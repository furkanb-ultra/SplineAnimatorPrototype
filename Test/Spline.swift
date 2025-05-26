//
//  Spline.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//
import Foundation
import simd

public struct Spline3D {
    public let points: [SIMD3<Float>]
    private let splineX: CubicSpline
    private let splineY: CubicSpline
    private let splineZ: CubicSpline
    public let totalLength: Float
    private let arcLengthLUT: [(t: Float, length: Float)]

    public init(_ points: [SIMD3<Float>], lutResolution: Int = 500) {
        precondition(points.count >= 2, "Need at least 2 points for a spline")
        self.points = points

        let tValues = (0..<points.count).map { Float($0) }

        splineX = CubicSpline(x: tValues, y: points.map { $0.x })
        splineY = CubicSpline(x: tValues, y: points.map { $0.y })
        splineZ = CubicSpline(x: tValues, y: points.map { $0.z })

        // Temporary arc-length LUT calculation
        var table: [(Float, Float)] = [(0, 0)]
        var length: Float = 0
        var lastPt = SIMD3<Float>(
            splineX.interpolate(at: 0),
            splineY.interpolate(at: 0),
            splineZ.interpolate(at: 0)
        )

        for i in 1...lutResolution {
            let t = Float(i) / Float(lutResolution)
            let scaledT = t * Float(points.count - 1)
            let pt = SIMD3<Float>(
                splineX.interpolate(at: scaledT),
                splineY.interpolate(at: scaledT),
                splineZ.interpolate(at: scaledT)
            )
            length += simd_distance(pt, lastPt)
            table.append((t, length))
            lastPt = pt
        }

        arcLengthLUT = table
        totalLength = length
    }

    public func point(atFraction fraction: Float) -> SIMD3<Float> {
        let clampedFraction = max(0, min(1, fraction))
        let targetLength = clampedFraction * totalLength
        let table = arcLengthLUT

        if targetLength <= 0 { return pointRaw(at: 0) }
        if targetLength >= totalLength { return pointRaw(at: 1) }

        // Binary search
        var low = 0, high = table.count - 1
        while low < high {
            let mid = (low + high) / 2
            if table[mid].length < targetLength {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let idx = max(1, low)
        let (t0, l0) = table[idx - 1]
        let (t1, l1) = table[idx]
        let alpha = (targetLength - l0) / (l1 - l0)
        let t = t0 + (t1 - t0) * alpha

        return pointRaw(at: t)
    }

    // NEW: Calculate tangent (forward direction) at any point on the spline
    public func tangent(atFraction fraction: Float) -> SIMD3<Float> {
        let clampedFraction = max(0, min(1, fraction))
        
        // Use small epsilon for numerical differentiation
        let epsilon: Float = 0.001
        let t1 = max(0, clampedFraction - epsilon/2)
        let t2 = min(1, clampedFraction + epsilon/2)
        
        let p1 = point(atFraction: t1)
        let p2 = point(atFraction: t2)
        
        let tangent = p2 - p1
        let length = simd_length(tangent)
        
        // Return normalized tangent, or default forward if zero length
        if length > 0.0001 {
            return tangent / length
        } else {
            return SIMD3<Float>(0, 0, -1) // Default forward direction
        }
    }

    private func pointRaw(at t: Float) -> SIMD3<Float> {
        let scaledT = t * Float(points.count - 1)
        return SIMD3<Float>(
            splineX.interpolate(at: scaledT),
            splineY.interpolate(at: scaledT),
            splineZ.interpolate(at: scaledT)
        )
    }
}

private class CubicSpline {
    let x: [Float]
    let y: [Float]
    let m: [Float]

    init(x: [Float], y: [Float]) {
        let n = x.count
        precondition(n > 1 && y.count == n)

        self.x = x
        self.y = y

        var h = [Float](repeating: 0, count: n-1)
        var alpha = [Float](repeating: 0, count: n-1)

        for i in 0..<n-1 {
            h[i] = x[i+1] - x[i]
        }

        for i in 1..<n-1 {
            alpha[i] = (3/h[i])*(y[i+1]-y[i]) - (3/h[i-1])*(y[i]-y[i-1])
        }

        var l = [Float](repeating: 1, count: n)
        var mu = [Float](repeating: 0, count: n)
        var z = [Float](repeating: 0, count: n)

        for i in 1..<n-1 {
            l[i] = 2*(x[i+1]-x[i-1]) - h[i-1]*mu[i-1]
            mu[i] = h[i]/l[i]
            z[i] = (alpha[i] - h[i-1]*z[i-1])/l[i]
        }

        var cVec = [Float](repeating: 0, count: n)
        var bVec = [Float](repeating: 0, count: n-1)
        var dVec = [Float](repeating: 0, count: n-1)

        for j in stride(from: n-2, through: 0, by: -1) {
            cVec[j] = z[j] - mu[j]*cVec[j+1]
            bVec[j] = (y[j+1]-y[j])/h[j] - h[j]*(cVec[j+1]+2*cVec[j])/3
            dVec[j] = (cVec[j+1]-cVec[j])/(3*h[j])
        }

        self.m = cVec
        self.b = bVec
        self.d = dVec
    }

    func interpolate(at xVal: Float) -> Float {
        let i = min(max(Int(xVal), 0), x.count-2)
        let dx = xVal - x[i]
        return y[i] + b[i]*dx + m[i]*dx*dx + d[i]*dx*dx*dx
    }

    private let b: [Float]
    private let d: [Float]
}
