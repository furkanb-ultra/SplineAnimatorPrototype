//
//  ImmersiveView.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct ImmersiveView: View {
    @State private var cancellable: Cancellable?
    @State private var animator: SplineAnimator?
    @State private var startTime: Date?
    
    var body: some View {
        RealityView { content in
            let pts: [SIMD3<Float>] = [
                [1.0, 0.5, -3.0],
                [0.5, 0.0, -2.0],
                [-1.0, 1.0, -2.5],
                [0.5, 2.0, -3.0],
                [0.5, 0.0, -4.0],
                [-1.0, 1.0, -5.0]
            ]
            let spline = Spline3D(pts)
            let ball = ModelEntity(
                mesh: .generateSphere(radius: 0.03),
                materials: [SimpleMaterial(color: .orange, isMetallic: false)]
            )
            content.add(ball)

            let animator = SplineAnimator(
                spline: spline,
                duration: 10,
                easeInDuration: 1,
                easeOutDuration: 8,
                easeInCurve: VelocityCurves.quadraticOut,
                easeOutCurve: VelocityCurves.quadraticIn,
                isLooping: true,
                isPingPong: true
            )
            self.animator = animator
            self.startTime = Date()
            
            // Visualize the spline path
            visualizeSpline(spline, content: content)

            // Visualize the control points
            visualizeControlPoints(pts, content: content)
            
            cancellable = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard let animator = self.animator, let startTime = self.startTime else { return }
                let elapsedTime = Float(Date().timeIntervalSince(startTime))
                ball.position = animator.position(at: elapsedTime)
            } as? any Cancellable
        }
    }
    private func visualizeSpline(_ spline: Spline3D, content: RealityViewContent, segments: Int = 100) {
        for i in 0...segments {
            let fraction = Float(i) / Float(segments)
            let position = spline.point(atFraction: fraction)
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.01),
                materials: [UnlitMaterial(color: .blue.withAlphaComponent(0.1))]
            )
            sphere.position = position
            content.add(sphere)
        }
    }

    private func visualizeControlPoints(_ points: [SIMD3<Float>], content: RealityViewContent) {
        for (index, position) in points.enumerated() {
            let controlPointSphere = ModelEntity(
                mesh: .generateSphere(radius: 0.025),
                materials: [SimpleMaterial(color: colorForControlPoint(at: index, total: points.count), isMetallic: false)]
            )
            controlPointSphere.position = position
            content.add(controlPointSphere)
        }
    }

    private func colorForControlPoint(at index: Int, total: Int) -> UIColor {
        switch index {
        case 0:
            return .orange // Start - Orange
        case total - 1:
            return .blue // End - Blue
        default:
            return .white
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
