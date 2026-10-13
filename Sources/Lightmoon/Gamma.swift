import CoreGraphics
import Foundation

struct GammaTable {
  var red: [CGGammaValue]
  var green: [CGGammaValue]
  var blue: [CGGammaValue]
}

enum Gamma {
  static func capture(_ id: CGDirectDisplayID) -> GammaTable? {
    var count: UInt32 = 0
    var red = [CGGammaValue](repeating: 0, count: 256)
    var green = [CGGammaValue](repeating: 0, count: 256)
    var blue = [CGGammaValue](repeating: 0, count: 256)
    guard CGGetDisplayTransferByTable(id, 256, &red, &green, &blue, &count) == .success, count > 0 else {
      return nil
    }
    let n = Int(count)
    return GammaTable(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
  }

  /// Canais verde e azul caem conforme a tela esquenta; em 1.0 fica perto de uma lâmpada de 2700 K.
  static func warmthMultipliers(_ warmth: Double) -> (red: Double, green: Double, blue: Double) {
    (1, 1 - 0.28 * warmth, 1 - 0.58 * warmth)
  }

  /// `contrast` vai de 0 a 1 com 0.5 neutro: abaixo achata a curva em torno do cinza médio, acima estica.
  static func apply(_ id: CGDirectDisplayID, base: GammaTable, brightness: Double, warmth: Double, contrast: Double) {
    let m = warmthMultipliers(warmth)
    let slope = CGGammaValue(0.5 + contrast)
    func channel(_ values: [CGGammaValue], _ gain: Double) -> [CGGammaValue] {
      let gain = CGGammaValue(brightness * gain)
      return values.map { min(1, max(0, 0.5 + ($0 - 0.5) * slope)) * gain }
    }
    let red = channel(base.red, m.red)
    let green = channel(base.green, m.green)
    let blue = channel(base.blue, m.blue)
    CGSetDisplayTransferByTable(id, UInt32(red.count), red, green, blue)
  }

  static func restoreAll() {
    CGDisplayRestoreColorSyncSettings()
  }
}

/// Brilho de hardware da tela embutida, pela mesma via privada que as teclas de brilho usam.
enum BuiltinBrightness {
  private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
  private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
  private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

  static func get(_ id: CGDirectDisplayID) -> Double? {
    guard let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
    var value: Float = 0
    return unsafeBitCast(symbol, to: GetFn.self)(id, &value) == 0 ? Double(value) : nil
  }

  static func set(_ id: CGDirectDisplayID, _ value: Double) {
    guard let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return }
    _ = unsafeBitCast(symbol, to: SetFn.self)(id, Float(value))
  }
}

struct DisplayMode: Identifiable, Hashable {
  let id: Int32
  let width: Int
  let height: Int
  let hertz: Int
  let hidpi: Bool

  var title: String {
    var text = "\(width) × \(height)"
    if hertz > 0 { text += " · \(hertz) Hz" }
    if hidpi { text += " · HiDPI" }
    return text
  }
}

enum DisplayModes {
  private static func raw(_ id: CGDirectDisplayID) -> [CGDisplayMode] {
    let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
    let all = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
    return all.filter { $0.isUsableForDesktopGUI() }
  }

  private static func describe(_ mode: CGDisplayMode) -> DisplayMode {
    DisplayMode(id: mode.ioDisplayModeID, width: mode.width, height: mode.height,
                hertz: Int(mode.refreshRate.rounded()), hidpi: mode.pixelWidth > mode.width)
  }

  static func list(_ id: CGDirectDisplayID) -> [DisplayMode] {
    var seen = Set<String>()
    return raw(id).map(describe)
      .filter { seen.insert($0.title).inserted }
      .sorted { ($0.width, $0.height, $0.hertz, $0.hidpi ? 1 : 0) > ($1.width, $1.height, $1.hertz, $1.hidpi ? 1 : 0) }
  }

  static func current(_ id: CGDirectDisplayID) -> DisplayMode? {
    CGDisplayCopyDisplayMode(id).map(describe)
  }

  static func set(_ mode: DisplayMode, on id: CGDirectDisplayID) {
    guard let target = raw(id).first(where: { describe($0).title == mode.title }) else { return }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else { return }
    CGConfigureDisplayWithDisplayMode(config, id, target, nil)
    CGCompleteDisplayConfiguration(config, .permanently)
  }
}
