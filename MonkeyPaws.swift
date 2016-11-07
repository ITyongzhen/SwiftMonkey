//
//  MonkeyPaws.swift
//  Fleek
//
//  Created by Dag Agren on 12/04/16.
//  Copyright © 2016 Zalando SE. All rights reserved.
//

//#if DEBUG

import UIKit

private let maxGesturesShown: Int = 15
private let crossRadius: CGFloat = 7
private let circleRadius: CGFloat = 7

public class MonkeyPaws: NSObject, CALayerDelegate {
    private var gestures: [Gesture] = []
    private weak var view: UIView?
    private var counter: Int = 0

    private(set) var layer: CALayer = CALayer()

    fileprivate static var tappingTracks: [WeakReference<MonkeyPaws>] = []

    init(view: UIView) {
        super.init()
        self.view = view

        layer.delegate = self
        layer.isOpaque = false
        layer.frame = view.layer.bounds
        layer.contentsScale = UIScreen.main.scale
        layer.rasterizationScale = UIScreen.main.scale

        view.layer.addSublayer(layer)
    }

    func appendEvent(event: UIEvent) {
        guard event.type == .touches else { return }
        guard let touches = event.allTouches else { return }

        for touch in touches {
            appendTouch(touch: touch)
        }

        layer.setNeedsDisplay()
        layer.displayIfNeeded()
        bumpLayer()
    }

    func appendTouch(touch: UITouch) {
        guard let view = view else { return }

        let touchHash = touch.hash
        let point = touch.location(in: view)

        let index = gestures.index(where: { (gesture) -> Bool in
            return gesture.touchHash == touchHash
        })

        if let index = index {
            if touch.phase == .ended { gestures[index].ended = true; gestures[index].touchHash = nil }
            if touch.phase == .cancelled { gestures[index].cancelled = true; gestures[index].touchHash = nil }
            gestures[index].points.append(point)
        } else {
            if gestures.count > maxGesturesShown { gestures.removeFirst() }

            let colour = UIColor(hue: CGFloat(fmod(Float(counter) * 0.391, 1)), saturation: 1, brightness: 0.5, alpha: 1)
            let angle = 45 * (CGFloat(fmod(Float(counter) * 0.279, 1)) * 2 - 1)

            gestures.append(Gesture(firstPoint: point, colour: colour, angle: angle, touchHash: touch.hash))

            counter += 1
        }
    }

    private static let swizzleMethods: Bool = {
        let originalSelector = #selector(UIApplication.sendEvent(_:))
        let swizzledSelector = #selector(UIApplication.monkey_sendEvent(_:))
        
        let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector)
        
        let didAddMethod = class_addMethod(UIApplication.self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(UIApplication.self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }

        return true
    }()
    
    func tapUIApplicationSendEvent() {
        _ = MonkeyPaws.swizzleMethods
        MonkeyPaws.tappingTracks.append(WeakReference(self))
    }

    public func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.clear(layer.bounds)

        UIGraphicsPushContext(ctx)

        for (index, gesture) in gestures.enumerated() {
            let fraction = Float(maxGesturesShown - gestures.count + index + 1) / Float(maxGesturesShown)
            let alpha = CGFloat(sqrt(fraction))

            ctx.setAlpha(alpha)
            gesture.colour.setStroke()

            let startPoint = gesture.points.first!
            drawMonkeyHand(colour: gesture.colour, at: startPoint, content: String(gestures.count - index), angle: gesture.angle, scale: 1)

            if gesture.points.count >= 2 {
                let endPoint = gesture.points.last!

                if gesture.ended {
                    drawCircle(colour: gesture.colour, at: endPoint)
                }

                if gesture.cancelled {
                    drawCross(colour: gesture.colour, at: endPoint)
                }

                ctx.saveGState()

                let clipPath = UIBezierPath(rect: layer.bounds)
                let handPath = monkeyHand()
                handPath.apply(CGAffineTransform(rotationAngle: gesture.angle / 180 * CGFloat.pi))
                handPath.apply(CGAffineTransform(translationX: startPoint.x, y: startPoint.y))

                clipPath.append(handPath)
                clipPath.usesEvenOddFillRule = true
                clipPath.addClip()

                let path = UIBezierPath()
                path.move(to: startPoint)
                for point in gesture.points.dropFirst() {
                    path.addLine(to: point)
                }

                path.stroke()

                ctx.restoreGState()
            }
        }

