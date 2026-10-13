import SwiftUI

struct PanelView: View {
  @ObservedObject var store: DisplayStore

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      if store.displays.isEmpty {
        emptyState
      } else {
        presets
        ForEach(store.displays) { display in
          DisplayCard(display: display, store: store)
        }
        .disabled(!store.enabled)
        .opacity(store.enabled ? 1 : 0.45)
      }
      footer
    }
    .padding(14)
    .frame(width: 330)
    .animation(.easeOut(duration: 0.2), value: store.enabled)
  }

  private var header: some View {
    HStack(spacing: 10) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Lightmoon").font(.system(size: 15, weight: .semibold))
        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Spacer()
      Toggle("", isOn: Binding(get: { store.enabled }, set: store.setEnabled))
        .toggleStyle(.switch)
        .controlSize(.small)
        .labelsHidden()
        .help("Liga ou pausa os ajustes sem perder os valores")
    }
  }

  private var subtitle: String {
    guard store.enabled else { return "Pausado" }
    switch store.displays.count {
    case 0: return "Nenhum monitor externo"
    case 1: return "1 monitor externo"
    default: return "\(store.displays.count) monitores externos"
    }
  }

  private var presets: some View {
    HStack(spacing: 7) {
      ForEach(Preset.all) { preset in
        PresetButton(preset: preset, active: store.activePreset == preset.id) {
          store.applyPreset(preset)
        }
      }
    }
    .disabled(!store.enabled)
    .opacity(store.enabled ? 1 : 0.45)
  }

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "display.trianglebadge.exclamationmark")
        .font(.system(size: 24)).foregroundStyle(.secondary)
      Text("Conecte um monitor externo para ajustar.")
        .font(.system(size: 12)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 22)
  }

  private var footer: some View {
    HStack(spacing: 8) {
      if store.displays.count > 1 {
        FooterChip(symbol: store.linked ? "link" : "link.badge.plus",
                   title: "Ajustar juntos", active: store.linked) {
          store.setLinked(!store.linked)
        }
      }
      FooterChip(symbol: "arrow.counterclockwise", title: "Restaurar", active: false) {
        store.reset()
      }
      Spacer()
      Menu {
        Toggle("Iniciar no login", isOn: Binding(get: { store.launchAtLogin }, set: store.setLaunchAtLogin))
        Divider()
        Button("Sair do Lightmoon") { NSApplication.shared.terminate(nil) }
      } label: {
        Image(systemName: "ellipsis.circle").font(.system(size: 14))
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
    }
  }
}

struct FooterChip: View {
  let symbol: String
  let title: String
  let active: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
        Text(title).font(.system(size: 11, weight: .medium))
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .foregroundStyle(active ? Color.white : Color.primary.opacity(0.8))
      .background(Capsule().fill(active ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color.primary.opacity(0.08))))
    }
    .buttonStyle(.plain)
  }
}

struct DisplayCard: View {
  let display: DisplayInfo
  @ObservedObject var store: DisplayStore

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        MonitorGlyph(aspect: display.aspect, brightness: display.brightness, warmth: display.warmth)
        VStack(alignment: .leading, spacing: 1) {
          Text(display.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
          Text(display.detail).font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
        Spacer()
        Text("\(Int((display.brightness * 100).rounded()))%")
          .font(.system(size: 17, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
      }
      TrackSlider(symbol: "sun.max.fill",
                  value: display.brightness,
                  range: DisplayStore.minBrightness...1,
                  fill: AnyShapeStyle(Color.white)) {
        store.setBrightness($0, for: display.id)
      }
      TrackSlider(symbol: "thermometer.medium",
                  value: display.warmth,
                  range: 0...1,
                  fill: AnyShapeStyle(LinearGradient(colors: [.white, .warm], startPoint: .leading, endPoint: .trailing))) {
        store.setWarmth($0, for: display.id)
      }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
  }
}
