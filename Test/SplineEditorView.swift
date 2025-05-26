//
//  SplineEditorView.swift
//  Test
//
//  Created by Furkan on 26/05/25.
//
//


import SwiftUI
import RealityKit
import RealityKitContent

// MARK: - State Management
@MainActor
@Observable
class SplineEditState {
    var isEditMode: Bool = true
    var selectedControlPointIndex: Int? = nil
    var controlPoints: [SIMD3<Float>] = [
        [1.0, 0.5, -3.0],
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

        self.components[CollisionComponent.self] = CollisionComponent(shapes: [.generateSphere(radius: 0.1)])
        self.components.set(InputTargetComponent())
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    func setSelected(_ selected: Bool) {
        let color: UIColor = selected ? .orange : .blue
        self.model?.materials = [SimpleMaterial(color: color, isMetallic: false)]
    }
}

// MARK: - SplineEditorView View
struct SplineEditorView: View {
    @State private var editState = SplineEditState()
    @State private var controlPointEntities: [ControlPointEntity] = []
    @State private var rootEntity = Entity()
    @State private var gizmoEntity: Entity?

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
                    handleTap(on: value.entity)
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

                    if let selected = editState.selectedControlPointIndex {
                        Text("Selected: Point \(selected)")
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

        for (index, position) in editState.controlPoints.enumerated() {
            let entity = ControlPointEntity(index: index, position: position)
            rootEntity.addChild(entity)
            controlPointEntities.append(entity)
        }
    }

    private func handleTap(on entity: Entity) {
        guard editState.isEditMode else { return }

        if let cpEntity = entity as? ControlPointEntity {
            selectControlPoint(cpEntity.index)
        } else {
            deselectControlPoint()
        }
    }

    private func selectControlPoint(_ index: Int) {
        if let previous = editState.selectedControlPointIndex, previous != index {
            controlPointEntities[previous].setSelected(false)
        }

        controlPointEntities[index].setSelected(true)
        editState.selectedControlPointIndex = index

        spawnGizmo(at: editState.controlPoints[index])
    }

    private func deselectControlPoint() {
        if let previous = editState.selectedControlPointIndex {
            controlPointEntities[previous].setSelected(false)
            editState.selectedControlPointIndex = nil
        }
        removeGizmo()
    }

    private func spawnGizmo(at position: SIMD3<Float>) {
        removeGizmo()

        let gizmo = Entity()
        gizmo.name = "GizmoEntity"
        gizmo.position = position

        // Axes: direction, color, rotation
        let axes: [(SIMD3<Float>, UIColor, simd_quatf)] = [
            ([0.15, 0, 0], .red, simd_quatf(angle: -.pi / 2, axis: [0,0,1])),   // X-axis
            ([0, 0.15, 0], .green, simd_quatf(angle: 0, axis: [0,1,0])),         // Y-axis
            ([0, 0, 0.15], .blue, simd_quatf(angle: .pi / 2, axis: [1,0,0]))    // Z-axis
        ]

        for (direction, color, rotation) in axes {
            let arrow = ModelEntity(
                mesh: .generateCone(height: 0.08, radius: 0.015),
                materials: [SimpleMaterial(color: color, isMetallic: false)]
            )
            arrow.position = direction
            arrow.orientation = rotation
            arrow.generateCollisionShapes(recursive: false)
            gizmo.addChild(arrow)
        }

        rootEntity.addChild(gizmo)
        gizmoEntity = gizmo
    }

    private func removeGizmo() {
        gizmoEntity?.removeFromParent()
        gizmoEntity = nil
    }

    private func updateSplineVisualization() {
        rootEntity.children
            .filter { $0.name == "SplineVisualization" }
            .forEach { $0.removeFromParent() }

        let splineEntity = Entity()
        splineEntity.name = "SplineVisualization"
        rootEntity.addChild(splineEntity)

        let spline = Spline3D(editState.controlPoints)
        let splineVisualizer = SplineVisualizer(config: editState.isEditMode ? .editor : .default)

        splineVisualizer.visualize(spline: spline, controlPoints: [], parentEntity: splineEntity)
    }
}

#Preview(immersionStyle: .mixed) {
    SplineEditorView()
}