        UIGraphicsPopContext()
    }

    func bumpLayer() {
        guard let superlayer = layer.superlayer else { return }
        guard let layers = superlayer.sublayers else { return }
        guard let index = layers.index(of: layer) else { return }
        if index != layers.count - 1 {
            layer.removeFromSuperlayer()
            superlayer.addSublayer(layer)
        }
    }
}

func drawMonkeyHand(colour: UIColor, at: CGPoint, content: String, angle: CGFloat, scale: CGFloat) {
    let context = UIGraphicsGetCurrentContext()!

    context.saveGState()
    context.translateBy(x: at.x, y: at.y)
    context.rotate(by: -angle * CGFloat.pi/180)
    context.scaleBy(x: scale, y: scale)

    let bezierPath = monkeyHand()
    colour.setStroke()
    bezierPath.lineWidth = 1
    bezierPath.stroke()

    context.restoreGState()

    context.saveGState()
    context.translateBy(x: at.x, y: at.y)

    let textRect = CGRect(x: -14, y: -10.5, width: 28, height: 21)
    let textStyle = NSMutableParagraphStyle()
    textStyle.alignment = .center
    let textFontAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 10), NSForegroundColorAttributeName: colour, NSParagraphStyleAttributeName: textStyle]

    let textTextHeight: CGFloat = content.boundingRect(with: CGSize(width: textRect.width, height: CGFloat.infinity), options: .usesLineFragmentOrigin, attributes: textFontAttributes, context: nil).height
    context.saveGState()
    context.clip(to: textRect)
    content.draw(in: CGRect(x: textRect.minX, y: textRect.minY + (textRect.height - textTextHeight) / 2, width: textRect.width, height: textTextHeight), withAttributes: textFontAttributes)
    context.restoreGState()

    context.restoreGState()
}

