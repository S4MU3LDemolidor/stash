import CoreGraphics
import Foundation
import Testing
@testable import Stash

@Suite("Shake detection")
struct ShakeDetectorTests {
    /// Moves through `points` (8 samples per swing, `swing` seconds each); returns how often it fired.
    private func run(_ points: [CGPoint], swing: TimeInterval = 0.1, start: TimeInterval = 0, detector: inout ShakeDetector) -> Int {
        var fired = 0
        var time = start
        var current = points[0]
        if detector.add(current, at: time) { fired += 1 }
        for target in points.dropFirst() {
            let from = current
            for step in 1...8 {
                time += swing / 8
                let t = CGFloat(step) / 8
                current = CGPoint(x: from.x + (target.x - from.x) * t, y: from.y + (target.y - from.y) * t)
                if detector.add(current, at: time) { fired += 1 }
            }
        }
        return fired
    }

    private func swings(_ xs: [CGFloat], y: CGFloat = 300) -> [CGPoint] { xs.map { CGPoint(x: $0, y: y) } }

    @Test func aQuickShakeFires() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 560, 500, 560, 500, 560]), detector: &detector) == 1)
    }

    @Test func keepShakingFiresOnlyOnce() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 560, 500, 560, 500, 560, 500, 560, 500, 560]), detector: &detector) == 1)
    }

    @Test func twoReversalsAreNotEnough() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 560, 500, 560]), detector: &detector) == 0)
    }

    @Test func aSlowWiggleDoesNotFire() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 560, 500, 560, 500, 560]), swing: 0.35, detector: &detector) == 0)
    }

    @Test func smallJitterDoesNotFire() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 515, 500, 515, 500, 515, 500]), detector: &detector) == 0)
    }

    @Test func verticalScrubbingDoesNotFire() {
        var detector = ShakeDetector()
        let path = [CGPoint(x: 500, y: 300), CGPoint(x: 540, y: 420), CGPoint(x: 500, y: 300),
                    CGPoint(x: 540, y: 420), CGPoint(x: 500, y: 300), CGPoint(x: 540, y: 420)]
        #expect(run(path, detector: &detector) == 0)
    }

    @Test func resetAllowsAnotherShake() {
        var detector = ShakeDetector()
        #expect(run(swings([500, 560, 500, 560, 500, 560]), detector: &detector) == 1)
        detector.reset()
        #expect(run(swings([500, 560, 500, 560, 500, 560]), start: 5, detector: &detector) == 1)
    }
}
