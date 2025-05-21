//
//  Spline.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//

import simd

/// Minimal Catmull-Rom spline that works for any number of points ≥ 2
public struct Spline3D {
    public let points: [SIMD3<Float>]
    private let arcLengthLUT: [(t: Float, length: Float)]
    public let totalLength: Float

    public init(_ points: [SIMD3<Float>], lutResolution: Int = 100) {
        precondition(points.count >= 2, "Need at least 2 points for a spline")
        self.points = points

        // --- Call static method instead of self
        let (lut, len) = Spline3D.computeArcLengthLUT(points: points, lutResolution: lutResolution)
        self.arcLengthLUT = lut
        self.totalLength = len
    }
    
    /// Static, so doesn't require fully-initialized self
    private static func computeArcLengthLUT(points: [SIMD3<Float>], lutResolution: Int) -> ([(Float, Float)], Float) {
        func pointRaw(_ points: [SIMD3<Float>], _ t: Float) -> SIMD3<Float> {
            let clampedT = max(0, min(1, t))
            let n = points.count

            if n == 2 {
                return points[0] * (1 - clampedT) + points[1] * clampedT
            }
            if n == 3 {
                let a = points[0] * (1 - clampedT) + points[1] * clampedT
                let b = points[1] * (1 - clampedT) + points[2] * clampedT
                return a * (1 - clampedT) + b * clampedT
            }
            let segments = n - 3
            let tScaled = clampedT * Float(segments)
            let seg = min(Int(tScaled), segments - 1)
            let localT = tScaled - Float(seg)
            let p0 = points[seg]
            let p1 = points[seg + 1]
            let p2 = points[seg + 2]
            let p3 = points[seg + 3]
            let tt = localT
            let tt2 = tt * tt
            let tt3 = tt2 * tt
            let a = (2*p0 - 5*p1 + 4*p2 - p3)
            let b = (-p0 + 3*p1 - 3*p2 + p3)
            
            return 0.5 * ((2 * p1) + (-p0 + p2) * tt + a * tt2 + b * tt3 )
        }

        var lastPt = pointRaw(points, 0)
        var table: [(Float, Float)] = [(0, 0)]
        var length: Float = 0
        for i in 1...lutResolution {
            let t = Float(i) / Float(lutResolution)
            let pt = pointRaw(points, t)
            length += simd_distance(pt, lastPt)
            table.append((t, length))
            lastPt = pt
        }
        return (table, length)
    }
    
    /// Sample the spline by spatial distance, not parameter t.
    public func point(atFraction fraction: Float) -> SIMD3<Float> {
        let clampedFraction = max(0, min(1, fraction))
        let targetLength = clampedFraction * totalLength
        let table = arcLengthLUT
        if targetLength <= 0 { return pointRaw(at: 0) }
        if targetLength >= totalLength { return pointRaw(at: 1) }

        // Binary search for performance (optional)
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

    public func pointRaw(at t: Float) -> SIMD3<Float> {
        let clampedT = max(0, min(1, t))
        let n = points.count

        if n == 2 {
            return points[0] * (1 - clampedT) + points[1] * clampedT
        }
        if n == 3 {
            let a = points[0] * (1 - clampedT) + points[1] * clampedT
            let b = points[1] * (1 - clampedT) + points[2] * clampedT
            return a * (1 - clampedT) + b * clampedT
        }
        let segments = n - 3
        let tScaled = clampedT * Float(segments)
        let seg = min(Int(tScaled), segments - 1)
        let localT = tScaled - Float(seg)
        let p0 = points[seg]
        let p1 = points[seg + 1]
        let p2 = points[seg + 2]
        let p3 = points[seg + 3]
        let tt = localT
        let tt2 = tt * tt
        let tt3 = tt2 * tt
        let a = (2*p0 - 5*p1 + 4*p2 - p3)
        let b = (-p0 + 3*p1 - 3*p2 + p3)
        
        return 0.5 * ((2 * p1) + (-p0 + p2) * tt + a * tt2 + b * tt3 )
    }
}

