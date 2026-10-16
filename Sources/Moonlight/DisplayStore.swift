import AppKit
import Combine
import ServiceManagement

struct DisplayInfo: Identifiable, Equatable {
  let id: CGDirectDisplayID
  let name: String
  let key: String
  let isBuiltin: Bool
  let detail: String
  let aspect: CGFloat
  var brightness: Double
  var warmth: Double
  var contrast: Double

  var minBrightness: Double { isBuiltin ? 0 : 0.1 }
}

struct Preset: Identifiable, Equatable {
  let id: String
  let title: String
  let symbol: String
  let brightness: Double
  let warmth: Double

  static let day = Preset(id: "dia", title: "Dia", symbol: "sun.max.fill", brightness: 1.0, warmth: 0.0)
  static let night = Preset(id: "noite", title: "Noite", symbol: "moon.fill", brightness: 0.5, warmth: 0.6)
  static let all: [Preset] = [
    day,
    Preset(id: "foco", title: "Foco", symbol: "scope", brightness: 0.8, warmth: 0.15),
    night,
    Preset(id: "cinema", title: "Cinema", symbol: "film.fill", brightness: 0.35, warmth: 0.3),
  ]
  /// Não tem valores fixos: cada tela guarda os seus em `DisplayStore.custom`.
  static let custom = Preset(id: "custom", title: "Custom", symbol: "slider.horizontal.3", brightness: 1, warmth: 0)
}

@MainActor
final class DisplayStore: ObservableObject {
  static let restInterval: TimeInterval = 20 * 60
  static let restSeconds = 20

  @Published var displays: [DisplayInfo] = []
  /// `nil` significa todas as telas.
  @Published var selection: CGDirectDisplayID?
  @Published var enabled: Bool
  @Published var activePreset: String?
  @Published var launchAtLogin = false

  @Published var nightAuto: Bool
  @Published var nightStart: Int
  @Published var nightEnd: Int
  @Published var eyeRest: Bool
  @Published var hotKeys: Bool

  private let live: Bool
  private let defaults = UserDefaults.standard

