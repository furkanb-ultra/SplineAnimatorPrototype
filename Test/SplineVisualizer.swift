//
//  SplineVisualizer.swift
//  Test
//
//  Created by Furkan on 23/05/25.
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
            materials: [UnlitMaterial(color: config.splinePointColor.withAlphaComponent(0.5))]
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
}
