//
//  TimelineProvider.swift
//  Test
//
//  Created by Furkan on 21/05/25.
//

import Foundation
import Combine

/// Simple timeline system for managing time-based events and animations
@Observable
final class TimelineProvider {
    private var startTime: Date?
    private var pausedTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    
    /// Current elapsed time in seconds since timeline started
    var currentTime: Float {
        guard let startTime = startTime else { return 0 }
        
        if let pausedTime = pausedTime {
            // We're paused, return time up to pause point
            return Float(pausedTime.timeIntervalSince(startTime) - totalPausedDuration)
        } else {
            // We're running, return current elapsed time
            return Float(Date().timeIntervalSince(startTime) - totalPausedDuration)
        }
    }
    
    /// Whether the timeline is currently running
    var isRunning: Bool {
        return startTime != nil && pausedTime == nil
    }
    
    /// Whether the timeline is paused
    var isPaused: Bool {
        return startTime != nil && pausedTime != nil
    }
    
    /// Start or resume the timeline
    func start() {
        if startTime == nil {
            // First start
            startTime = Date()
            totalPausedDuration = 0
        } else if let pausedTime = pausedTime {
            // Resume from pause
            totalPausedDuration += Date().timeIntervalSince(pausedTime)
            self.pausedTime = nil
        }
    }
    
    /// Pause the timeline
    func pause() {
        guard startTime != nil, pausedTime == nil else { return }
        pausedTime = Date()
    }
    
    /// Stop and reset the timeline
    func stop() {
        startTime = nil
        pausedTime = nil
        totalPausedDuration = 0
    }
    
    /// Reset timeline to beginning but keep running state
    func reset() {
        let wasRunning = isRunning
        stop()
        if wasRunning {
            start()
        }
    }
    
    /// Jump to specific time in seconds
    func seek(to time: Float) {
        let wasRunning = isRunning
        let now = Date()
        
        startTime = now.addingTimeInterval(-Double(time))
        pausedTime = wasRunning ? nil : now
        totalPausedDuration = 0
    }
}
