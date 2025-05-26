//
//  SplineEditorView.swift
//  Test
//
//  Created by Furkan on 26/05/25.
//
import SwiftUI
import RealityKit
import RealityKitContent
import Combine
import simd

// MARK: - State Management
@MainActor
@Observable
class SplineEditState {
    var isEditMode: Bool = true
    var selectedControlPointIndex: Int? = nil
    var controlPoints: [SIMD3<Float>] = [
        [0.5, 0.0, -2.0],
        [-1.0, 1.0, -2.5],
        [0.5, 2.0, -3.0],
        [0.5, 0.0, -4.0],
        [-1.0, 1.0, -5.0]
    ]
}

// MARK: - ControlPointEntity
class ControlPointEntity: Entity, HasModel, HasCollision {
    let index: Int

    init(index: Int, position: SIMD3<Float>) {
        self.index = index
        super.init()
        self.position = position
        self.name = "ControlPoint_\(index)"

        self.components[ModelComponent.self] = ModelComponent(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .blue, isMetallic: false)]
        )
        self.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateSphere(radius: 0.1)]
        )
        self.components.set(InputTargetComponent())
    }

    required init() { fatalError("init() has not been implemented") }

    func setSelected(_ selected: Bool) {
        let color: UIColor = selected ? .orange : .blue
        self.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
    }
}

// MARK: - SplineEditorView
struct SplineEditorView: View {
    @State private var editState = SplineEditState()
    @State private var controlPointEntities: [ControlPointEntity] = []
    @State private var rootEntity = Entity()
    @State private var gizmoEntity: Entity?
    @State private var arrowEntities: [ModelEntity] = []
    @State private var dragStartCPPosition: SIMD3<Float>? = nil
    @State private var dragAxisDir: SIMD3<Float>? = nil
    @State private var dragStartOffset: Float? = nil

    var body: some View {
        RealityView { content in
            content.add(rootEntity)
            createControlPoints()
            updateSplineVisualization()
        } update: { content in
            updateSplineVisualization()
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    guard editState.isEditMode else { return }
                    if let cp = value.entity as? ControlPointEntity {
                        selectControlPoint(cp.index)
                    }
                }
        )
        .simultaneousGesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    guard
                        let arrow = value.entity as? ModelEntity,
                        let selected = editState.selectedControlPointIndex,
                        let gizmo = gizmoEntity,
                        arrowEntities.contains(arrow)
                    else { return }

                    // Convert 3D gesture location to rootEntity space
                    let worldPos = value.location3D
                    let localPos = value.convert(worldPos,
                                                 from: .global,
                                                 to: rootEntity)

                    // Initialize drag context
                    if dragStartCPPosition == nil {
                        dragStartCPPosition = editState.controlPoints[selected]
                        // Axis from arrow's local +Y axis
                        let rawAxis = arrow.orientation.act([0,1,0])
                        let axis = normalize(rawAxis)
                        dragAxisDir = axis
                        // Compute initial offset so we don't jump
                        dragStartOffset = dot(localPos - dragStartCPPosition!, axis)
                    }

                    guard
                        let initialPos = dragStartCPPosition,
                        let axisDir = dragAxisDir,
                        let startOff = dragStartOffset
                    else { return }

                    // Compute how far we've moved along the axis
                    let raw = dot(localPos - initialPos, axisDir)
                    let delta = raw - startOff
                    let newPos = initialPos + axisDir * delta

                    // Update state and visuals
                    editState.controlPoints[selected] = newPos
                    controlPointEntities[selected].position = newPos
                    gizmo.position = newPos
                    updateSplineVisualization()
                }
                .onEnded { _ in
                    dragStartCPPosition = nil
                    dragAxisDir = nil
                    dragStartOffset = nil
                }
        )
        .ornament(attachmentAnchor: .scene(.bottom)) {
            VStack {
                Toggle("Edit Mode", isOn: $editState.isEditMode)
                    .toggleStyle(.button)
                    .padding()

                if editState.isEditMode {
                    HStack {
                        Image(systemName: "hand.tap.fill")
                        Text("Tap a sphere to select")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)

                    if let sel = editState.selectedControlPointIndex {
                        Text("Selected: Point \(sel)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }

    // MARK: - Helpers
    private func createControlPoints() {
        controlPointEntities.forEach { $0.removeFromParent() }
        controlPointEntities.removeAll()

        for (i, pos) in editState.controlPoints.enumerated() {
            let cp = ControlPointEntity(index: i, position: pos)
            rootEntity.addChild(cp)
            controlPointEntities.append(cp)
        }
    }

    private func selectControlPoint(_ index: Int) {
        if let prev = editState.selectedControlPointIndex, prev != index {
            controlPointEntities[prev].setSelected(false)
        }
        controlPointEntities[index].setSelected(true)
        editState.selectedControlPointIndex = index
        spawnGizmo(at: editState.controlPoints[index])
    }

    private func spawnGizmo(at position: SIMD3<Float>) {
        removeGizmo()
        arrowEntities.removeAll()

        let gizmo = Entity()
        gizmo.name = "GizmoEntity"
        gizmo.position = position

        let axes: [(SIMD3<Float>, UIColor, simd_quatf)] = [
            ([0.15, 0, 0], .red,   simd_quatf(angle: -.pi/2, axis: [0,0,1])),
            ([0, 0.15, 0], .green, simd_quatf(angle: 0,       axis: [0,1,0])),
            ([0, 0, 0.15], .blue,  simd_quatf(angle: .pi/2,  axis: [1,0,0]))
        ]

        for (dir, color, rotation) in axes {
            let arrow = ModelEntity(
                mesh: .generateCone(height: 0.08, radius: 0.015),
                materials: [SimpleMaterial(color: color, isMetallic: false)]
            )
            arrow.position = dir
            arrow.orientation = rotation
            arrow.generateCollisionShapes(recursive: false)
            arrow.components.set(InputTargetComponent())
            gizmo.addChild(arrow)
            arrowEntities.append(arrow)
        }

        rootEntity.addChild(gizmo)
        gizmoEntity = gizmo
    }

    private func removeGizmo() {
        gizmoEntity?.removeFromParent()
        gizmoEntity = nil
        arrowEntities.removeAll()
    }

    private func updateSplineVisualization() {
        rootEntity.children
            .filter { $0.name == "SplineVisualization" }
            .forEach { $0.removeFromParent() }

        let splineEntity = Entity()
        splineEntity.name = "SplineVisualization"
        rootEntity.addChild(splineEntity)

        let spline = Spline3D(editState.controlPoints)
        // Adaptive segment count based on spline length
        let length = spline.totalLength
        let segments = Int(max(10, min(200, length * 10)))
        let config = SplineVisualizationConfig(
            showSplinePath: true,
            showControlPoints: editState.isEditMode,
            splineSegments: segments,
            splinePointRadius: editState.isEditMode ? 0.008 : 0.01,
            splinePointColor: .blue,
            controlPointRadius: editState.isEditMode ? 0.03 : 0.025,
            controlPointColor: .blue,
            splineOpacity: editState.isEditMode ? 0.2 : 0.1
        )
        let visualizer = SplineVisualizer(config: config)
        visualizer.visualize(
            spline: spline,
            controlPoints: [],
            parentEntity: splineEntity
        )
    }
}

#Preview(immersionStyle: .mixed) {
    SplineEditorView()
}
