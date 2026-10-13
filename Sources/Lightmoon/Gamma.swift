import CoreGraphics

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

  static func apply(_ id: CGDirectDisplayID, base: GammaTable, brightness: Double, warmth: Double) {
    let m = warmthMultipliers(warmth)
    let red = base.red.map { $0 * CGGammaValue(brightness * m.red) }
    let green = base.green.map { $0 * CGGammaValue(brightness * m.green) }
    let blue = base.blue.map { $0 * CGGammaValue(brightness * m.blue) }
    CGSetDisplayTransferByTable(id, UInt32(red.count), red, green, blue)
  }

  static func restoreAll() {
    CGDisplayRestoreColorSyncSettings()
  }
}
