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

    var body: some View {
        RealityView { content in
            let pts: [SIMD3<Float>] = [
                [0.0, 3.0, -1.0],
                [0.0, 0.0, -2.0],
                [0.0, 2.0, -2.5],
                [0.0, 1.0, -4.0],
                [0.0, 2.0, -5.0]
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
                easeIn: 0.2, // first 20% of time is ease-in
                easeOut: 0.2, // last 20% of time is ease-out
                easeInFunc: Easing.easeIn, // t*t
                easeOutFunc: Easing.easeOut, // t*(2-t)
                midFunc: Easing.linear
            )
            self.animator = animator

            cancellable = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard let animator = self.animator else { return }
                ball.position = animator.position()
            } as? any Cancellable
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
