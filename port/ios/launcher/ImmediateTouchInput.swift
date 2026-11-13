// UIKit input updates the native pad before SwiftUI redraws or haptics run.
// GPL-3.0-or-later
import SwiftUI
import UIKit

// Shared multi-touch coordinator: allows a finger to roll/drag between action buttons
// without lifting, activating the new button instantly while releasing the previous one.
final class TouchGlidingRouter {
    static let shared = TouchGlidingRouter()

    private final class Target {
        let id: TouchControlID
        weak var view: UIView?
        var haptics: Bool
        var setPressed: (Bool) -> Void
        init(id: TouchControlID, view: UIView, haptics: Bool, setPressed: @escaping (Bool) -> Void) {
            self.id = id
            self.view = view
            self.haptics = haptics
            self.setPressed = setPressed
        }
    }

    private var targets: [Target] = []
    // Each finger owns exactly one face button, even when layouts have overlapping
    // 600% hit boxes. Different fingers may still press separate buttons at once.
    private var activeTouches: [ObjectIdentifier: TouchControlID] = [:]
    // Remember fingers that moved off every button so they can re-enter later.
    private var outsideTouches: Set<ObjectIdentifier> = []

    func register(id: TouchControlID, view: UIView, haptics: Bool, setPressed: @escaping (Bool) -> Void) {
        unregister(view: view)
        targets.append(Target(id: id, view: view, haptics: haptics, setPressed: setPressed))
    }

    func unregister(view: UIView) {
        targets.removeAll { $0.view == nil || $0.view === view }
    }

    private func nearestTarget(at point: CGPoint, window: UIWindow, margin: CGFloat) -> Target? {
        var closest: Target?
        var nearest = CGFloat.infinity
        for target in targets {
            guard let view = target.view, view.window === window,
                  !view.isHidden, view.alpha > 0, view.isUserInteractionEnabled else { continue }
            let position = view.convert(point, from: window)
            guard view.bounds.insetBy(dx: -margin, dy: -margin).contains(position) else { continue }
            let dx = position.x - view.bounds.midX, dy = position.y - view.bounds.midY
            let distance = dx * dx + dy * dy
            if distance < nearest {
                nearest = distance
                closest = target
            }
        }
        return closest
    }

    private func isHeld(_ id: TouchControlID, except touchId: ObjectIdentifier? = nil) -> Bool {
        activeTouches.contains { key, value in
            key != touchId && !outsideTouches.contains(key) && value == id
        }
    }

    private func setButton(_ id: TouchControlID, pressed: Bool) {
        touch_input_set_button(id, pressed)
        for target in targets where target.id == id { target.setPressed(pressed) }
    }

