//
//  SimpleSplineAnimator.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//

import Foundation
import simd

final class SplineAnimator {
    let spline: Spline3D
    let duration: Float

    let easeInDuration: Float      // Proportion (0...1)
    let easeOutDuration: Float     // Proportion (0...1)
    let easeInCurve: (Float) -> Float   // velocity profile: t in 0...1 → velocity in 0...1
    let easeOutCurve: (Float) -> Float  // velocity profile: t in 0...1 → velocity in 1...0

    let isLooping: Bool
    let isPingPong: Bool

    // Precomputed areas and matched linear speed
    let A_in: Float
    let A_out: Float
    let v_linear: Float
    let Tc: Float // central linear portion

    enum Phase {
        case easeIn
        case linear
        case easeOut
        case unknown
    }

    init(
        spline: Spline3D,
        duration: Float,
        easeInDuration: Float,
        easeOutDuration: Float,
        easeInCurve: @escaping (Float) -> Float,
        easeOutCurve: @escaping (Float) -> Float,
        isLooping: Bool = false,
        isPingPong: Bool = false
    ) {
        self.spline = spline
        self.duration = duration
        self.easeInCurve = easeInCurve
        self.easeOutCurve = easeOutCurve
        self.isLooping = isLooping
        self.isPingPong = isPingPong

        // Clamp ease durations so that sum <= 1.0
        let totalEase = easeInDuration + easeOutDuration
        if totalEase > 1.0 {
            let scale = 1.0 / totalEase
            self.easeInDuration = easeInDuration * scale
            self.easeOutDuration = easeOutDuration * scale
        } else {
            self.easeInDuration = easeInDuration
            self.easeOutDuration = easeOutDuration
        }

        let T1 = self.easeInDuration
        let T2 = self.easeOutDuration
        let Tc = max(0, 1.0 - T1 - T2)
        self.Tc = Tc

        self.A_in = SplineAnimator.integrate(curve: easeInCurve, steps: 1000)
        self.A_out = SplineAnimator.integrate(curve: easeOutCurve, steps: 1000)
        self.v_linear = 1.0 / (A_in * T1 + Tc + A_out * T2)
    }

    static func integrate(curve: (Float) -> Float, steps: Int) -> Float {
        var sum: Float = 0
        let dt = 1.0 / Float(steps)
        for i in 0..<steps {
            let t0 = Float(i) * dt
            let t1 = t0 + dt
            sum += 0.5 * (curve(t0) + curve(min(t1, 1.0))) * dt
        }
        return sum
    }

    static func integrate(curve: (Float) -> Float, upTo localT: Float, steps: Int) -> Float {
        let localTClamped = min(max(localT, 0), 1)
        if localTClamped <= 0 { return 0 }
        var sum: Float = 0
        let dt = localTClamped / Float(steps)
        for i in 0..<steps {
            let t0 = Float(i) * dt
            let t1 = t0 + dt
            sum += 0.5 * (curve(t0) + curve(min(t1, 1.0))) * dt
        }
        return sum
    }

    /// Converts any elapsed time to normalized [0,1] progress, with support for looping and ping-pong.
    private func normalizedTime(for elapsedTime: Float) -> Float {
        guard duration > 0 else { return 0 }
        if !isLooping {
            return min(max(elapsedTime / duration, 0), 1)
        }
        if !isPingPong {
            let t = fmodf(elapsedTime, duration) / duration
            return t
        } else {
            let doubleDuration = duration * 2
            let t = fmodf(elapsedTime, doubleDuration)
            if t < duration {
                // Forward
                return t / duration
            } else {
                // Backward
                return 1 - ((t - duration) / duration)
            }
        }
    }

    /// PHASE DETECTION FOR DEBUGGING
    func phase(at t: Float) -> Phase {
        let T1 = easeInDuration
        let T2 = easeOutDuration
        let Tc = Tc
        let tClamped = min(max(t, 0), 1)
        let easeInEnd = T1
        let linearEnd = 1.0 - T2

        if T1 > 0 && tClamped < easeInEnd {
            return .easeIn
        }
        else if Tc > 0 && tClamped < linearEnd {
            return .linear
        }
        else if T2 > 0 && tClamped <= 1.0 {
            return .easeOut
        }
        else {
            return .unknown
        }
    }

    /// Returns the *arc-length fraction* (distance fraction) at a given normalized time t in [0,1].
    func distanceFraction(at t: Float) -> Float {
        let T1 = easeInDuration
        let T2 = easeOutDuration
        let Tc = self.Tc
        let tClamped = min(max(t, 0), 1)
        let easeInEnd = T1
        let linearEnd = 1.0 - T2
        let easeInArea = v_linear * A_in * T1
        let linearArea = v_linear * Tc

        // 1. Ease-in phase: [0, easeInEnd)
        if T1 > 0, tClamped < easeInEnd {
            let localT = tClamped / T1
            let area = SplineAnimator.integrate(curve: easeInCurve, upTo: localT, steps: 100)
            return v_linear * area * T1
        }

        // 2. Linear phase: [easeInEnd, linearEnd)
        if Tc > 0, tClamped < linearEnd {
            let linearT = tClamped - T1
            return easeInArea + v_linear * linearT
        }

        // 3. Ease-out phase: [linearEnd, 1]
        if T2 > 0 {
            let localT = (tClamped - linearEnd) / T2
            let area = SplineAnimator.integrate(curve: easeOutCurve, upTo: localT, steps: 100)
            return easeInArea + linearArea + v_linear * area * T2
        }

        // Fallback
        return 1.0
    }

    func position(at elapsedTime: Float) -> SIMD3<Float> {
        let normT = normalizedTime(for: elapsedTime)
        let arcFraction = distanceFraction(at: normT)
        return spline.point(atFraction: arcFraction)
    }

    func normalizedProgress(at elapsedTime: Float) -> Float {
        return normalizedTime(for: elapsedTime)
    }
}

// MARK: - Example Curves

struct VelocityCurves {
    static let linear: (Float) -> Float = { _ in 1 }
    static let quadraticIn: (Float) -> Float = { t in t * t }
    static let quadraticOut: (Float) -> Float = { t in (1 - t) * (1 - t) }
    static let cubicIn: (Float) -> Float = { t in t * t * t }
    static let cubicOut: (Float) -> Float = { t in (1 - t) * (1 - t) * (1 - t) }
    static func mirrored(_ curve: @escaping (Float) -> Float) -> (Float) -> Float {
        return { t in curve(1 - t) }
    }
}
