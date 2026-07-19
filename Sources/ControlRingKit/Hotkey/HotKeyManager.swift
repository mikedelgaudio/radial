import Carbon.HIToolbox
import AppKit

public final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onFire: (() -> Void)?
    private let signature: FourCharCode = 0x43526e67 // 'CRng'

    public init() {}

    public func register(_ spec: HotKeySpec, onFire: @escaping () -> Void) {
        unregister()
        self.onFire = onFire

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            DispatchQueue.main.async { manager.onFire?() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(UInt32(spec.keyCode), spec.carbonModifierFlags,
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    public func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let eventHandler { RemoveEventHandler(eventHandler); self.eventHandler = nil }
    }

    deinit { unregister() }
}