    private func activate(_ id: TouchControlID, touchId: ObjectIdentifier, target: Target?) {
        if !isHeld(id, except: touchId) { setButton(id, pressed: true) }
        if let target = target, target.haptics {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func touchBegan(_ touch: UITouch, on view: UIView, id: TouchControlID) {
        let key = ObjectIdentifier(touch)
        guard activeTouches[key] == nil else { return }
        let target = view.window.flatMap { window in
            nearestTarget(at: touch.location(in: window), window: window, margin: 0)
        }
        let chosen = target?.id ?? id
        activeTouches[key] = chosen
        outsideTouches.remove(key)
        activate(chosen, touchId: key, target: target ?? targets.first(where: { $0.view === view }))
    }

    func touchMoved(_ touch: UITouch, from view: UIView) {
        guard let window = view.window else { return }
        let key = ObjectIdentifier(touch)
        guard let previous = activeTouches[key] else { return }
        let point = touch.location(in: window)
        var chosen = nearestTarget(at: point, window: window, margin: 12)
        if chosen == nil, let existing = targets.first(where: { $0.id == previous }),
           let current = existing.view, current.window === window {
            let local = current.convert(point, from: window)
            if current.bounds.insetBy(dx: -18, dy: -18).contains(local) { chosen = existing }
        }
        let next = chosen?.id
        let wasActive = !outsideTouches.contains(key)
        if wasActive && next == previous { return }
        // Release the previous action only when this was the last finger on it.
        // Exclude the finger being moved before checking other owners.
        if wasActive {
            outsideTouches.insert(key)
            if !isHeld(previous, except: key) { setButton(previous, pressed: false) }
        }
        if let next {
            activeTouches[key] = next
            activate(next, touchId: key, target: chosen)
            outsideTouches.remove(key)
        } // Otherwise, keep the touch alive but inactive until it returns.
    }

    func touchEnded(_ touch: UITouch) {
        let key = ObjectIdentifier(touch)
        let wasOutside = outsideTouches.remove(key) != nil
        guard let id = activeTouches.removeValue(forKey: key) else { return }
        if !wasOutside && !isHeld(id) { setButton(id, pressed: false) }
    }

    func reset() {
        activeTouches.removeAll()
        outsideTouches.removeAll()
        for target in targets { target.setPressed(false) }
    }
}

struct ImmediateTouchInput: UIViewRepresentable {
    var controlID: TouchControlID? = nil
    var haptics: Bool = false
    var onDown: (CGPoint, CGSize) -> Void
    var onMove: (CGPoint, CGPoint, CGSize) -> Void = { _, _, _ in }
    var onUp: () -> Void
    var onVisualPressed: ((Bool) -> Void)? = nil

    func makeUIView(context: Context) -> ImmediateTouchView {
        let view = ImmediateTouchView()
        view.backgroundColor = .clear
        view.controlID = controlID
        view.isMultipleTouchEnabled = controlID != nil
        view.haptics = haptics
        view.onDown = onDown
        view.onMove = onMove
        view.onUp = onUp
        view.onVisualPressed = onVisualPressed
        return view
    }

    func updateUIView(_ view: ImmediateTouchView, context: Context) {
        view.controlID = controlID
        view.isMultipleTouchEnabled = controlID != nil
        view.haptics = haptics
        view.onDown = onDown
        view.onMove = onMove
        view.onUp = onUp
        view.onVisualPressed = onVisualPressed
        if let cid = controlID, view.window != nil {
            TouchGlidingRouter.shared.register(id: cid, view: view, haptics: haptics) { [weak view] pressed in
                view?.onVisualPressed?(pressed)
            }
        }
    }

    static func dismantleUIView(_ view: ImmediateTouchView, coordinator: ()) {
        view.releaseInput()
        TouchGlidingRouter.shared.unregister(view: view)
    }
}

final class ImmediateTouchView: UIView {
    var controlID: TouchControlID?
    var haptics: Bool = false
    var onDown: (CGPoint, CGSize) -> Void = { _, _ in }
    var onMove: (CGPoint, CGPoint, CGSize) -> Void = { _, _, _ in }
    var onUp: () -> Void = {}
    var onVisualPressed: ((Bool) -> Void)?
    private var buttonFingers = Set<UITouch>()
    private var finger: UITouch?
    private var origin = CGPoint.zero

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let cid = controlID {
            buttonFingers.formUnion(touches)
            for touch in touches { TouchGlidingRouter.shared.touchBegan(touch, on: self, id: cid) }
            return
        }
        guard finger == nil, let touch = touches.first else { return }
        finger = touch
        origin = touch.location(in: self)
        onDown(origin, bounds.size)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where buttonFingers.contains(touch) {
            TouchGlidingRouter.shared.touchMoved(touch, from: self)
        }
        guard let finger = finger, touches.contains(finger) else { return }
        onMove(finger.location(in: self), origin, bounds.size)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouches(touches) }

    private func endTouches(_ touches: Set<UITouch>) {
        for touch in touches where buttonFingers.remove(touch) != nil {
            TouchGlidingRouter.shared.touchEnded(touch)
        }
        if let finger, touches.contains(finger) { releaseInput() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            releaseInput()
            TouchGlidingRouter.shared.unregister(view: self)
        } else if let cid = controlID {
            TouchGlidingRouter.shared.register(id: cid, view: self, haptics: haptics) { [weak self] pressed in
                self?.onVisualPressed?(pressed)
            }
        }
    }

    func releaseInput() {
        for touch in buttonFingers { TouchGlidingRouter.shared.touchEnded(touch) }
        buttonFingers.removeAll()
        guard finger != nil else { return }
        finger = nil
        onUp()
    }
}

// Observe every phone touch, including the black screen and the first reveal tap.
// This recognizer never recognizes, prevents, cancels or delays another control.
private final class TouchActivityRecognizer: UIGestureRecognizer {
    var activity: (Bool, Int) -> Void = { _, _ in }
    private var fingers = Set<UITouch>()
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        fingers.formUnion(touches)
        activity(true, fingers.count)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { activity(true, fingers.count) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        fingers.subtract(touches)
        activity(false, fingers.count)
        if fingers.isEmpty { state = .failed }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        fingers.subtract(touches)
        activity(false, fingers.count)
        if fingers.isEmpty { state = .failed }
    }
    override func reset() { fingers.removeAll(); super.reset() }
}

struct PhoneTouchActivityObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> PhoneTouchObserverView { PhoneTouchObserverView() }
    func updateUIView(_ view: PhoneTouchObserverView, context: Context) {}
    static func dismantleUIView(_ view: PhoneTouchObserverView, coordinator: ()) { view.detach() }
}
final class PhoneTouchObserverView: UIView {
    private let observer = TouchActivityRecognizer()
    private weak var observedWindow: UIWindow?
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        observer.cancelsTouchesInView = false
        observer.delaysTouchesBegan = false
        observer.delaysTouchesEnded = false
        observer.activity = { began, count in
            LauncherModel.shared.phoneTouchActivity(began: began, count: count)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        observedWindow = window
        window?.addGestureRecognizer(observer)
    }
    func detach() {
        observedWindow?.removeGestureRecognizer(observer)
        observedWindow = nil
    }
}
