//
//  SimpleSplineAnimator.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//
import Foundation
import simd

/// Velocity-matched, arc-length-correct spline animator with looping and ping-pong options.
/// Use velocity curves (not progress curves!) for ease-in/ease-out.
/// See the bottom for ready-to-use quadratic and cubic velocity curves.

final class SplineAnimator {
    let spline: Spline3D
    let duration: Float

    let easeInDuration: Float      // e.g. 0.2 means 20% of animation is ease-in
    let easeOutDuration: Float     // e.g. 0.1 means last 10% is ease-out
    let easeInCurve: (Float) -> Float   // velocity profile: t in 0...1 → velocity in 0...1
    let easeOutCurve: (Float) -> Float  // velocity profile: t in 0...1 → velocity in 1...0

    let isLooping: Bool
    let isPingPong: Bool

    // Precomputed areas and matched linear speed
    let A_in: Float
    let A_out: Float
    let v_linear: Float
    let Tc: Float // central linear portion

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
        self.easeInDuration = easeInDuration
        self.easeOutDuration = easeOutDuration
        self.easeInCurve = easeInCurve
        self.easeOutCurve = easeOutCurve
        self.isLooping = isLooping
        self.isPingPong = isPingPong

        let T1 = easeInDuration
        let T2 = easeOutDuration
        let Tc = max(0, 1.0 - T1 - T2)
        self.Tc = Tc

        self.A_in = SplineAnimator.integrate(curve: easeInCurve, steps: 100)
        self.A_out = SplineAnimator.integrate(curve: easeOutCurve, steps: 100)
        // Compute linear velocity so that area under the whole velocity curve is 1.0
        self.v_linear = 1.0 / (A_in * T1 + Tc + A_out * T2)
    }

    /// Integrate curve from 0 to 1.
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

    /// Integrate curve from 0 to `localT` (used for partial area).
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
            // Standard loop (0→1, 0→1, ...)
            let t = fmodf(elapsedTime, duration) / duration
            return t
        } else {
            // Ping-pong (0→1, 1→0, ...)
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

    /// Returns the *arc-length fraction* (distance fraction) at a given normalized time t in [0,1].
    /// (This is what you pass to your Spline3D to get position.)
    func distanceFraction(at t: Float) -> Float {
        let T1 = easeInDuration
        let T2 = easeOutDuration
        let Tc = self.Tc
        let tClamped = min(max(t, 0), 1)

        if tClamped <= T1, T1 > 0 {
            // Ease-in phase
            let localT = tClamped / T1
            let area = SplineAnimator.integrate(
                curve: easeInCurve,
                upTo: localT,
                steps: 50
            )
            return v_linear * area * T1
        } else if tClamped < (1 - T2), Tc > 0 {
            // Linear phase
            let easeInDistance = v_linear * A_in * T1
            let linearTime = tClamped - T1
            return easeInDistance + v_linear * linearTime
        } else if T2 > 0 {
            // Ease-out phase
            let easeInDistance = v_linear * A_in * T1
            let linearDistance = v_linear * Tc
            let localT = T2 == 0 ? 1 : (tClamped - (1 - T2)) / T2
            let area = SplineAnimator.integrate(
                curve: easeOutCurve,
                upTo: localT,
                steps: 50
            )
            return easeInDistance + linearDistance + v_linear * area * T2
        } else {
            // Should not occur, but fallback to end of spline
            return 1.0
        }
    }

    /// Main function: get position on the spline at the given elapsed time (seconds).
    func position(at elapsedTime: Float) -> SIMD3<Float> {
        let normT = normalizedTime(for: elapsedTime)
        let arcFraction = distanceFraction(at: normT)
        return spline.point(atFraction: arcFraction)
    }
}


/// Example quadratic and cubic velocity curves.
/// (Use these as easeInCurve. For easeOutCurve, use mirrored or as shown.)
struct VelocityCurves {
    static let linear: (Float) -> Float = { _ in 1 }
    static let quadraticIn: (Float) -> Float = { t in t * t }
    static let quadraticOut: (Float) -> Float = { t in (1 - t) * (1 - t) }
    static let cubicIn: (Float) -> Float = { t in t * t * t }
    static let cubicOut: (Float) -> Float = { t in (1 - t) * (1 - t) * (1 - t) }
    // You can also add s-curve, sinusoidal, etc, as needed.

    /// Helper to mirror a curve (for ease-out)
    static func mirrored(_ curve: @escaping (Float) -> Float) -> (Float) -> Float {
        return { t in curve(1 - t) }
    }
}
