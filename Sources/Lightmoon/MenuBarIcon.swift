import AppKit

/// Ícone da barra de menus, desenhado em vetor e marcado como template para seguir o tema claro ou escuro.
enum MenuBarIcon {
  static func image(open: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 24, height: 16), flipped: false) { _ in
      NSColor.black.set()
      let center = NSPoint(x: 9.5, y: 7.5)
      let left = NSPoint(x: 1.2, y: center.y), right = NSPoint(x: 17.8, y: center.y)

      if open {
        // Olho aberto e descansado: contorno, íris com reflexo e um brilho no canto.
        let outline = NSBezierPath()
        outline.move(to: left)
        outline.curve(to: right, controlPoint1: NSPoint(x: 5.5, y: 13.6), controlPoint2: NSPoint(x: 13.5, y: 13.6))
        outline.curve(to: left, controlPoint1: NSPoint(x: 13.5, y: 1.4), controlPoint2: NSPoint(x: 5.5, y: 1.4))
        outline.close()
        outline.lineWidth = 1.35
        outline.lineJoinStyle = .round
        outline.stroke()

        let iris = NSBezierPath(ovalIn: NSRect(x: center.x - 3.3, y: center.y - 3.3, width: 6.6, height: 6.6))
        iris.append(NSBezierPath(ovalIn: NSRect(x: center.x + 0.3, y: center.y + 0.4, width: 2.1, height: 2.1)))
        iris.windingRule = .evenOdd
        iris.fill()

        sparkle(at: NSPoint(x: 20.6, y: 12.6), radius: 3.1).fill()
      } else {
        // Olho fechado: pausado.
        let lid = NSBezierPath()
        lid.move(to: left)
        lid.curve(to: right, controlPoint1: NSPoint(x: 5.5, y: 2.6), controlPoint2: NSPoint(x: 13.5, y: 2.6))
        lid.lineWidth = 1.35
        lid.lineCapStyle = .round
        lid.stroke()
        let lashes = NSBezierPath()
        for (from, to) in [(NSPoint(x: 5.2, y: 4.3), NSPoint(x: 4.0, y: 2.0)),
                           (NSPoint(x: 9.5, y: 3.4), NSPoint(x: 9.5, y: 0.9)),
                           (NSPoint(x: 13.8, y: 4.3), NSPoint(x: 15.0, y: 2.0))] {
          lashes.move(to: from)
          lashes.line(to: to)
        }
        lashes.lineWidth = 1.35
        lashes.lineCapStyle = .round
        lashes.stroke()
      }
      return true
    }
    image.isTemplate = true
    return image
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
