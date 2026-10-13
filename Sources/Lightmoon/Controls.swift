import SwiftUI

extension Color {
  /// Cor aproximada que a tela assume com os ajustes atuais; usada nas miniaturas e nos trilhos.
  static func screenTint(brightness: Double, warmth: Double) -> Color {
    let m = Gamma.warmthMultipliers(warmth)
    let level = 0.25 + 0.75 * brightness
    return Color(red: m.red * level, green: m.green * level, blue: m.blue * level)
  }

  static let warm = Color(red: 1.0, green: 0.66, blue: 0.30)
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
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.black.opacity(0.62))
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
      .scaleEffect(y: dragging ? 1.06 : 1)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragging)
    }
    .frame(height: 26)
  }
}

/// Miniatura do monitor na proporção real, pintada com o resultado dos ajustes.
struct MonitorGlyph: View {
  let aspect: CGFloat
  let brightness: Double
  let warmth: Double

  var body: some View {
    let height: CGFloat = 22
    let width = min(56, max(30, height * aspect))
    VStack(spacing: 2) {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(Color.screenTint(brightness: brightness, warmth: warmth).gradient)
        .overlay(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5)
        )
        .frame(width: width, height: height)
      Capsule().fill(Color.primary.opacity(0.35)).frame(width: width * 0.36, height: 2.5)
    }
    .frame(width: 58)
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
        Image(systemName: preset.symbol)
          .font(.system(size: 15, weight: .medium))
          .frame(height: 18)
        Text(preset.title)
          .font(.system(size: 10.5, weight: .medium))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 9)
      .foregroundStyle(active ? Color.black.opacity(0.8) : Color.primary.opacity(0.85))
      .background(
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(active ? AnyShapeStyle(Color.screenTint(brightness: 1, warmth: preset.warmth))
                       : AnyShapeStyle(Color.primary.opacity(hovering ? 0.14 : 0.08)))
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering = $0 }
    .animation(.easeOut(duration: 0.15), value: hovering)
    .animation(.easeOut(duration: 0.2), value: active)
  }
}
