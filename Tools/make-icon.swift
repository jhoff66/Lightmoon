// Desenha o ícone do app (lua crescente com um brilho no céu de noite) e grava um PNG de 1024 px.
// Uso: swiftc Tools/make-icon.swift -o build/make-icon && build/make-icon saida.png
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
  CGColor(colorSpace: space, components: [r, g, b, a])!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
  CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

// Base no formato dos ícones do macOS: 824 px centrados, cantos contínuos.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil))
ctx.clip()
// Céu de noite, do roxo da marca ao azul fundo.
ctx.drawLinearGradient(gradient([color(0.47, 0.38, 0.95), color(0.22, 0.17, 0.55), color(0.07, 0.06, 0.20)], [0, 0.5, 1]),
                       start: CGPoint(x: 724, y: 924), end: CGPoint(x: 300, y: 100),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Lua crescente: um disco menos outro deslocado para cima e à direita.
let moonCenter = CGPoint(x: 470, y: 480), moonRadius: CGFloat = 270
let moon = CGPath(ellipseIn: CGRect(x: moonCenter.x - moonRadius, y: moonCenter.y - moonRadius, width: moonRadius * 2, height: moonRadius * 2), transform: nil)
  .subtracting(CGPath(ellipseIn: CGRect(x: 600 - 235, y: 590 - 235, width: 470, height: 470), transform: nil))

// Halo de luz atrás da lua.
ctx.drawRadialGradient(gradient([color(1, 0.88, 0.62, 0.40), color(1, 0.88, 0.62, 0)], [0, 1]),
                       startCenter: CGPoint(x: 420, y: 430), startRadius: 0,
                       endCenter: CGPoint(x: 420, y: 430), endRadius: 430, options: [])

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 40, color: color(0.03, 0.02, 0.12, 0.55))
ctx.addPath(moon)
ctx.setFillColor(color(1, 0.93, 0.76))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(moon)
ctx.clip()
ctx.drawLinearGradient(gradient([color(1, 0.97, 0.88), color(1, 0.86, 0.60)], [0, 1]),
                       start: CGPoint(x: 300, y: 700), end: CGPoint(x: 560, y: 220), options: [])
// Duas crateras discretas para a lua não ficar chapada.
ctx.setFillColor(color(0.93, 0.74, 0.45, 0.35))
ctx.fillEllipse(in: CGRect(x: 268, y: 400, width: 70, height: 70))
ctx.fillEllipse(in: CGRect(x: 370, y: 268, width: 44, height: 44))
ctx.restoreGState()

// A coisinha: um brilho de quatro pontas no colo da lua, e um menor ao lado.
func sparkle(at p: CGPoint, radius r: CGFloat, alpha: CGFloat) {
  let path = CGMutablePath()
  let inner = r * 0.2
  for step in 0..<8 {
    let angle = CGFloat(step) * .pi / 4 + .pi / 2
    let length = step % 2 == 0 ? r : inner
    let point = CGPoint(x: p.x + cos(angle) * length, y: p.y + sin(angle) * length)
    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
  }
  path.closeSubpath()
  ctx.addPath(path)
  ctx.setFillColor(color(1, 1, 1, alpha))
  ctx.fillPath()
}
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 30, color: color(1, 0.95, 0.80, 0.8))
sparkle(at: CGPoint(x: 676, y: 664), radius: 84, alpha: 0.98)
ctx.restoreGState()
sparkle(at: CGPoint(x: 790, y: 540), radius: 34, alpha: 0.8)
// Estrelinhas soltas no céu.
for (x, y, r) in [(300.0, 790.0, 7.0), (800.0, 800.0, 5.0), (760.0, 300.0, 6.0), (210.0, 230.0, 4.0)] {
  ctx.setFillColor(color(1, 1, 1, 0.55))
  ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
