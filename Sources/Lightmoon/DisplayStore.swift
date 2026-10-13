import AppKit
import Combine
import ServiceManagement

struct DisplayInfo: Identifiable, Equatable {
  let id: CGDirectDisplayID
  let name: String
  let key: String
  let detail: String
  let aspect: CGFloat
  var brightness: Double
  var warmth: Double
}

struct Preset: Identifiable, Equatable {
  let id: String
  let title: String
  let symbol: String
  let brightness: Double
  let warmth: Double

  static let all: [Preset] = [
    Preset(id: "dia", title: "Dia", symbol: "sun.max.fill", brightness: 1.0, warmth: 0.0),
    Preset(id: "foco", title: "Foco", symbol: "scope", brightness: 0.8, warmth: 0.15),
    Preset(id: "noite", title: "Noite", symbol: "moon.fill", brightness: 0.5, warmth: 0.6),
    Preset(id: "cinema", title: "Cinema", symbol: "film.fill", brightness: 0.35, warmth: 0.3),
  ]
}

@MainActor
final class DisplayStore: ObservableObject {
  static let minBrightness = 0.1

  @Published var displays: [DisplayInfo] = []
  @Published var enabled: Bool
  @Published var linked: Bool
  @Published var activePreset: String?
  @Published var launchAtLogin = false

  private let live: Bool
  private let defaults = UserDefaults.standard
  private var base: [CGDirectDisplayID: GammaTable] = [:]
  private var tween: Task<Void, Never>?
  private var observers: [NSObjectProtocol] = []

  init(live: Bool = true) {
    self.live = live
    self.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
    self.linked = defaults.bool(forKey: "linked")
    self.activePreset = defaults.string(forKey: "preset")
    if live {
      // Parte de um estado limpo: sem isso, a tabela capturada pode já vir escurecida por outro app.
      Gamma.restoreAll()
      launchAtLogin = SMAppService.mainApp.status == .enabled
      observe()
    }
    refresh()
  }

  private func observe() {
    let reapply: @Sendable (Notification) -> Void = { [weak self] _ in
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.5))
        self?.refresh()
      }
    }
    observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main, using: reapply))
    observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: reapply))
    observers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
      Gamma.restoreAll()
    })
  }

  func refresh() {
    var found: [DisplayInfo] = []
    for screen in NSScreen.screens {
      guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
      let id = CGDirectDisplayID(number.uint32Value)
      guard CGDisplayIsBuiltin(id) == 0 else { continue }
      let key = "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
      let width = CGDisplayPixelsWide(id)
      let height = CGDisplayPixelsHigh(id)
      var detail = "\(width) × \(height)"
      if let mode = CGDisplayCopyDisplayMode(id), mode.refreshRate > 0 {
        detail += " · \(Int(mode.refreshRate.rounded())) Hz"
      }
      if live, base[id] == nil {
        base[id] = Gamma.capture(id)
      }
      found.append(DisplayInfo(
        id: id,
        name: screen.localizedName,
        key: key,
        detail: detail,
        aspect: height > 0 ? CGFloat(width) / CGFloat(height) : 16 / 9,
        brightness: defaults.object(forKey: "brightness.\(key)") as? Double ?? 1,
        warmth: defaults.object(forKey: "warmth.\(key)") as? Double ?? 0
      ))
    }
    displays = found
    applyAll()
  }

  // MARK: Ajustes

  func setBrightness(_ value: Double, for id: CGDirectDisplayID) {
    update(id) { $0.brightness = min(1, max(Self.minBrightness, value)) }
  }

  func setWarmth(_ value: Double, for id: CGDirectDisplayID) {
    update(id) { $0.warmth = min(1, max(0, value)) }
  }

  private func update(_ id: CGDirectDisplayID, _ change: (inout DisplayInfo) -> Void) {
    tween?.cancel()
    activePreset = nil
    defaults.removeObject(forKey: "preset")
    for index in displays.indices where linked || displays[index].id == id {
      change(&displays[index])
      persist(displays[index])
      apply(displays[index])
    }
  }

  func applyPreset(_ preset: Preset) {
    activePreset = preset.id
    defaults.set(preset.id, forKey: "preset")
    animate(to: displays.map { ($0.id, preset.brightness, preset.warmth) })
  }

  func reset() {
    activePreset = nil
    defaults.removeObject(forKey: "preset")
    animate(to: displays.map { ($0.id, 1, 0) })
  }

  func setEnabled(_ value: Bool) {
    enabled = value
    defaults.set(value, forKey: "enabled")
    applyAll()
  }

  func setLinked(_ value: Bool) {
    linked = value
    defaults.set(value, forKey: "linked")
  }

  func setLaunchAtLogin(_ value: Bool) {
    do {
      if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      NSLog("Lightmoon: iniciar no login falhou: \(error.localizedDescription)")
    }
    launchAtLogin = SMAppService.mainApp.status == .enabled
  }

  // MARK: Aplicação

  private func animate(to targets: [(CGDirectDisplayID, Double, Double)]) {
    tween?.cancel()
    let start = displays
    tween = Task { [weak self] in
      let steps = 30
      for step in 1...steps {
        guard let self, !Task.isCancelled else { return }
        let t = Double(step) / Double(steps)
        let eased = t * t * (3 - 2 * t)
        for (id, brightness, warmth) in targets {
          guard let index = self.displays.firstIndex(where: { $0.id == id }),
                let from = start.first(where: { $0.id == id }) else { continue }
          self.displays[index].brightness = from.brightness + (brightness - from.brightness) * eased
          self.displays[index].warmth = from.warmth + (warmth - from.warmth) * eased
          self.apply(self.displays[index])
        }
        try? await Task.sleep(for: .milliseconds(12))
      }
      guard let self, !Task.isCancelled else { return }
      self.displays.forEach(self.persist)
    }
  }

  private func persist(_ display: DisplayInfo) {
    defaults.set(display.brightness, forKey: "brightness.\(display.key)")
    defaults.set(display.warmth, forKey: "warmth.\(display.key)")
  }

  private func applyAll() {
    displays.forEach(apply)
  }

  private func apply(_ display: DisplayInfo) {
    guard live, let table = base[display.id] else { return }
    if enabled {
      Gamma.apply(display.id, base: table, brightness: display.brightness, warmth: display.warmth)
    } else {
      Gamma.apply(display.id, base: table, brightness: 1, warmth: 0)
    }
  }
}