  /// O app se chamava Lightmoon: na primeira abertura como Moonlight, traz os ajustes salvos com o nome antigo.
  private static func migrateFromLightmoon() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: "migratedFromLightmoon") else { return }
    if let old = UserDefaults(suiteName: "br.com.jhosefer.lightmoon")?.persistentDomain(forName: "br.com.jhosefer.lightmoon") {
      for (key, value) in old where defaults.object(forKey: key) == nil { defaults.set(value, forKey: key) }
    }
    defaults.set(true, forKey: "migratedFromLightmoon")
  }
  private var base: [CGDirectDisplayID: GammaTable] = [:]
  private var tween: Task<Void, Never>?
  private var restLoop: Task<Void, Never>?
  private var restFactor = 1.0
  private var lastNightState: Bool?
  private var scheduleTimer: Timer?
  private var observers: [NSObjectProtocol] = []

  init(live: Bool = true) {
    self.live = live
    Self.migrateFromLightmoon()
    enabled = defaults.object(forKey: "enabled") as? Bool ?? true
    activePreset = defaults.string(forKey: "preset")
    nightAuto = defaults.bool(forKey: "nightAuto")
    nightStart = defaults.object(forKey: "nightStart") as? Int ?? 19
    nightEnd = defaults.object(forKey: "nightEnd") as? Int ?? 7
    eyeRest = defaults.bool(forKey: "eyeRest")
    hotKeys = defaults.object(forKey: "hotKeys") as? Bool ?? true
    if live {
      // Parte de um estado limpo: sem isso, a tabela capturada pode já vir escurecida por outro app.
      Gamma.restoreAll()
      launchAtLogin = SMAppService.mainApp.status == .enabled
      observe()
    }
    refresh()
    if live {
      HotKeys.shared.handler = { [weak self] action in
        Task { @MainActor in self?.handle(action) }
      }
      HotKeys.shared.setEnabled(hotKeys)
      scheduleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.tickSchedule() }
      }
      tickSchedule()
      restartRestLoop()
    }
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
      let builtin = CGDisplayIsBuiltin(id) != 0
      let key = "\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
      let width = CGDisplayPixelsWide(id)
      let height = CGDisplayPixelsHigh(id)
      if live, base[id] == nil {
        base[id] = Gamma.capture(id)
      }
      let saved = defaults.object(forKey: "brightness.\(key)") as? Double ?? 1
      found.append(DisplayInfo(
        id: id,
        name: builtin ? "Tela do Mac" : screen.localizedName,
        key: key,
        isBuiltin: builtin,
        detail: DisplayModes.current(id)?.title ?? "\(width) × \(height)",
        aspect: height > 0 ? CGFloat(width) / CGFloat(height) : 16 / 9,
        // A tela embutida tem brilho próprio, que as teclas do Mac também mudam: vale o que o sistema reporta.
        brightness: builtin && live ? (BuiltinBrightness.get(id) ?? saved) : saved,
        warmth: defaults.object(forKey: "warmth.\(key)") as? Double ?? 0,
        contrast: defaults.object(forKey: "contrast.\(key)") as? Double ?? 0.5
      ))
    }
    // Externas primeiro: são o motivo de o app existir.
    displays = found.sorted { !$0.isBuiltin && $1.isBuiltin }
    if let selection, !displays.contains(where: { $0.id == selection }) {
      self.selection = nil
    }
    if displays.count == 1 {
      selection = displays[0].id
    }
    displays.forEach { apply($0) }
  }

  // MARK: Escopo

  /// Tela cujos valores o painel mostra: a selecionada ou, em "Todas", a primeira.
  var focus: DisplayInfo? {
    displays.first { $0.id == selection } ?? displays.first
  }

  private var scopedIDs: [CGDirectDisplayID] {
    displays.filter { selection == nil || $0.id == selection }.map(\.id)
  }

  // MARK: Ajustes

  func set(_ keyPath: WritableKeyPath<DisplayInfo, Double>, to value: Double, only id: CGDirectDisplayID? = nil) {
    tween?.cancel()
    // Com o Custom ativo, mexer nos ajustes é o jeito de editá-lo; nos outros presets, sai deles.
    let editingCustom = activePreset == Preset.custom.id
    if !editingCustom { clearPreset() }
    let targets = id.map { [$0] } ?? scopedIDs
    for index in displays.indices where targets.contains(displays[index].id) {
      let floor = keyPath == \.brightness ? displays[index].minBrightness : 0
      displays[index][keyPath: keyPath] = min(1, max(floor, value))
      persist(displays[index])
      if editingCustom { remember(displays[index]) }
      apply(displays[index], hardware: keyPath == \.brightness)
    }
  }

  // MARK: Custom

  /// Ajuste salvo de cada tela, pela chave do monitor: [brilho, temperatura, contraste].
  private var custom: [String: [Double]] {
    get { defaults.dictionary(forKey: "custom") as? [String: [Double]] ?? [:] }
    set { defaults.set(newValue, forKey: "custom") }
  }

  var hasCustom: Bool { !custom.isEmpty }

  /// Aplica o ajuste salvo de cada tela, independente da seleção. Na primeira vez, salva o que está na tela.
  /// Uma tela que ainda não tem ajuste salvo entra com os valores atuais.
  func applyCustom() {
    if custom.isEmpty { saveCustom() }
    activePreset = Preset.custom.id
    defaults.set(Preset.custom.id, forKey: "preset")
    let saved = custom
    animate(to: displays.map { display in
      guard let values = saved[display.key], values.count == 3 else {
        remember(display)
        return (display.id, display.brightness, display.warmth, display.contrast)
      }
      return (display.id, max(display.minBrightness, values[0]), values[1], values[2])
    })
  }

  /// Guarda os ajustes atuais de todas as telas como o Custom.
  func saveCustom() {
    displays.forEach(remember)
    activePreset = Preset.custom.id
    defaults.set(Preset.custom.id, forKey: "preset")
  }

  func clearCustom() {
    custom = [:]
    if activePreset == Preset.custom.id { clearPreset() }
  }

  private func remember(_ display: DisplayInfo) {
    custom[display.key] = [display.brightness, display.warmth, display.contrast]
  }

  func applyPreset(_ preset: Preset, toAll: Bool = false) {
    activePreset = preset.id
    defaults.set(preset.id, forKey: "preset")
    let ids = toAll ? displays.map(\.id) : scopedIDs
    animate(to: displays.filter { ids.contains($0.id) }.map { ($0.id, preset.brightness, preset.warmth, $0.contrast) })
  }

  func reset() {
    clearPreset()
    // O brilho da tela embutida é de hardware e não tem "original" para voltar.
    animate(to: displays.filter { scopedIDs.contains($0.id) }.map { ($0.id, $0.isBuiltin ? $0.brightness : 1, 0, 0.5) })
  }

  func setEnabled(_ value: Bool) {
    enabled = value
    defaults.set(value, forKey: "enabled")
    displays.forEach { apply($0) }
  }

  func setLaunchAtLogin(_ value: Bool) {
    do {
      if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      NSLog("Moonlight: iniciar no login falhou: \(error.localizedDescription)")
    }
    launchAtLogin = SMAppService.mainApp.status == .enabled
  }

  private func clearPreset() {
    activePreset = nil
    defaults.removeObject(forKey: "preset")
  }

  // MARK: Resolução

  func modes(for id: CGDirectDisplayID) -> [DisplayMode] {
    live ? DisplayModes.list(id) : []
  }

  func setMode(_ mode: DisplayMode, for id: CGDirectDisplayID) {
    guard live else { return }
    DisplayModes.set(mode, on: id)
  }

  func sleepDisplays() {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["displaysleepnow"]
    try? process.run()
  }

  // MARK: Automação

  func setNightAuto(_ value: Bool) {
    nightAuto = value
    defaults.set(value, forKey: "nightAuto")
    lastNightState = nil
    tickSchedule()
  }

  func setNightHours(start: Int, end: Int) {
    nightStart = start
    nightEnd = end
    defaults.set(start, forKey: "nightStart")
    defaults.set(end, forKey: "nightEnd")
    lastNightState = nil
    tickSchedule()
  }

  /// Só age na virada do horário, para não desfazer um ajuste manual a cada verificação.
  private func tickSchedule() {
    guard live, nightAuto, enabled else { return }
    let hour = Calendar.current.component(.hour, from: Date())
    let isNight = nightStart < nightEnd ? (hour >= nightStart && hour < nightEnd) : (hour >= nightStart || hour < nightEnd)
    guard isNight != lastNightState else { return }
    lastNightState = isNight
    applyPreset(isNight ? .night : .day, toAll: true)
  }

  func setEyeRest(_ value: Bool) {
    eyeRest = value
    defaults.set(value, forKey: "eyeRest")
    restartRestLoop()
  }

  private func restartRestLoop() {
    restLoop?.cancel()
    guard live, eyeRest else { return }
    restLoop = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(Self.restInterval))
        guard !Task.isCancelled else { return }
        await self?.rest()
      }
    }
  }

  /// Escurece todas as telas por alguns segundos e mostra o aviso; não altera os valores salvos.
  func rest() async {
    guard live, restFactor == 1 else { return }
    RestHUD.shared.show(seconds: Self.restSeconds)
    await fadeRest(to: 0.45)
    try? await Task.sleep(for: .seconds(Self.restSeconds))
    await fadeRest(to: 1)
    RestHUD.shared.hide()
  }

  private func fadeRest(to target: Double) async {
    let start = restFactor
    let steps = 40
    for step in 1...steps {
      restFactor = start + (target - start) * Double(step) / Double(steps)
      displays.forEach { apply($0) }
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  func setHotKeys(_ value: Bool) {
    hotKeys = value
    defaults.set(value, forKey: "hotKeys")
    HotKeys.shared.setEnabled(value)
  }

  /// Os atalhos agem na tela onde o cursor está, independente da seleção do painel.
  private func handle(_ action: HotKeys.Action) {
    let mouse = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }),
          let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          let display = displays.first(where: { $0.id == number.uint32Value }) else { return }
    switch action {
    case .brightnessUp: set(\.brightness, to: display.brightness + 0.1, only: display.id)
    case .brightnessDown: set(\.brightness, to: display.brightness - 0.1, only: display.id)
    case .warmthUp: set(\.warmth, to: display.warmth + 0.1, only: display.id)
    case .warmthDown: set(\.warmth, to: display.warmth - 0.1, only: display.id)
    }
  }

  // MARK: Aplicação

  private func animate(to targets: [(CGDirectDisplayID, Double, Double, Double)]) {
    tween?.cancel()
    let start = displays
    tween = Task { [weak self] in
      let steps = 30
      for step in 1...steps {
        guard let self, !Task.isCancelled else { return }
        let t = Double(step) / Double(steps)
        let eased = t * t * (3 - 2 * t)
        for (id, brightness, warmth, contrast) in targets {
          guard let index = self.displays.firstIndex(where: { $0.id == id }),
                let from = start.first(where: { $0.id == id }) else { continue }
          self.displays[index].brightness = from.brightness + (brightness - from.brightness) * eased
          self.displays[index].warmth = from.warmth + (warmth - from.warmth) * eased
          self.displays[index].contrast = from.contrast + (contrast - from.contrast) * eased
          self.apply(self.displays[index], hardware: true)
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
    defaults.set(display.contrast, forKey: "contrast.\(display.key)")
  }

  /// `hardware` só é verdadeiro quando o brilho mudou: evita brigar com as teclas de brilho do Mac.
  private func apply(_ display: DisplayInfo, hardware: Bool = false) {
    guard live else { return }
    if display.isBuiltin, hardware {
      BuiltinBrightness.set(display.id, display.brightness)
    }
    guard let table = base[display.id] else { return }
    if enabled {
      let dim = display.isBuiltin ? 1 : display.brightness
      Gamma.apply(display.id, base: table, brightness: dim * restFactor, warmth: display.warmth, contrast: display.contrast)
    } else {
      Gamma.apply(display.id, base: table, brightness: 1, warmth: 0, contrast: 0.5)
    }
  }
}
