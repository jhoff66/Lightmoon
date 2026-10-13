// Desenha o ícone do app (um olho saudável: branco limpo, íris viva e brilho) e grava um PNG de 1024 px.
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

let center = CGPoint(x: 512, y: 512)

// Base no formato dos ícones do macOS: 824 px centrados, cantos contínuos.
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.addPath(CGPath(roundedRect: plate, cornerWidth: 186, cornerHeight: 186, transform: nil))
ctx.clip()
ctx.drawLinearGradient(gradient([color(0.36, 0.90, 0.74), color(0.07, 0.66, 0.60), color(0.03, 0.42, 0.47)], [0, 0.55, 1]),
                       start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.drawRadialGradient(gradient([color(1, 1, 1, 0.30), color(1, 1, 1, 0)], [0, 1]),
                       startCenter: CGPoint(x: 512, y: 600), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 600), endRadius: 460, options: [])

// Branco do olho: amêndoa com sombra suave embaixo.
let left = CGPoint(x: 196, y: 512), right = CGPoint(x: 828, y: 512)
let eye = CGMutablePath()
eye.move(to: left)
eye.addQuadCurve(to: right, control: CGPoint(x: 512, y: 512 + 400))
eye.addQuadCurve(to: left, control: CGPoint(x: 512, y: 512 - 400))
eye.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 44, color: color(0.0, 0.22, 0.25, 0.45))
ctx.addPath(eye)
ctx.setFillColor(color(1, 1, 1))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(eye)
ctx.clip()
// Leve sombreado da pálpebra, para o branco não ficar chapado.
ctx.drawLinearGradient(gradient([color(0.80, 0.90, 0.92, 0.75), color(1, 1, 1, 0)], [0, 1]),
                       start: CGPoint(x: 512, y: 720), end: CGPoint(x: 512, y: 590), options: [])

// Íris viva, com borda mais escura e raios claros a partir da pupila.
let irisRadius: CGFloat = 158
ctx.addEllipse(in: CGRect(x: center.x - irisRadius, y: center.y - irisRadius, width: irisRadius * 2, height: irisRadius * 2))
ctx.clip()
ctx.drawRadialGradient(gradient([color(0.55, 0.98, 0.72), color(0.10, 0.74, 0.62), color(0.02, 0.36, 0.44)], [0, 0.62, 1]),
                       startCenter: center, startRadius: 0, endCenter: center, endRadius: irisRadius, options: [])
ctx.setStrokeColor(color(1, 1, 1, 0.20))
ctx.setLineWidth(5)
ctx.setLineCap(.round)
for step in 0..<28 {
  let angle = CGFloat(step) / 28 * 2 * .pi
  ctx.move(to: CGPoint(x: center.x + cos(angle) * 78, y: center.y + sin(angle) * 78))
  ctx.addLine(to: CGPoint(x: center.x + cos(angle) * 132, y: center.y + sin(angle) * 132))
}
ctx.strokePath()

// Pupila e reflexos de luz: o que faz o olho parecer vivo.
ctx.setFillColor(color(0.02, 0.10, 0.16))
ctx.fillEllipse(in: CGRect(x: center.x - 68, y: center.y - 68, width: 136, height: 136))
ctx.setFillColor(color(1, 1, 1, 0.96))
ctx.fillEllipse(in: CGRect(x: center.x + 18, y: center.y + 30, width: 62, height: 62))
ctx.setFillColor(color(1, 1, 1, 0.75))
ctx.fillEllipse(in: CGRect(x: center.x - 62, y: center.y - 70, width: 26, height: 26))
ctx.restoreGState()

// Brilho de quatro pontas no canto: olho descansado.
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
sparkle(at: CGPoint(x: 762, y: 770), radius: 62, alpha: 0.95)
sparkle(at: CGPoint(x: 846, y: 690), radius: 26, alpha: 0.75)

let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
