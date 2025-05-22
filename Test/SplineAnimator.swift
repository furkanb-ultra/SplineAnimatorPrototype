//
//  SplineAnimator.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//


import Foundation
import simd

final class SplineAnimator {
    let spline: Spline3D
    let duration: Float // Total animation duration in seconds
    
    // Phase durations in seconds
    let easeInDuration: Float
    let easeOutDuration: Float
    let constantDuration: Float
    
    // Velocity curves (should return values roughly 0-2, with average ~1)
    let easeInCurve: (Float) -> Float
    let easeOutCurve: (Float) -> Float
    
    let isLooping: Bool
    let isPingPong: Bool
    
    // Computed physics properties
    private let constantVelocity: Float
    private let easeInVelocityScale: Float
    private let easeOutVelocityScale: Float
    
    // Distance contributions of each phase (0-1 range)
    private let easeInDistanceFraction: Float
    private let easeOutDistanceFraction: Float
    
    enum Phase {
        case easeIn
        case constant
        case easeOut
    }
    
    init(
        spline: Spline3D,
        duration: Float,
        easeInDuration: Float,
        easeOutDuration: Float,
        easeInCurve: @escaping (Float) -> Float = { _ in 1.0 },
        easeOutCurve: @escaping (Float) -> Float = { _ in 1.0 },
        isLooping: Bool = false,
        isPingPong: Bool = false
    ) {
        self.spline = spline
        self.duration = max(0.1, duration) // Minimum duration safety
        self.isLooping = isLooping
        self.isPingPong = isPingPong
        self.easeInCurve = easeInCurve
        self.easeOutCurve = easeOutCurve
        
        // Clamp ease durations to not exceed total duration
        let totalEaseDuration = easeInDuration + easeOutDuration
        if totalEaseDuration >= duration {
            // If ease durations exceed total, scale them proportionally
            let scale = (duration * 0.95) / totalEaseDuration // Leave 5% for constant phase
            self.easeInDuration = easeInDuration * scale
            self.easeOutDuration = easeOutDuration * scale
            self.constantDuration = duration - self.easeInDuration - self.easeOutDuration
        } else {
            self.easeInDuration = easeInDuration
            self.easeOutDuration = easeOutDuration
            self.constantDuration = duration - easeInDuration - easeOutDuration
        }
        
        // Find maximum velocities of the curves to ensure peaks match constant velocity
        let easeInMaxVelocity = Self.maxCurveValue(easeInCurve)
        let easeOutMaxVelocity = Self.maxCurveValue(easeOutCurve)
        
        // Calculate average values of the velocity curves (after normalization to max=1)
        let easeInNormalizedAverage = Self.averageCurveValue { t in easeInCurve(t) / easeInMaxVelocity }
        let easeOutNormalizedAverage = Self.averageCurveValue { t in easeOutCurve(t) / easeOutMaxVelocity }
        
        // Calculate what fraction of total distance each phase should cover
        // This ensures the entire spline is traversed in the specified duration
        let totalTimeWeightedDistance = (self.easeInDuration * easeInNormalizedAverage) +
                                       self.constantDuration +
                                       (self.easeOutDuration * easeOutNormalizedAverage)
        
        if totalTimeWeightedDistance > 0 {
            // The constant velocity is what we need to maintain the timing
            self.constantVelocity = 1.0 / totalTimeWeightedDistance
            
            // Calculate distance fractions based on normalized curves
            self.easeInDistanceFraction = (self.easeInDuration * easeInNormalizedAverage) / totalTimeWeightedDistance
            self.easeOutDistanceFraction = (self.easeOutDuration * easeOutNormalizedAverage) / totalTimeWeightedDistance
            
            // Scale factors to make ease curve PEAKS match constant velocity
            // Since we normalized curves to max=1, multiplying by constantVelocity gives us the right peak
            self.easeInVelocityScale = self.constantVelocity / easeInMaxVelocity
            self.easeOutVelocityScale = self.constantVelocity / easeOutMaxVelocity
        } else {
            // Fallback for edge cases
            self.easeInDistanceFraction = 0.33
            self.easeOutDistanceFraction = 0.33
            self.constantVelocity = 1.0
            self.easeInVelocityScale = 1.0 / easeInMaxVelocity
            self.easeOutVelocityScale = 1.0 / easeOutMaxVelocity
        }
        
        print("=== SplineAnimator Refactored (Peak Velocity Matched) ===")
        print("Total Duration: \(duration)s")
        print("Phase Durations: EaseIn=\(self.easeInDuration)s, Constant=\(self.constantDuration)s, EaseOut=\(self.easeOutDuration)s")
        print("Distance Fractions: EaseIn=\(easeInDistanceFraction), EaseOut=\(easeOutDistanceFraction), Constant=\(1-easeInDistanceFraction-easeOutDistanceFraction)")
        print("Constant Velocity: \(constantVelocity)")
        print("Curve Max Velocities: EaseIn=\(easeInMaxVelocity), EaseOut=\(easeOutMaxVelocity)")
        print("Curve Normalized Averages: EaseIn=\(easeInNormalizedAverage), EaseOut=\(easeOutNormalizedAverage)")
        print("Velocity Scales: EaseIn=\(easeInVelocityScale), EaseOut=\(easeOutVelocityScale)")
        print("Peak Velocities After Scaling: EaseIn=\(easeInMaxVelocity * easeInVelocityScale), EaseOut=\(easeOutMaxVelocity * easeOutVelocityScale)")
        print("=========================================================")
    }
    
