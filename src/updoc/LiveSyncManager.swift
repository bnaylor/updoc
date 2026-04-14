import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
public class LiveSyncManager {
    public var activeNote: Note?
    public var currentInterval: TimeInterval = 30.0
    public var isSyncing: Bool = false
    
    public var isFastPolling: Bool {
        return currentInterval < lazyInterval
    }
    
    private var timer: Timer?
    private let lazyInterval: TimeInterval = 30.0
    private let aggressiveInterval: TimeInterval = 2.0
    
    public init() {}
    
    public func start(for note: Note) {
        guard note.googleDocId != nil else {
            stop()
            return
        }
        
        // If we are already polling the same note, do nothing
        if let current = activeNote, current.id == note.id {
            return
        }
        
        stop()
        self.activeNote = note
        self.currentInterval = lazyInterval
        scheduleTimer()
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        activeNote = nil
    }
    
    private func scheduleTimer() {
        timer?.invalidate()
        
        timer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.performSync()
            }
        }
    }
    
    private func performSync() {
        guard let note = activeNote else { return }
        
        // Let the app know we want a background sync
        // The ContentView will catch this and run a sync without showing the manual spinner
        NotificationCenter.default.post(name: .backgroundSyncRequested, object: note)
    }
    
    public func remoteEditDetected() {
        // Drop to aggressive interval and poll quickly
        currentInterval = aggressiveInterval
        scheduleTimer()
    }
    
    public func noRemoteEditDetected() {
        // Exponential backoff, capped at the lazy interval
        currentInterval = min(currentInterval * 1.5, lazyInterval)
        scheduleTimer()
    }
}
