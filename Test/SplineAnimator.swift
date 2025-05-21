//
//  SplineAnimator.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//
import simd
import QuartzCore

private func integrate(_ f: (Float) -> Float, from: Float, to: Float, steps: Int = 50) -> Float {
    var sum: Float = 0
    let dt = (to - from) / Float(steps)
    for i in 0..<steps {
        let t0 = from + Float(i) * dt
        let t1 = from + Float(i + 1) * dt
        sum += 0.5 * (f(t0) + f(t1)) * dt
    }
    return sum
}

public class SplineAnimator {
    public let spline: Spline3D
    public let duration: Float
    public let easeInTime: Float
    public let easeOutTime: Float
    public let easeInFunc: (Float) -> Float
    public let easeOutFunc: (Float) -> Float
    public let midFunc: (Float) -> Float

    // Precomputed region areas and distances
    private let easeInArea: Float
    private let easeOutArea: Float
    private let easeInDistance: Float
    private let easeOutDistance: Float
    private let linearTime: Float
    private let linearDistance: Float
    private let totalDistance: Float

    public private(set) var startTime: Double = 0

    public init(
        spline: Spline3D,
        duration: Float,
        easeIn: Float = 0.0,   // as a fraction of total time (0..1)
        easeOut: Float = 0.0,  // as a fraction of total time (0..1)
        easeInFunc: @escaping (Float) -> Float = Easing.easeIn,
        easeOutFunc: @escaping (Float) -> Float = Easing.easeOut,
        midFunc: @escaping (Float) -> Float = Easing.linear
    ) {
        self.spline = spline
        self.duration = duration
        self.easeInTime = min(max(0, easeIn), 1)
        self.easeOutTime = min(max(0, easeOut), 1 - easeIn)
        self.linearTime = max(0, 1 - self.easeInTime - self.easeOutTime)
        self.easeInFunc = easeInFunc
        self.easeOutFunc = easeOutFunc
        self.midFunc = midFunc
        self.startTime = CACurrentMediaTime()

        self.easeInArea = self.easeInTime > 0 ? integrate(easeInFunc, from: 0, to: 1, steps: 100) : 0
        self.easeOutArea = self.easeOutTime > 0 ? integrate(easeOutFunc, from: 0, to: 1, steps: 100) : 0
        self.easeInDistance = self.easeInTime * self.easeInArea
        self.easeOutDistance = self.easeOutTime * self.easeOutArea
        self.linearDistance = max(0, 1 - (self.easeInDistance + self.easeOutDistance))
        self.totalDistance = self.easeInDistance + self.linearDistance + self.easeOutDistance
    }

    public func position(now: Double? = nil) -> SIMD3<Float> {
        let t = progress(now: now)
        let d = distanceFraction(for: t)
        return spline.point(atFraction: d)
    }

    public func progress(now: Double? = nil) -> Float {
        let currentTime = Float((now ?? CACurrentMediaTime()) - startTime)
        let rawT = currentTime / duration
        return rawT.truncatingRemainder(dividingBy: 1)
    }

    public func distanceFraction(for t: Float) -> Float {
        // Safety for edge cases
        if totalDistance <= 0 { return 0 }
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }

        if t < easeInTime && easeInTime > 0 {
            // Ease-in region
            let localT = t / easeInTime
            let area = integrate(easeInFunc, from: 0, to: localT, steps: 50)
            let easeInSoFar = easeInTime * area
            return min(1, (easeInSoFar) / totalDistance)
        } else if t > 1 - easeOutTime && easeOutTime > 0 {
            // Ease-out region
            let localT = (t - (1 - easeOutTime)) / easeOutTime
            let area = integrate(easeOutFunc, from: 0, to: localT, steps: 50)
            let easeOutSoFar = easeOutTime * area
            let distToLinearEnd = easeInDistance + linearDistance
            return min(1, (distToLinearEnd + easeOutSoFar) / totalDistance)
        } else {
            // Linear region
            let t0 = easeInTime
            let t1 = 1 - easeOutTime
            let localT = (t - t0) / (t1 - t0)
            let distToLinearStart = easeInDistance
            let linearSoFar = localT * linearDistance
            return min(1, (distToLinearStart + linearSoFar) / totalDistance)
        }
    }

    public func restart(at now: Double = CACurrentMediaTime()) {
        self.startTime = now
    }
}