    // Calculate the maximum value of a curve over [0,1]
    private static func maxCurveValue(_ curve: (Float) -> Float, samples: Int = 200) -> Float {
        var maxValue: Float = 0
        for i in 0...samples {
            let t = Float(i) / Float(samples)
            maxValue = max(maxValue, curve(t))
        }
        return max(maxValue, 0.01) // Prevent division by zero
    }
    
    // Calculate the average value of a curve over [0,1]
    private static func averageCurveValue(_ curve: (Float) -> Float, samples: Int = 100) -> Float {
        var sum: Float = 0
        for i in 0...samples {
            let t = Float(i) / Float(samples)
            sum += curve(t)
        }
        return sum / Float(samples + 1)
    }
    
    // Convert elapsed time to normalized time [0,1] handling looping and ping-pong
    private func normalizedTime(for elapsedTime: Float) -> Float {
        guard duration > 0 else { return 0 }
        
        if !isLooping {
            return min(max(elapsedTime / duration, 0), 1)
        }
        
        if !isPingPong {
            // Simple looping
            let cycles = elapsedTime / duration
            let t = cycles - floor(cycles) // Get fractional part
            return t
        } else {
            // Ping-pong: 0→1→0→1...
            let halfCycle = duration
            let fullCycle = duration * 2
            let cycleTime = elapsedTime.truncatingRemainder(dividingBy: fullCycle)
            
            if cycleTime < halfCycle {
                // Forward: 0 → 1
                return cycleTime / halfCycle
            } else {
                // Backward: 1 → 0
                return 1.0 - ((cycleTime - halfCycle) / halfCycle)
            }
        }
    }
    
    // Determine which phase we're in based on normalized time
    func currentPhase(at normalizedTime: Float) -> Phase {
        let t = max(0, min(1, normalizedTime))
        let timeInSeconds = t * duration
        
        if timeInSeconds <= easeInDuration {
            return .easeIn
        } else if timeInSeconds <= (easeInDuration + constantDuration) {
            return .constant
        } else {
            return .easeOut
        }
    }
    
    // Calculate how far along the spline we should be (0-1) at given normalized time
    func splineProgress(at normalizedTime: Float) -> Float {
        let t = max(0, min(1, normalizedTime))
        let timeInSeconds = t * duration
        
        if timeInSeconds <= easeInDuration && easeInDuration > 0 {
            // Ease-in phase
            let phaseProgress = timeInSeconds / easeInDuration
            let curveValue = easeInCurve(phaseProgress)
            let velocityAtTime = curveValue * easeInVelocityScale
            
            // Integrate velocity over time to get distance
            let distance = Self.integrateVelocityCurve(
                curve: easeInCurve,
                velocityScale: easeInVelocityScale,
                upTo: phaseProgress,
                duration: easeInDuration
            )
            
            return distance
            
        } else if timeInSeconds <= (easeInDuration + constantDuration) {
            // Constant phase
            let constantTimeElapsed = timeInSeconds - easeInDuration
            let constantDistance = constantTimeElapsed * constantVelocity
            
            return easeInDistanceFraction + constantDistance
            
        } else {
            // Ease-out phase
            let easeOutTimeElapsed = timeInSeconds - easeInDuration - constantDuration
            let phaseProgress = easeOutDuration > 0 ? easeOutTimeElapsed / easeOutDuration : 0
            
            let easeOutDistance = Self.integrateVelocityCurve(
                curve: easeOutCurve,
                velocityScale: easeOutVelocityScale,
                upTo: phaseProgress,
                duration: easeOutDuration
            )
            
            let totalProgress = easeInDistanceFraction + (1 - easeInDistanceFraction - easeOutDistanceFraction) + easeOutDistance
            return min(totalProgress, 1.0)
        }
    }
    
