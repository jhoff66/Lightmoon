import AppKit
import ServiceManagement
import SwiftUI

struct LightmoonApp: App {
  @StateObject private var store = DisplayStore()

  var body: some Scene {
    MenuBarExtra {
      PanelView(store: store)
    } label: {
      Image(systemName: store.enabled ? "moon.stars.fill" : "moon.stars")
    }
    .menuBarExtraStyle(.window)
  }
}

// `--snapshot <arquivo.png>` renderiza o painel sem tocar na tela, para conferir o layout.
let arguments = CommandLine.arguments
if let flag = arguments.firstIndex(of: "--snapshot"), arguments.count > flag + 1 {
  MainActor.assumeIsolated {
    let store = DisplayStore(live: false)
    let view = PanelView(store: store)
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
} else {
  LightmoonApp.main()
}
