import AppKit

/// Ícone da barra de menus, desenhado em vetor e marcado como template para seguir o tema claro ou escuro.
enum MenuBarIcon {
  static func image(open: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
      NSColor.black.set()
      // Lua crescente: um disco menos outro deslocado para cima e à direita.
      let moon = crescent(outer: NSPoint(x: 8.2, y: 7.7), radius: 6.7, cut: NSPoint(x: 11.7, y: 10.1), cutRadius: 5.7)
      if open {
        // Ligado: lua cheia de tinta e o brilho ao lado.
        moon.fill()
        sparkle(at: NSPoint(x: 17.6, y: 11.6), radius: 3.6).fill()
        sparkle(at: NSPoint(x: 19.8, y: 5.4), radius: 1.9).fill()
      } else {
        // Pausado: só o contorno, sem brilho.
        moon.lineWidth = 1.3
        moon.lineJoinStyle = .round
        moon.stroke()
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  /// Contorno da lua: arco externo do disco até onde o recorte o cruza, e volta pelo arco do recorte.
  private static func crescent(outer a: NSPoint, radius r1: CGFloat, cut b: NSPoint, cutRadius r2: CGFloat) -> NSBezierPath {
    let dx = b.x - a.x, dy = b.y - a.y
    let d = hypot(dx, dy)
    let along = (d * d + r1 * r1 - r2 * r2) / (2 * d)
    let half = sqrt(r1 * r1 - along * along)
    let base = NSPoint(x: a.x + dx * along / d, y: a.y + dy * along / d)
    let p1 = NSPoint(x: base.x - dy * half / d, y: base.y + dx * half / d)
    let p2 = NSPoint(x: base.x + dy * half / d, y: base.y - dx * half / d)
    func angle(_ c: NSPoint, _ p: NSPoint) -> CGFloat { atan2(p.y - c.y, p.x - c.x) * 180 / .pi }
    let path = NSBezierPath()
    path.appendArc(withCenter: a, radius: r1, startAngle: angle(a, p1), endAngle: angle(a, p2), clockwise: false)
    path.appendArc(withCenter: b, radius: r2, startAngle: angle(b, p2), endAngle: angle(b, p1), clockwise: true)
    path.close()
    return path
  }

  private static func sparkle(at p: NSPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for step in 0..<8 {
      let angle = CGFloat(step) * .pi / 4 + .pi / 2
      let length = step % 2 == 0 ? radius : radius * 0.24
      let point = NSPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
      if step == 0 { path.move(to: point) } else { path.line(to: point) }
    }
    path.close()
    return path
  }
}
