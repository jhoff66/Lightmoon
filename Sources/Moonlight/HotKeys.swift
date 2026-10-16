import Carbon.HIToolbox

/// Atalhos globais via Carbon, que não exigem permissão de Acessibilidade.
final class HotKeys {
  enum Action: UInt32 {
    case brightnessUp = 1, brightnessDown, warmthUp, warmthDown
  }

  static let shared = HotKeys()
  var handler: ((Action) -> Void)?

  private var refs: [EventHotKeyRef] = []
  private var handlerInstalled = false

  func setEnabled(_ enabled: Bool) {
    refs.forEach { UnregisterEventHotKey($0) }
    refs.removeAll()
    guard enabled else { return }
    installHandlerIfNeeded()
    let modifiers = UInt32(controlKey | optionKey | shiftKey)
    let keys: [(Int, Action)] = [
      (kVK_UpArrow, .brightnessUp), (kVK_DownArrow, .brightnessDown),
      (kVK_RightArrow, .warmthUp), (kVK_LeftArrow, .warmthDown),
    ]
    for (key, action) in keys {
      var ref: EventHotKeyRef?
      let id = EventHotKeyID(signature: OSType(0x4C4D_4F4E), id: action.rawValue)
      if RegisterEventHotKey(UInt32(key), modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
        refs.append(ref)
      }
    }
  }

  private func installHandlerIfNeeded() {
    guard !handlerInstalled else { return }
    handlerInstalled = true
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
      var id = EventHotKeyID()
      GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                        nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
      if let action = Action(rawValue: id.id) {
        HotKeys.shared.handler?(action)
      }
      return noErr
    }, 1, &spec, nil, nil)
  }
}
