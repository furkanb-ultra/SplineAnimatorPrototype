//
//  SplineAnimatorController.swift
//  Test
//
//  Created by Furkan on 23/05/25.
//



import RealityKit
import simd

/// Configuration preset for common animation types
enum SplineAnimationPreset {
    case base
    case linear(duration: Float, looping: Bool, adaptRotation: Bool)
    case smooth(duration: Float, looping: Bool, adaptRotation: Bool)
    case dramatic(duration: Float, looping: Bool, adaptRotation: Bool)
    case bouncing(duration: Float, adaptRotation: Bool)
    case custom(SplineAnimationConfig)
    
    var config: SplineAnimationConfig {
        switch self {
            
        case .base:
            return SplineAnimationConfig(
                duration: 2,
                easeInDuration: 0,
                easeOutDuration: 0,
                easeInCurve: VelocityCurves.linear,
                easeOutCurve: VelocityCurves.linear,
                isLooping: false,
                isPingPong: false,
                followSplineRotation: false
            )
            
            
        case .linear(let duration, let looping, let rotation):
            return SplineAnimationConfig(
                duration: duration,
                easeInDuration: 0,
                easeOutDuration: 0,
                easeInCurve: VelocityCurves.linear,
                easeOutCurve: VelocityCurves.linear,
                isLooping: looping,
                isPingPong: false,
                followSplineRotation: rotation
            )
            
        case .smooth(let duration, let looping, let rotation):
            let easeTime = duration * 0.33 // 25% of duration for each ease
            return SplineAnimationConfig(
                duration: duration,
                easeInDuration: easeTime,
                easeOutDuration: easeTime,
                easeInCurve: VelocityCurves.quadraticIn,
                easeOutCurve: VelocityCurves.quadraticOut,
                isLooping: looping,
                isPingPong: false,
                followSplineRotation: rotation
            )

        case .dramatic(let duration, let looping, let rotation):
            let easeTime = duration * 0.167 // ~1/6 of duration
            return SplineAnimationConfig(
                duration: duration,
                easeInDuration: easeTime,
                easeOutDuration: easeTime,
                easeInCurve: VelocityCurves.cubicIn,
                easeOutCurve: VelocityCurves.cubicOut,
                isLooping: looping,
                isPingPong: false,
                followSplineRotation: rotation
            )
            
        case .bouncing(let duration, let rotation):
            return SplineAnimationConfig(
                duration: duration,
                easeInDuration: duration,
                easeOutDuration: 0.0,
                easeInCurve: VelocityCurves.cubicIn,
                easeOutCurve: VelocityCurves.linear,
                isLooping: true,
                isPingPong: true,
                followSplineRotation: rotation
            )
                
        case .custom(let config):
            return config
        }
    }
}

/// Configuration for spline animations
struct SplineAnimationConfig {
    let duration: Float
    let easeInDuration: Float
    let easeOutDuration: Float
    let easeInCurve: (Float) -> Float
    let easeOutCurve: (Float) -> Float
    let isLooping: Bool
    let isPingPong: Bool
    let followSplineRotation: Bool
    let startDelay: Float
    
    init(
        duration: Float,
        easeInDuration: Float,
        easeOutDuration: Float,
        easeInCurve: @escaping (Float) -> Float = VelocityCurves.linear,
        easeOutCurve: @escaping (Float) -> Float = VelocityCurves.linear,
        isLooping: Bool = false,
        isPingPong: Bool = false,
        followSplineRotation: Bool = false,
        startDelay: Float = 0.0
    ) {
        self.duration = duration
        self.easeInDuration = easeInDuration
        self.easeOutDuration = easeOutDuration
        self.easeInCurve = easeInCurve
        self.easeOutCurve = easeOutCurve
        self.isLooping = isLooping
        self.isPingPong = isPingPong
        self.followSplineRotation = followSplineRotation
        self.startDelay = startDelay
    }
}

