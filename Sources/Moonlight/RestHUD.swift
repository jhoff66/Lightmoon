import AppKit
import SwiftUI

/// Aviso flutuante da pausa para os olhos; não rouba o foco nem recebe cliques.
@MainActor
final class RestHUD {
  static let shared = RestHUD()
  private var panel: NSPanel?

  func show(seconds: Int) {
    hide()
    let size = NSSize(width: 380, height: 92)
    let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .statusBar
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.contentView = NSHostingView(rootView: RestHUDView(seconds: seconds))
    if let frame = NSScreen.main?.visibleFrame {
      panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 60))
    }
    panel.alphaValue = 0
    panel.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { $0.duration = 0.4; panel.animator().alphaValue = 1 }
    self.panel = panel
  }

  func hide() {
    guard let panel else { return }
    self.panel = nil
    NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; panel.animator().alphaValue = 0 },
                                         completionHandler: { panel.orderOut(nil) })
  }
}

struct RestHUDView: View {
  let seconds: Int
  @State private var progress = 0.0

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "eye.fill")
        .font(.system(size: 22, weight: .medium))
        .foregroundStyle(Color.moon)
        .frame(width: 46, height: 46)
        .background(Circle().fill(Color.white.opacity(0.1)))
      VStack(alignment: .leading, spacing: 6) {
        Text("Descanse os olhos").font(.system(size: 14, weight: .semibold))
        Text("Olhe para algo distante por \(seconds) segundos.")
          .font(.system(size: 11.5)).foregroundStyle(.secondary)
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule().fill(Color.moon).frame(width: geo.size.width * progress)
          }
        }
        .frame(height: 3)
      }
    }
    .padding(.horizontal, 18)
    .frame(width: 380, height: 92)
    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial))
    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    .environment(\.colorScheme, .dark)
    .onAppear { withAnimation(.linear(duration: Double(seconds))) { progress = 1 } }
  }
}
