import SwiftUI

struct PanelView: View {
  @ObservedObject var store: DisplayStore
  @State var page = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      PageTabs(titles: ["Telas", "Automação"], selection: $page)
      if page == 0 {
        if store.displays.isEmpty { emptyState } else { displaysPage }
      } else {
        automationPage
      }
      footer
    }
    .padding(14)
    .frame(width: 336)
    .animation(.easeOut(duration: 0.2), value: store.enabled)
    .onAppear { store.refresh() }
  }

  // MARK: Cabeçalho e rodapé

  private var header: some View {
    HStack(spacing: 9) {
      Image(systemName: store.enabled ? "moon.fill" : "moon")
        .font(.system(size: 19, weight: .medium))
        .foregroundStyle(store.enabled ? AnyShapeStyle(Color.moon) : AnyShapeStyle(.secondary))
      VStack(alignment: .leading, spacing: 1) {
        Text("Lightmoon").font(.system(size: 14.5, weight: .semibold))
        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
      }
      Spacer()
      Switch(isOn: store.enabled, action: store.setEnabled)
        .help("Liga ou pausa os ajustes sem perder os valores")
    }
  }

  private var subtitle: String {
    guard store.enabled else { return "Pausado" }
    return store.displays.count == 1 ? "1 tela" : "\(store.displays.count) telas"
  }

  private var footer: some View {
    HStack(spacing: 7) {
      FooterChip(symbol: "arrow.counterclockwise", title: "Restaurar", action: store.reset)
      FooterChip(symbol: "moon.zzz.fill", title: "Apagar telas", action: store.sleepDisplays)
      Spacer()
      Menu {
        Button("Fazer pausa para os olhos agora") { Task { await store.rest() } }
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

  private var emptyState: some View {
    VStack(spacing: 6) {
      Image(systemName: "display.trianglebadge.exclamationmark").font(.system(size: 24)).foregroundStyle(.secondary)
      Text("Nenhuma tela encontrada.").font(.system(size: 12)).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 22)
  }

  // MARK: Telas

  private var displaysPage: some View {
    VStack(alignment: .leading, spacing: 12) {
      if store.displays.count > 1 { picker }
      if let display = store.focus { controls(display) }
      HStack(spacing: 7) {
        ForEach(Preset.all) { preset in
          PresetButton(preset: preset, active: store.activePreset == preset.id) { store.applyPreset(preset) }
        }
        PresetButton(preset: .custom, active: store.activePreset == Preset.custom.id, action: store.applyCustom)
          .help(store.activePreset == Preset.custom.id
                ? "Ajuste cada tela como quiser: fica salvo no Custom"
                : "Aplica o ajuste salvo de cada tela. Botão direito para salvar o atual")
          .contextMenu {
            Button("Salvar ajustes atuais no Custom", action: store.saveCustom)
            if store.hasCustom { Button("Apagar o Custom", action: store.clearCustom) }
          }
      }
      if store.activePreset == Preset.custom.id {
        Text("Editando o Custom: escolha cada tela e ajuste, fica salvo.")
          .font(.system(size: 10.5)).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
      }
    }
    .disabled(!store.enabled)
    .opacity(store.enabled ? 1 : 0.45)
  }

  private var picker: some View {
    HStack(spacing: 7) {
      DisplayTile(title: "Todas", selected: store.selection == nil, action: { store.selection = nil }) {
        Image(systemName: "rectangle.on.rectangle").font(.system(size: 17, weight: .light))
          .foregroundStyle(Color.primary.opacity(0.75))
      }
      ForEach(store.displays) { display in
        DisplayTile(title: display.name, selected: store.selection == display.id, action: { store.selection = display.id }) {
          MonitorGlyph(aspect: display.aspect, laptop: display.isBuiltin, brightness: display.brightness, warmth: display.warmth)
        }
      }
    }
  }

  private func controls(_ display: DisplayInfo) -> some View {
    let all = store.selection == nil
    return VStack(alignment: .leading, spacing: 11) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(all ? "Todas as telas" : display.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
          if all {
            Text("Os ajustes valem para as \(store.displays.count)").font(.system(size: 10.5)).foregroundStyle(.secondary)
          } else {
            modeMenu(display)
          }
        }
        Spacer()
        HStack(alignment: .firstTextBaseline, spacing: 1) {
          Text("\(Int((display.brightness * 100).rounded()))")
            .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
            .contentTransition(.numericText())
          Text("%").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
        }
      }
      SliderRow(title: "Brilho", valueText: "\(Int((display.brightness * 100).rounded()))%",
                symbol: "sun.max.fill", value: display.brightness, range: display.minBrightness...1,
                fill: AnyShapeStyle(Color.white)) { store.set(\.brightness, to: $0) }
      SliderRow(title: "Temperatura", valueText: display.warmth < 0.01 ? "Neutra" : "+\(Int((display.warmth * 100).rounded()))",
                symbol: "thermometer.medium", value: display.warmth, range: 0...1,
                fill: AnyShapeStyle(LinearGradient(colors: [.white, .warm], startPoint: .leading, endPoint: .trailing))) {
        store.set(\.warmth, to: $0)
      }
      SliderRow(title: "Contraste", valueText: contrastText(display.contrast),
                symbol: "circle.lefthalf.filled", value: display.contrast, range: 0...1,
                fill: AnyShapeStyle(LinearGradient(colors: [Color(white: 0.62), .white], startPoint: .leading, endPoint: .trailing))) {
        // Encaixa no neutro quando passa perto, para dar para voltar ao original sem mira.
        store.set(\.contrast, to: abs($0 - 0.5) < 0.03 ? 0.5 : $0)
      }
    }
    .padding(13)
    .card()
  }

  private func contrastText(_ value: Double) -> String {
    let delta = Int(((value - 0.5) * 100).rounded())
    return delta == 0 ? "Neutro" : (delta > 0 ? "+\(delta)" : "\(delta)")
  }

  private func modeMenu(_ display: DisplayInfo) -> some View {
    Menu {
      ForEach(store.modes(for: display.id)) { mode in
        Button {
          store.setMode(mode, for: display.id)
        } label: {
          if mode.title == display.detail { Label(mode.title, systemImage: "checkmark") } else { Text(mode.title) }
        }
      }
    } label: {
      HStack(spacing: 3) {
        Text(display.detail)
        Image(systemName: "chevron.up.chevron.down").font(.system(size: 7.5, weight: .bold))
      }
      .font(.system(size: 10.5))
      .foregroundStyle(.secondary)
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("Trocar resolução e taxa de atualização")
  }

  // MARK: Automação

  private var automationPage: some View {
    VStack(spacing: 13) {
      SettingRow(symbol: "moon.stars.fill", title: "Noite automática",
                 subtitle: "Noite no horário, Dia no resto") {
        Switch(isOn: store.nightAuto, action: store.setNightAuto)
      }
      if store.nightAuto {
        HStack(spacing: 6) {
          Text("Das").foregroundStyle(.secondary)
          hourMenu(store.nightStart) { store.setNightHours(start: $0, end: store.nightEnd) }
          Text("às").foregroundStyle(.secondary)
          hourMenu(store.nightEnd) { store.setNightHours(start: store.nightStart, end: $0) }
          Spacer()
        }
        .font(.system(size: 11.5))
        .padding(.leading, 41)
      }
      Divider().opacity(0.5)
      SettingRow(symbol: "eye.fill", title: "Pausa para os olhos",
                 subtitle: "20 s de descanso a cada 20 min") {
        Switch(isOn: store.eyeRest, action: store.setEyeRest)
      }
      Divider().opacity(0.5)
      SettingRow(symbol: "keyboard.fill", title: "Atalhos de teclado",
                 subtitle: "⌃⌥⇧ + setas, na tela do cursor") {
        Switch(isOn: store.hotKeys, action: store.setHotKeys)
      }
      Divider().opacity(0.5)
      SettingRow(symbol: "power", title: "Iniciar no login",
                 subtitle: "Abre junto com o Mac") {
        Switch(isOn: store.launchAtLogin, action: store.setLaunchAtLogin)
      }
    }
    .padding(13)
    .card()
  }

  private func hourMenu(_ hour: Int, onPick: @escaping (Int) -> Void) -> some View {
    Menu {
      ForEach(0..<24, id: \.self) { value in
        Button("\(value)h") { onPick(value) }
      }
    } label: {
      Text("\(hour)h").font(.system(size: 11.5, weight: .medium, design: .rounded))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.1)))
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
  }
}
