import AppKit
import ServiceManagement
import SwiftUI

struct MoonlightApp: App {
  @StateObject private var store = DisplayStore()

  var body: some Scene {
    MenuBarExtra {
      PanelView(store: store)
    } label: {
      Image(nsImage: MenuBarIcon.image(open: store.enabled))
    }
    .menuBarExtraStyle(.window)
  }
}

// `--snapshot <arquivo.png>` renderiza o painel sem tocar na tela, para conferir o layout.
let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--snapshot"), arguments.count > flag + 1 {
  MainActor.assumeIsolated {
    let store = DisplayStore(live: false)
    let view = PanelView(store: store, page: arguments.contains("--automation") ? 1 : 0)
      .background(Color(red: 0.13, green: 0.13, blue: 0.15))
      .environment(\.colorScheme, .dark)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
       let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
      try? png.write(to: URL(fileURLWithPath: arguments[flag + 1]))
    }
  }
} else if let flag = arguments.firstIndex(of: "--login"), arguments.count > flag + 1 {
  // `--login on|off` liga ou desliga o início automático pelo terminal.
  do {
    if arguments[flag + 1] == "on" { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
  } catch {
    print("erro: \(error.localizedDescription)")
  }
  print(SMAppService.mainApp.status == .enabled ? "login: ligado" : "login: desligado")
} else if let flag = arguments.firstIndex(of: "--icon-preview"), arguments.count > flag + 1 {
  // `--icon-preview <arquivo.png>` amplia os dois estados do ícone da barra de menus para conferência.
  let scale: CGFloat = 12
  let canvas = NSImage(size: NSSize(width: 24 * scale * 2 + 60, height: 16 * scale + 40), flipped: false) { rect in
    NSColor.white.setFill()
    rect.fill()
    MenuBarIcon.image(open: true).draw(in: NSRect(x: 20, y: 20, width: 24 * scale, height: 16 * scale))
    MenuBarIcon.image(open: false).draw(in: NSRect(x: 40 + 24 * scale, y: 20, width: 24 * scale, height: 16 * scale))
    return true
  }
  if let tiff = canvas.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: arguments[flag + 1]))
  }
} else if arguments.contains("--diag") {
  // `--diag` lista o que o app enxerga em cada tela, sem alterar nada.
  for id in NSScreen.screens.compactMap({ ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value }) {
    let builtin = CGDisplayIsBuiltin(id) != 0
    print(id, builtin ? "embutida" : "externa",
          "| modo:", DisplayModes.current(id)?.title ?? "?",
          "| modos:", DisplayModes.list(id).count,
          "| brilho hw:", builtin ? (BuiltinBrightness.get(id).map { String(format: "%.2f", $0) } ?? "indisponível") : "n/a")
  }
} else {
  MoonlightApp.main()
}
