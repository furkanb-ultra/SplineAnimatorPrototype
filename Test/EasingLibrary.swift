//
//  EasingLibrary.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//

import Foundation

public func customEase(
    t: Float,
    easeIn: Float,
    easeOut: Float,
    easeInFunc: (Float) -> Float = Easing.easeIn,
    easeOutFunc: (Float) -> Float = Easing.easeOut,
    midFunc: (Float) -> Float = Easing.linear
) -> Float {
    let tClamped = max(0, min(1, t))
    if tClamped < easeIn, easeIn > 0 {
        // Map [0, easeIn] → [0,1] for easeInFunc
        let localT = tClamped / easeIn
        return easeIn * easeInFunc(localT)
    } else if tClamped > 1 - easeOut, easeOut > 0 {
        // Map [1-easeOut, 1] → [0,1] for easeOutFunc
        let localT = (tClamped - (1 - easeOut)) / easeOut
        return (1 - easeOut) + easeOut * easeOutFunc(localT)
    } else if easeIn + easeOut < 1 {
        // Mid region: linear or other
        let midT = (tClamped - easeIn) / (1 - easeIn - easeOut)
        return easeIn + (1 - easeIn - easeOut) * midFunc(midT)
    } else {
        // Fallback to linear
        return tClamped
    }
}

public struct Easing {
    public static func linear(_ t: Float) -> Float { t }
    public static func easeIn(_ t: Float) -> Float { t * t }
    public static func easeOut(_ t: Float) -> Float { t * (2 - t) }
    public static func easeInOut(_ t: Float) -> Float {
        t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
    public static func cubicEaseIn(_ t: Float) -> Float { t * t * t }
    public static func cubicEaseOut(_ t: Float) -> Float {
        let f = t - 1; return f * f * f + 1
    }
    public static func cubicEaseInOut(_ t: Float) -> Float {
        t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
    }
    // Add more as you wish!
}
