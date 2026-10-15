import CoreGraphics
import Foundation

/// Recognizes a quick left-right shake in a stream of mouse positions (the shelf's trigger).
///
/// A shake is `reversalsNeeded` changes of horizontal direction within `window` seconds, where
/// every swing covers at least `minimumSwing` points and goes more sideways than up or down.
/// Coming back less than `hysteresis` points is noise, not a reversal.
struct ShakeDetector {
    var minimumSwing: CGFloat
    var window: TimeInterval
    var reversalsNeeded: Int
    var hysteresis: CGFloat

    private var swingStart: CGPoint?
    private var extreme: CGPoint = .zero
    /// -1 left, +1 right, 0 not moving yet.
    private var direction: CGFloat = 0
    private var reversals: [TimeInterval] = []
    private var fired = false

    init(minimumSwing: CGFloat = 30, window: TimeInterval = 0.6, reversalsNeeded: Int = 3, hysteresis: CGFloat = 6) {
        self.minimumSwing = minimumSwing
        self.window = window
        self.reversalsNeeded = reversalsNeeded
        self.hysteresis = hysteresis
    }

    /// Forgets the movement so far (a new drag started, or the mouse button came up).
    mutating func reset() {
        swingStart = nil
        extreme = .zero
        direction = 0
        reversals.removeAll()
        fired = false
    }

    /// Feeds one mouse position. Returns true once per drag, when the movement amounts to a shake.
    mutating func add(_ point: CGPoint, at time: TimeInterval) -> Bool {
        guard let start = swingStart else {
            swingStart = point
            extreme = point
            return false
        }
        if direction == 0 {
            let dx = point.x - start.x
            if abs(dx) >= hysteresis {
                direction = dx > 0 ? 1 : -1
                extreme = point
            }
            return false
        }
        // Still going the same way: the swing gets longer.
        if (point.x - extreme.x) * direction >= 0 {
            extreme = point
            return false
        }
        guard abs(point.x - extreme.x) >= hysteresis else { return false }

        // A reversal: judge the swing that just ended.
        let horizontal = abs(extreme.x - start.x)
        let vertical = abs(extreme.y - start.y)
        if horizontal >= minimumSwing, horizontal > vertical {
            reversals.append(time)
        } else {
            reversals.removeAll()
        }
        reversals.removeAll { time - $0 > window }
        direction = -direction
        swingStart = extreme
        extreme = point
        guard !fired, reversals.count >= reversalsNeeded else { return false }
        fired = true
        return true
    }
}
