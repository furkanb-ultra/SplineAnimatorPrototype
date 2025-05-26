//
//  SplineVisualizer.swift
//  Test
//
//  Updated by Furkan on 26/05/25.
//

import RealityKit
import SwiftUI

class SplineVisualizer {
    private let config: SplineVisualizationConfig
    
    init(config: SplineVisualizationConfig = .default) {
        self.config = config
    }
    
    func visualize(spline: Spline3D, controlPoints: [SIMD3<Float>], content: RealityViewContent) {
        if config.showSplinePath {
            visualizeSplinePath(spline, content: content)
        }
        
        if config.showControlPoints {
            visualizeControlPoints(controlPoints, content: content)
        }
    }
    
    private func visualizeSplinePath(_ spline: Spline3D, content: RealityViewContent) {
        for i in 0...config.splineSegments {
            let fraction = Float(i) / Float(config.splineSegments)
            let position = spline.point(atFraction: fraction)
            let sphere = createSplinePointEntity()
            sphere.position = position
            content.add(sphere)
        }
    }
    
    private func visualizeControlPoints(_ points: [SIMD3<Float>], content: RealityViewContent) {
        for position in points {
            let sphere = createControlPointEntity()
            sphere.position = position
            content.add(sphere)
        }
    }
    
    private func createSplinePointEntity() -> ModelEntity {
        return ModelEntity(
            mesh: .generateSphere(radius: config.splinePointRadius),
            materials: [UnlitMaterial(color: config.splinePointColor.withAlphaComponent(CGFloat(config.splineOpacity)))]
        )
    }
    
    private func createControlPointEntity() -> ModelEntity {
        return ModelEntity(
            mesh: .generateSphere(radius: config.controlPointRadius),
            materials: [SimpleMaterial(color: config.controlPointColor, isMetallic: false)]
        )
    }
}

struct SplineVisualizationConfig {
    let showSplinePath: Bool
    let showControlPoints: Bool
    let splineSegments: Int
    let splinePointRadius: Float
    let splinePointColor: UIColor
    let controlPointRadius: Float
    let controlPointColor: UIColor
    let splineOpacity: Float
    
    static let `default` = SplineVisualizationConfig(
        showSplinePath: true,
        showControlPoints: true,
        splineSegments: 100,
        splinePointRadius: 0.01,
        splinePointColor: .blue,
        controlPointRadius: 0.025,
        controlPointColor: .blue,
        splineOpacity: 0.1
    )
    
    static let minimal = SplineVisualizationConfig(
        showSplinePath: true,
        showControlPoints: false,
        splineSegments: 100,
        splinePointRadius: 0.005,
        splinePointColor: .orange,
        controlPointRadius: 0.02,
        controlPointColor: .red,
        splineOpacity: 0.05
    )

    // 🚩 New editor preset added
    static let editor = SplineVisualizationConfig(
        showSplinePath: true,
        showControlPoints: true,
        splineSegments: 100,
        splinePointRadius: 0.008,
        splinePointColor: .blue,
        controlPointRadius: 0.03,
        controlPointColor: .blue,
        splineOpacity: 0.2
    )
}

extension SplineVisualizer {
    func visualize(spline: Spline3D, controlPoints: [SIMD3<Float>], parentEntity: Entity) {
        if config.showSplinePath {
            visualizeSplinePath(spline, parentEntity: parentEntity)
        }
        
        if config.showControlPoints {
            visualizeControlPoints(controlPoints, parentEntity: parentEntity)
        }
    }

    private func visualizeSplinePath(_ spline: Spline3D, parentEntity: Entity) {
        for i in 0...config.splineSegments {
            let fraction = Float(i) / Float(config.splineSegments)
            let position = spline.point(atFraction: fraction)
            let sphere = createSplinePointEntity()
            sphere.position = position
            parentEntity.addChild(sphere)
        }
    }

    private func visualizeControlPoints(_ points: [SIMD3<Float>], parentEntity: Entity) {
        for position in points {
            let sphere = createControlPointEntity()
            sphere.position = position
            parentEntity.addChild(sphere)
        }
    }
}
