// Desenha o ícone do app (um olho sereno com a lua crescente na pupila, no céu de noite) e grava um PNG de 1024 px.
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

func disc(_ c: CGPoint, _ r: CGFloat) -> CGRect {
  CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
}

// Base no formato dos ícones do macOS: 824 px centrados, cantos contínuos.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil))
ctx.clip()
// Céu de noite, do roxo da marca ao azul fundo.
ctx.drawLinearGradient(gradient([color(0.47, 0.38, 0.95), color(0.22, 0.17, 0.55), color(0.07, 0.06, 0.20)], [0, 0.5, 1]),
                       start: CGPoint(x: 724, y: 924), end: CGPoint(x: 300, y: 100),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Luz morna e difusa atrás do olho.
let eyeCenter = CGPoint(x: 512, y: 500)
ctx.drawRadialGradient(gradient([color(1, 0.88, 0.62, 0.34), color(1, 0.88, 0.62, 0)], [0, 1]),
                       startCenter: eyeCenter, startRadius: 0, endCenter: eyeCenter, endRadius: 420, options: [])

// Olho amendoado, de cantos macios: pálpebra de cima e de baixo em curvas suaves.
let left = CGPoint(x: 200, y: eyeCenter.y), right = CGPoint(x: 824, y: eyeCenter.y)
let eye = CGMutablePath()
eye.move(to: left)
eye.addCurve(to: right, control1: CGPoint(x: 340, y: 700), control2: CGPoint(x: 684, y: 700))
eye.addCurve(to: left, control1: CGPoint(x: 684, y: 316), control2: CGPoint(x: 340, y: 316))
eye.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 40, color: color(0.03, 0.02, 0.12, 0.55))
ctx.addPath(eye)
ctx.setFillColor(color(1, 0.94, 0.80))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(eye)
ctx.clip()
ctx.drawLinearGradient(gradient([color(1, 0.98, 0.91), color(1, 0.87, 0.64)], [0, 1]),
                       start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 300), options: [])

// Íris no tom do céu, com a borda escurecendo.
let irisRadius: CGFloat = 150
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: color(0.30, 0.18, 0.05, 0.35))
ctx.setFillColor(color(0.26, 0.20, 0.62))
ctx.fillEllipse(in: disc(eyeCenter, irisRadius))
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: disc(eyeCenter, irisRadius))
ctx.clip()
ctx.drawRadialGradient(gradient([color(0.55, 0.45, 1.0), color(0.30, 0.22, 0.72), color(0.12, 0.09, 0.34)], [0, 0.6, 1]),
                       startCenter: CGPoint(x: 490, y: 530), startRadius: 0,
                       endCenter: eyeCenter, endRadius: irisRadius, options: [.drawsAfterEndLocation])
ctx.restoreGState()

// Pupila: o céu de noite, com a lua crescente refletida.
let pupilRadius: CGFloat = 76
ctx.setFillColor(color(0.06, 0.05, 0.18))
ctx.fillEllipse(in: disc(eyeCenter, pupilRadius))
let moon = CGPath(ellipseIn: disc(CGPoint(x: 500, y: 498), 50), transform: nil)
  .subtracting(CGPath(ellipseIn: disc(CGPoint(x: 526, y: 520), 42), transform: nil))
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 16, color: color(1, 0.90, 0.65, 0.8))
ctx.addPath(moon)
ctx.setFillColor(color(1, 0.93, 0.76))
ctx.fillPath()
ctx.restoreGState()

// Reflexo de luz no canto da íris.
ctx.setFillColor(color(1, 1, 1, 0.85))
ctx.fillEllipse(in: disc(CGPoint(x: 572, y: 566), 22))
ctx.restoreGState()

// Contorno fino da pálpebra de cima, para o olho ter desenho sem pesar.
ctx.addPath(eye)
ctx.setStrokeColor(color(0.95, 0.78, 0.50, 0.9))
ctx.setLineWidth(6)
ctx.strokePath()

// Dobra da pálpebra: um arco suave por cima, que abraça o olho.
let crease = CGMutablePath()
crease.move(to: CGPoint(x: 250, y: 566))
crease.addCurve(to: CGPoint(x: 774, y: 566), control1: CGPoint(x: 360, y: 744), control2: CGPoint(x: 664, y: 744))
ctx.addPath(crease)
ctx.setStrokeColor(color(1, 0.93, 0.78, 0.55))
ctx.setLineWidth(11)
ctx.setLineCap(.round)
ctx.strokePath()

// A coisinha da marca: um brilho de quatro pontas no céu, e um menor ao lado.
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
ctx.setShadow(offset: .zero, blur: 26, color: color(1, 0.95, 0.80, 0.8))
sparkle(at: CGPoint(x: 744, y: 776), radius: 64, alpha: 0.98)
ctx.restoreGState()
sparkle(at: CGPoint(x: 834, y: 690), radius: 26, alpha: 0.8)
// Estrelinhas soltas no céu.
for (x, y, r) in [(300.0, 800.0, 7.0), (230.0, 250.0, 5.0), (790.0, 230.0, 6.0), (560.0, 840.0, 4.0)] {
  ctx.setFillColor(color(1, 1, 1, 0.55))
  ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
