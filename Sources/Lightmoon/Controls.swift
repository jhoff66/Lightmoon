import SwiftUI

extension Color {
  /// Cor aproximada que a tela assume com os ajustes atuais; usada nas miniaturas.
  static func screenTint(brightness: Double, warmth: Double) -> Color {
    let m = Gamma.warmthMultipliers(warmth)
    let level = 0.3 + 0.7 * brightness
    return Color(red: m.red * level, green: m.green * level, blue: m.blue * level)
  }

  static let warm = Color(red: 1.0, green: 0.66, blue: 0.30)
  static let moon = Color(red: 1.0, green: 0.91, blue: 0.72)
  static let dusk = Color(red: 0.45, green: 0.42, blue: 0.95)
}

extension ShapeStyle where Self == LinearGradient {
  static var brand: LinearGradient {
    LinearGradient(colors: [Color(red: 0.55, green: 0.48, blue: 1.0), Color(red: 0.36, green: 0.36, blue: 0.86)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}

extension View {
  /// Superfície padrão dos blocos do painel: preenchimento sutil com borda fina.
  func card(radius: CGFloat = 16) -> some View {
    background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.primary.opacity(0.055)))
      .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
  }
}

/// Trilho largo no estilo da Central de Controle: o preenchimento é o próprio valor.
struct TrackSlider: View {
  let symbol: String
  let value: Double
  let range: ClosedRange<Double>
  let fill: AnyShapeStyle
  let onChange: (Double) -> Void

  @State private var dragging = false

  private var fraction: Double {
    (value - range.lowerBound) / (range.upperBound - range.lowerBound)
  }

  var body: some View {
    GeometryReader { geo in
      let height = geo.size.height
      let width = geo.size.width
      let filled = height + (width - height) * fraction
      ZStack(alignment: .leading) {
        Capsule().fill(Color.primary.opacity(0.09))
        // O preenchimento ocupa o trilho inteiro e é recortado, para o degradê não se comprimir no valor.
        Rectangle().fill(fill)
          .mask(alignment: .leading) { Capsule().frame(width: filled) }
          .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        Image(systemName: symbol)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.black.opacity(0.6))
          .frame(width: height, height: height)
      }
      .contentShape(Capsule())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            dragging = true
            let t = (gesture.location.x - height / 2) / max(1, width - height)
            let clamped = min(1, max(0, t))
            onChange(range.lowerBound + clamped * (range.upperBound - range.lowerBound))
          }
          .onEnded { _ in dragging = false }
      )
      .scaleEffect(y: dragging ? 1.08 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
    }
    .frame(height: 24)
  }
}

struct SliderRow: View {
  let title: String
  let valueText: String
  let symbol: String
  let value: Double
  let range: ClosedRange<Double>
  let fill: AnyShapeStyle
  let onChange: (Double) -> Void

  var body: some View {
    VStack(spacing: 5) {
      HStack {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        Spacer()
        Text(valueText).font(.system(size: 11, weight: .medium, design: .rounded)).monospacedDigit()
          .foregroundStyle(.secondary)
      }
      TrackSlider(symbol: symbol, value: value, range: range, fill: fill, onChange: onChange)
    }
  }
}

/// Interruptor próprio, para o painel ter a mesma aparência em qualquer versão do macOS.
struct Switch: View {
  let isOn: Bool
  let action: (Bool) -> Void

  var body: some View {
    Capsule()
      .fill(isOn ? AnyShapeStyle(.brand) : AnyShapeStyle(Color.primary.opacity(0.16)))
      .frame(width: 34, height: 20)
      .overlay(alignment: isOn ? .trailing : .leading) {
        Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.25), radius: 1, y: 1)
      }
      .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
      .contentShape(Capsule())
      .onTapGesture { action(!isOn) }
  }
}

/// Miniatura da tela na proporção real, pintada com o resultado dos ajustes.
struct MonitorGlyph: View {
  let aspect: CGFloat
  let laptop: Bool
  let brightness: Double
  let warmth: Double

  var body: some View {
    let height: CGFloat = 20
    let width = min(50, max(28, height * aspect))
    VStack(spacing: 2) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color.screenTint(brightness: brightness, warmth: warmth).gradient)
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5))
        .frame(width: width, height: height)
      Capsule().fill(Color.primary.opacity(0.4))
        .frame(width: laptop ? width + 8 : width * 0.36, height: 2.5)
    }
  }
}

struct DisplayTile<Glyph: View>: View {
  let title: String
  let selected: Bool
  let action: () -> Void
  @ViewBuilder let glyph: Glyph

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        glyph.frame(height: 26)
        Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1)
          .foregroundStyle(selected ? Color.primary : Color.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 9)
      .padding(.horizontal, 4)
      .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(Color.primary.opacity(selected ? 0.13 : (hovering ? 0.08 : 0.04))))
      .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
        .strokeBorder(selected ? AnyShapeStyle(.brand) : AnyShapeStyle(Color.clear), lineWidth: 1.5))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.15), value: selected)
  }
}

struct PresetButton: View {
  let preset: Preset
  let active: Bool
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      VStack(spacing: 5) {
        Image(systemName: preset.symbol).font(.system(size: 14, weight: .medium)).frame(height: 17)
        Text(preset.title).font(.system(size: 10.5, weight: .medium))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 9)
      .foregroundStyle(active ? Color.white : Color.primary.opacity(0.85))
      .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
        .fill(active ? AnyShapeStyle(.brand) : AnyShapeStyle(Color.primary.opacity(hovering ? 0.12 : 0.06))))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.2), value: active)
  }
}

struct PageTabs: View {
  let titles: [String]
  @Binding var selection: Int

  var body: some View {
    HStack(spacing: 2) {
      ForEach(titles.indices, id: \.self) { index in
        Text(titles[index])
          .font(.system(size: 11.5, weight: .medium))
          .foregroundStyle(selection == index ? Color.primary : Color.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 5)
          .background(Capsule().fill(Color.primary.opacity(selection == index ? 0.14 : 0)))
          .contentShape(Capsule())
          .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { selection = index } }
      }
    }
    .padding(2)
    .background(Capsule().fill(Color.primary.opacity(0.06)))
  }
}

struct SettingRow<Accessory: View>: View {
  let symbol: String
  let title: String
  let subtitle: String
  @ViewBuilder let accessory: Accessory

  var body: some View {
    HStack(spacing: 11) {
      Image(systemName: symbol)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.moon)
        .frame(width: 30, height: 30)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.08)))
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 12.5, weight: .medium))
        Text(subtitle).font(.system(size: 10.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 6)
      accessory
    }
  }
}

struct FooterChip: View {
  let symbol: String
  let title: String
  let action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
        Text(title).font(.system(size: 11, weight: .medium))
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .foregroundStyle(Color.primary.opacity(0.8))
      .background(Capsule().fill(Color.primary.opacity(hovering ? 0.14 : 0.08)))
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
  }
}