    // Integrate a velocity curve over time to get distance traveled
    private static func integrateVelocityCurve(
        curve: (Float) -> Float,
        velocityScale: Float,
        upTo localProgress: Float,
        duration: Float,
        samples: Int = 50
    ) -> Float {
        guard localProgress > 0 && duration > 0 && samples > 0 else { return 0 }
        
        let clampedProgress = min(max(localProgress, 0), 1)
        var totalDistance: Float = 0
        let dt = clampedProgress / Float(samples)
        
        for i in 0..<samples {
            let t0 = Float(i) * dt
            let t1 = min(t0 + dt, clampedProgress)
            
            let v0 = curve(t0) * velocityScale
            let v1 = curve(t1) * velocityScale
            let avgVelocity = (v0 + v1) * 0.5
            
            // Distance = velocity × time (time here is dt * duration for actual seconds)
            totalDistance += avgVelocity * dt * duration
        }
        
        return totalDistance
    }
    
    // Get the 3D position at given elapsed time
    func position(at elapsedTime: Float) -> SIMD3<Float> {
        let normalizedT = normalizedTime(for: elapsedTime)
        let splineT = splineProgress(at: normalizedT)
        return spline.point(atFraction: splineT)
    }
    
    // Get current velocity magnitude (units per second)
    func currentVelocity(at elapsedTime: Float) -> Float {
        let normalizedT = normalizedTime(for: elapsedTime)
        let timeInSeconds = normalizedT * duration
        
        if timeInSeconds <= easeInDuration && easeInDuration > 0 {
            let phaseProgress = timeInSeconds / easeInDuration
            return easeInCurve(phaseProgress) * easeInVelocityScale
        } else if timeInSeconds <= (easeInDuration + constantDuration) {
            return constantVelocity
        } else if easeOutDuration > 0 {
            let easeOutTimeElapsed = timeInSeconds - easeInDuration - constantDuration
            let phaseProgress = easeOutTimeElapsed / easeOutDuration
            return easeOutCurve(phaseProgress) * easeOutVelocityScale
        } else {
            return constantVelocity
        }
    }
    
    // Debug information
    func debugInfo(at elapsedTime: Float) -> String {
        let normalizedT = normalizedTime(for: elapsedTime)
        let splineT = splineProgress(at: normalizedT)
        let phase = currentPhase(at: normalizedT)
        let velocity = currentVelocity(at: elapsedTime)
        
        return """
        Elapsed: \(String(format: "%.2f", elapsedTime))s / \(duration)s
        Normalized Time: \(String(format: "%.3f", normalizedT))
        Current Phase: \(phase)
        Spline Progress: \(String(format: "%.1f", splineT * 100))%
        Current Velocity: \(String(format: "%.2f", velocity))
        Phase Durations: EaseIn=\(easeInDuration)s, Constant=\(constantDuration)s, EaseOut=\(easeOutDuration)s
        """
    }
}

// MARK: - Velocity Curves
struct VelocityCurves {
    // Linear: constant velocity
    static let linear: (Float) -> Float = { _ in 1.0 }
    
    // Quadratic easing
    static let quadraticIn: (Float) -> Float = { t in 2 * t } // Derivative of t²
    static let quadraticOut: (Float) -> Float = { t in 2 * (1 - t) } // Derivative of -(t-1)²
    
    // Cubic easing
    static let cubicIn: (Float) -> Float = { t in 3 * t * t } // Derivative of t³
    static let cubicOut: (Float) -> Float = { t in 3 * (1 - t) * (1 - t) } // Derivative of -(t-1)³
    
    // Sine wave easing
    static let sineIn: (Float) -> Float = { t in
        let angle = t * Float.pi / 2
        return cos(angle) * Float.pi / 2 // Derivative of sin
    }
    static let sineOut: (Float) -> Float = { t in
        let angle = (1 - t) * Float.pi / 2
        return cos(angle) * Float.pi / 2
    }
    
    // Exponential easing
    static let exponentialIn: (Float) -> Float = { t in
        guard t > 0 else { return 0 }
        return pow(2, 10 * (t - 1)) * log(2) * 10
    }
    static let exponentialOut: (Float) -> Float = { t in
        guard t < 1 else { return 0 }
        return -pow(2, -10 * t) * log(2) * 10
    }
}
