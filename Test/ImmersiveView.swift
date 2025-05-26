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
    @State private var timelineProvider = TimelineProvider()
    @State private var animatorController: SplineAnimatorController?
    @State private var scene: Entity?
    
    var body: some View {
        RealityView { content in
            scene = try? await Entity(named: "Scene", in: realityKitContentBundle)
            content.add(scene!)
            
            // Initialize timeline and controller
            let controller = SplineAnimatorController(timelineProvider: timelineProvider)
            self.animatorController = controller
            
            // Create your spline points
            let pts: [SIMD3<Float>] = [
                [1.0, 0.5, -3.0],
                [0.5, 0.0, -2.0],
                [-1.0, 1.0, -2.5],
                [0.5, 2.0, -3.0],
                [0.5, 0.0, -4.0],
                [-1.0, 1.0, -5.0]
            ]
            let spline = Spline3D(pts)
            
            // Get the ball entity
            let ball: Entity = scene?.findEntity(named: "Immersive") ?? Entity()
            let sphere: Entity = scene?.findEntity(named: "Sphere") ?? Entity()

            // Add the animation using preset - this replaces your old SplineAnimator setup
            controller.addAnimation(
                id: "FirstElement",
                entity: ball,
                spline: spline,
                preset: .bouncing(duration: 10, adaptRotation: true)
            )
            
            // Example: Add a second animation with custom config and delay
            
            let customConfig = SplineAnimationConfig(
                duration: 15.0,
                easeInDuration: 3.0,
                easeOutDuration: 3.0,
                easeInCurve: VelocityCurves.quadraticIn,
                easeOutCurve: VelocityCurves.quadraticOut,
                isLooping: true,
                isPingPong: false,
                followSplineRotation: true,
                startDelay: 5.0  // Start 2 seconds after timeline begins
            )
            
            controller.addAnimation(
                id: "SecondElement",
                entity: sphere,
                spline: spline,
                preset: .custom(customConfig)
            )
            
            
            // Visualize the spline
            let splineVisualizer = SplineVisualizer(config: .default)
            splineVisualizer.visualize(spline: spline, controlPoints: pts, content: content)
            
            // Start the timeline
            timelineProvider.start()
            
            // Update loop
            cancellable = content.subscribe(to: SceneEvents.Update.self) { _ in
                controller.update()
            } as? any Cancellable
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
