import Carbon.HIToolbox
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()
    var onActivate: (() -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func register() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let ptr = userInfo else { return Unmanaged.passRetained(event) }
                let mgr = Unmanaged<HotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags
                let isCmd = flags.contains(.maskCommand)
                let isShift = flags.contains(.maskShift)
                let isSpace = keyCode == Int64(kVK_Space)
                if isCmd && isShift && isSpace {
                    DispatchQueue.main.async { mgr.onActivate?() }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        )
        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func unregister() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
    }

    deinit { unregister() }
}