func monkeyHand() -> UIBezierPath {
    let bezierPath = UIBezierPath()
    bezierPath.move(to: CGPoint(x: -5.91, y: 8.76))
    bezierPath.addCurve(to: CGPoint(x: -10.82, y: 2.15), controlPoint1: CGPoint(x: -9.18, y: 7.11), controlPoint2: CGPoint(x: -8.09, y: 4.9))
    bezierPath.addCurve(to: CGPoint(x: -16.83, y: -1.16), controlPoint1: CGPoint(x: -13.56, y: -0.6), controlPoint2: CGPoint(x: -14.65, y: 0.5))
    bezierPath.addCurve(to: CGPoint(x: -14.65, y: -6.11), controlPoint1: CGPoint(x: -19.02, y: -2.81), controlPoint2: CGPoint(x: -19.57, y: -6.66))
    bezierPath.addCurve(to: CGPoint(x: -8.09, y: -2.81), controlPoint1: CGPoint(x: -9.73, y: -5.56), controlPoint2: CGPoint(x: -8.64, y: -0.05))
    bezierPath.addCurve(to: CGPoint(x: -11.37, y: -13.82), controlPoint1: CGPoint(x: -7.54, y: -5.56), controlPoint2: CGPoint(x: -7, y: -8.32))
    bezierPath.addCurve(to: CGPoint(x: -7.54, y: -17.13), controlPoint1: CGPoint(x: -15.74, y: -19.33), controlPoint2: CGPoint(x: -9.73, y: -20.98))
    bezierPath.addCurve(to: CGPoint(x: -4.27, y: -8.87), controlPoint1: CGPoint(x: -5.36, y: -13.27), controlPoint2: CGPoint(x: -6.45, y: -7.76))
    bezierPath.addCurve(to: CGPoint(x: -4.27, y: -18.23), controlPoint1: CGPoint(x: -2.08, y: -9.97), controlPoint2: CGPoint(x: -3.72, y: -12.72))
    bezierPath.addCurve(to: CGPoint(x: 0.65, y: -18.23), controlPoint1: CGPoint(x: -4.81, y: -23.74), controlPoint2: CGPoint(x: 0.65, y: -25.39))
    bezierPath.addCurve(to: CGPoint(x: 1.2, y: -8.32), controlPoint1: CGPoint(x: 0.65, y: -11.07), controlPoint2: CGPoint(x: -0.74, y: -9.29))
    bezierPath.addCurve(to: CGPoint(x: 3.93, y: -18.78), controlPoint1: CGPoint(x: 2.29, y: -7.76), controlPoint2: CGPoint(x: 3.93, y: -9.3))
    bezierPath.addCurve(to: CGPoint(x: 8.3, y: -16.03), controlPoint1: CGPoint(x: 3.93, y: -23.19), controlPoint2: CGPoint(x: 9.96, y: -21.86))
    bezierPath.addCurve(to: CGPoint(x: 5.57, y: -6.11), controlPoint1: CGPoint(x: 7.76, y: -14.1), controlPoint2: CGPoint(x: 3.93, y: -6.66))
    bezierPath.addCurve(to: CGPoint(x: 9.4, y: -10.52), controlPoint1: CGPoint(x: 7.21, y: -5.56), controlPoint2: CGPoint(x: 9.16, y: -10.09))
    bezierPath.addCurve(to: CGPoint(x: 12.13, y: -6.66), controlPoint1: CGPoint(x: 12.13, y: -15.48), controlPoint2: CGPoint(x: 15.41, y: -9.42))
    bezierPath.addCurve(to: CGPoint(x: 8.3, y: -1.16), controlPoint1: CGPoint(x: 8.85, y: -3.91), controlPoint2: CGPoint(x: 8.85, y: -3.91))
    bezierPath.addCurve(to: CGPoint(x: 8.3, y: 7.11), controlPoint1: CGPoint(x: 7.76, y: 1.6), controlPoint2: CGPoint(x: 9.4, y: 4.35))
    bezierPath.addCurve(to: CGPoint(x: -5.91, y: 8.76), controlPoint1: CGPoint(x: 7.21, y: 9.86), controlPoint2: CGPoint(x: -2.63, y: 10.41))
    bezierPath.close()

    return bezierPath
}

func drawCircle(colour: UIColor, at: CGPoint) {
    let endCircle = UIBezierPath(ovalIn: CGRect(centre: at, size: CGSize(width: circleRadius * 2, height: circleRadius * 2)))
    endCircle.stroke()
}

func drawCross(colour: UIColor, at: CGPoint) {
    let rect = CGRect(centre: at, size: CGSize(width: crossRadius * 2, height: crossRadius * 2))
    let cross = UIBezierPath()
    cross.move(to: CGPoint(x: rect.minX, y: rect.minY))
    cross.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    cross.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    cross.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    colour.setStroke()
    cross.stroke()
}

extension UIApplication {
    func monkey_sendEvent(_ event: UIEvent) {
        for weakTrack in MonkeyPaws.tappingTracks {
            if let track = weakTrack.value {
                track.appendEvent(event: event)
            }
        }

        self.monkey_sendEvent(event)
    }
}

private struct Gesture {
    var points: [CGPoint]
    let colour: UIColor
    let angle: CGFloat
    var touchHash: Int?
    var ended: Bool
    var cancelled: Bool

    init(firstPoint: CGPoint, colour: UIColor, angle: CGFloat, touchHash: Int) {
        self.points = [firstPoint]
        self.colour = colour
        self.angle = angle
        self.touchHash = touchHash
        self.ended = false
        self.cancelled = false
    }
}

private struct WeakReference<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

extension CGRect {
    public init(centre: CGPoint, size: CGSize) {
        self.origin = CGPoint(x: centre.x - size.width / 2, y: centre.y - size.height / 2)
        self.size = size
    }
}

//#endif