/// Manages multiple spline animations in a timeline-based system
final class SplineAnimatorController {
    private let timelineProvider: TimelineProvider
    private var animations: [String: AnimationInstance] = [:]
    
    private struct AnimationInstance {
        let entity: Entity
        let animator: SplineAnimator
        let config: SplineAnimationConfig
        var isActive: Bool = true
        
        var shouldAnimate: Bool {
            return isActive && (config.isLooping || !isComplete)
        }
        
        var isComplete: Bool {
            // Non-looping animations are complete after one full duration + delay
            let timelineProvider = self.timelineProvider
            return !config.isLooping && timelineProvider.currentTime >= (config.startDelay + config.duration)
        }
        
        let timelineProvider: TimelineProvider
        
        init(entity: Entity, animator: SplineAnimator, config: SplineAnimationConfig, timelineProvider: TimelineProvider) {
            self.entity = entity
            self.animator = animator
            self.config = config
            self.timelineProvider = timelineProvider
        }
    }
    
    init(timelineProvider: TimelineProvider) {
        self.timelineProvider = timelineProvider
    }
    
    /// Add a new spline animation to the controller
    func addAnimation(
        id: String,
        entity: Entity,
        spline: Spline3D,
        preset: SplineAnimationPreset = .base
    ) {
        let config = preset.config
        let animator = SplineAnimator(
            spline: spline,
            duration: config.duration,
            easeInDuration: config.easeInDuration,
            easeOutDuration: config.easeOutDuration,
            easeInCurve: config.easeInCurve,
            easeOutCurve: config.easeOutCurve,
            isLooping: config.isLooping,
            isPingPong: config.isPingPong,
            followSplineRotation: config.followSplineRotation
        )
        
        animations[id] = AnimationInstance(
            entity: entity,
            animator: animator,
            config: config,
            timelineProvider: timelineProvider
        )
    }
    
    /// Remove an animation
    func removeAnimation(id: String) {
        animations.removeValue(forKey: id)
    }
    
    /// Pause/resume a specific animation
    func setAnimationActive(id: String, isActive: Bool) {
        animations[id]?.isActive = isActive
    }
    
    /// Update all animations - call this in SceneEvents.Update
    func update() {
        let currentTime = timelineProvider.currentTime
        
        for (id, var instance) in animations {
            guard instance.shouldAnimate else { continue }
            
            // Calculate time adjusted for start delay
            let adjustedTime = max(0, currentTime - instance.config.startDelay)
            
            // Skip if animation hasn't started yet
            guard adjustedTime > 0 else { continue }
            
            // Update position
            instance.entity.position = instance.animator.position(at: adjustedTime)
            
            // Update rotation if enabled
            if instance.config.followSplineRotation {
                instance.entity.orientation = instance.animator.orientation(
                    at: adjustedTime,
                    currentOrientation: instance.entity.orientation
                )
            }
            
            // Update the instance in dictionary
            animations[id] = instance
        }
    }
    
    /// Get debug info for all animations
    func debugInfo() -> String {
        var info = "Timeline: \(String(format: "%.2f", timelineProvider.currentTime))s\n"
        info += "Active Animations: \(animations.count)\n\n"
        
        for (id, instance) in animations {
            let adjustedTime = max(0, timelineProvider.currentTime - instance.config.startDelay)
            info += "[\(id)] "
            
            if adjustedTime <= 0 {
                info += "Waiting (starts in \(String(format: "%.1f", -adjustedTime))s)\n"
            } else {
                info += instance.animator.debugInfo(at: adjustedTime) + "\n\n"
            }
        }
        
        return info
    }
    
    /// Get all animation IDs
    var animationIDs: [String] {
        return Array(animations.keys)
    }
    
    /// Check if animation exists
    func hasAnimation(id: String) -> Bool {
        return animations[id] != nil
    }
    
    /// Get animation status
    func isAnimationActive(id: String) -> Bool {
        return animations[id]?.isActive ?? false
    }
    
    /// Clear all animations
    func clearAllAnimations() {
        animations.removeAll()
    }
}
