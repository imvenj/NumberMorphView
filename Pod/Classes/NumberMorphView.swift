//
//  NumberMorphView.swift
//  Pods
//
//  Created by Abhinav Chauhan on 14/03/16.
//
//

import Foundation
import UIKit
import QuartzCore

public protocol InterpolatorProtocol {
    func getInterpolation(_ x: CGFloat) -> CGFloat;
}

// Recommended ration for width : height is 13 : 24
@IBDesignable open class NumberMorphView: UIView {
    
    fileprivate static let DEFAULT_FONT_SIZE: CGFloat = 24;
    
    // *************************************************************************************************
    // * IBInspectable properties
    // *************************************************************************************************
    
    @IBInspectable open var fontSize: CGFloat = NumberMorphView.DEFAULT_FONT_SIZE {
        didSet {
            self.lineWidth = fontSize / 16;
            invalidateIntrinsicContentSize();
        }
    }
    
    @IBInspectable open var lineWidth: CGFloat = 2 {
        didSet {
            path.lineWidth = lineWidth;
            shapeLayer.lineWidth = lineWidth;
        }
    }
    
    @IBInspectable open var fontColor: UIColor = UIColor.black.withAlphaComponent(0.6) {
        didSet {
            self.shapeLayer.strokeColor = fontColor.cgColor;
        }
    }
    
    @IBInspectable open var animationDuration: Double = 0.5 {
        didSet {
            if let displayLink = displayLink, displayLink.duration > 0 {
                maxFrames = Int(animationDuration / displayLink.duration);
            }
        }
    }
    
    // *************************************************************************************************
    // * Private properties
    // *************************************************************************************************
    
    fileprivate var endpoints_original: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 5), count: 10);
    fileprivate var controlPoints1_original: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 4), count: 10);
    fileprivate var controlPoints2_original: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 4), count: 10);
    
    fileprivate var endpoints_scaled: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 5), count: 10);
    fileprivate var controlPoints1_scaled: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 4), count: 10);
    fileprivate var controlPoints2_scaled: [[[CGFloat]]] = Array(repeating: Array(repeating: Array(repeating: 0, count: 2), count: 4), count: 10);
    
    fileprivate var paths = [UIBezierPath]();
    
    fileprivate var maxFrames = 0; // will be initialized in first update() call
    fileprivate var _currentDigit = 0;
    fileprivate var _nextDigit = 0;
    fileprivate var currentFrame = 1;
    
    fileprivate var displayLink: CADisplayLink?;
    fileprivate var path = UIBezierPath();
    fileprivate var shapeLayer = CAShapeLayer();
    
    // *************************************************************************************************
    // * Constructors
    // *************************************************************************************************
    
    override init(frame: CGRect) {
        super.init(frame: frame);
        initialize();
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder);
        initialize();
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews();
        scalePoints();
        initializePaths();
        shapeLayer.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: self.bounds.height);
        if nil == displayLink || displayLink!.isPaused {
            drawDigitWithoutAnimation(_currentDigit);
        }
    }
    
    override open var intrinsicContentSize : CGSize {
        return CGSize(width: fontSize * 0.65, height: fontSize * 1.2);
    }

    // *************************************************************************************************
    // * Method overrides
    // *************************************************************************************************

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        return self.intrinsicContentSize;
    }

    // *************************************************************************************************
    // * Public properties and methods
    // *************************************************************************************************
    
    open var interpolator: InterpolatorProtocol = OvershootInterpolator(tension: 1.3);
    
    open var currentDigit: Int {
        get {
            return _currentDigit;
        }
        set {
            _currentDigit = newValue;
            _nextDigit = _currentDigit;
        }
    }
    
    open var nextDigit: Int {
        get {
            return _nextDigit;
        }
        set {
            animateToDigit(newValue);
        }
    }
    
    open func animateToDigit(_ digit: Int) {
        _currentDigit = _nextDigit;
        _nextDigit = digit;
        currentFrame = 1;
        displayLink?.isPaused = false;
    }
    
    open func animateToDigit_withCABasicAnimation(_ digit: Int) {
        _currentDigit = _nextDigit;
        _nextDigit = digit;
        
        let anim = CABasicAnimation(keyPath: "path");
        anim.duration = 0.2;
        anim.fromValue = paths[_currentDigit].cgPath;
        anim.toValue = paths[_nextDigit].cgPath;
        anim.repeatCount = 0;
        anim.fillMode = CAMediaTimingFillMode.forwards;
        anim.isRemovedOnCompletion = false;
        anim.autoreverses = false;
        
        CATransaction.begin();
        CATransaction.setCompletionBlock() {
            self._currentDigit = self._nextDigit;
            print("completed");
        }
        shapeLayer.add(anim, forKey: "path");
        CATransaction.commit();
    }
    
    // *************************************************************************************************
    // * Helper / utility methods
    // *************************************************************************************************
    
    fileprivate func drawDigitWithoutAnimation(_ digit: Int) {
        let p = endpoints_scaled[digit];
        let cp1 = controlPoints1_scaled[digit];
        let cp2 = controlPoints2_scaled[digit];
        
        path.removeAllPoints();
        
        path.move(to: CGPoint(x: p[0][0], y: p[0][1]));
        for i in 1..<p.count {
            
            let endpoint = CGPoint(x: p[i][0], y: p[i][1]);
            let cp1 = CGPoint(x: cp1[i-1][0], y: cp1[i-1][1]);
            let cp2 = CGPoint(x: cp2[i-1][0], y: cp2[i-1][1]);
            
            path.addCurve(to: endpoint, controlPoint1: cp1, controlPoint2: cp2);
        }
        shapeLayer.path = path.cgPath;
    }
    
    @objc func updateAnimationFrame() {
        if maxFrames <= 0 {
            if let displayLink = displayLink {
                maxFrames = Int(animationDuration / displayLink.duration);
            }
        }
        
        let pCur = endpoints_scaled[_currentDigit];
        let cp1Cur = controlPoints1_scaled[_currentDigit];
        let cp2Cur = controlPoints2_scaled[_currentDigit];
        
        let pNext = endpoints_scaled[_nextDigit];
        let cp1Next = controlPoints1_scaled[_nextDigit];
        let cp2Next = controlPoints2_scaled[_nextDigit];
        
        path.removeAllPoints();
        let factor: CGFloat = interpolator.getInterpolation((CGFloat)(currentFrame) / (CGFloat)(maxFrames));
        
        path.move(to: CGPoint(x: pCur[0][0] + (pNext[0][0] - pCur[0][0]) * factor, y: pCur[0][1] + (pNext[0][1] - pCur[0][1]) * factor));
        for i in 1..<pCur.count {
            
            let ex = pCur[i][0] + (pNext[i][0] - pCur[i][0]) * factor
            let ey = pCur[i][1] + (pNext[i][1] - pCur[i][1]) * factor;
            let endpoint = CGPoint(x: ex, y: ey);
            
            let iMinus1 = i-1;
            let cp1x = cp1Cur[iMinus1][0] + (cp1Next[iMinus1][0] - cp1Cur[iMinus1][0]) * factor;
            let cp1y = cp1Cur[iMinus1][1] + (cp1Next[iMinus1][1] - cp1Cur[iMinus1][1]) * factor;
            let cp1 = CGPoint(x: cp1x, y: cp1y);
            
            let cp2x = cp2Cur[iMinus1][0] + (cp2Next[iMinus1][0] - cp2Cur[iMinus1][0]) * factor;
            let cp2y = cp2Cur[iMinus1][1] + (cp2Next[iMinus1][1] - cp2Cur[iMinus1][1]) * factor;
            let cp2 = CGPoint(x: cp2x, y: cp2y);
            
            path.addCurve(to: endpoint, controlPoint1: cp1, controlPoint2: cp2);
        }
        
        shapeLayer.path = path.cgPath;
        currentFrame += 1;
        
        if currentFrame > maxFrames {
            currentFrame = 1;
            currentDigit = _nextDigit;
            displayLink?.isPaused = true;
            drawDigitWithoutAnimation(currentDigit);
        }
    }
    
    fileprivate func initialize() {
        path.lineJoinStyle = .round;
        path.lineCapStyle = .round;
        path.miterLimit = -10;
        path.lineWidth = self.lineWidth;
        
        shapeLayer.fillColor = UIColor.clear.cgColor;
        shapeLayer.strokeColor = self.fontColor.cgColor;
        shapeLayer.lineWidth = self.lineWidth;
        shapeLayer.contentsScale = UIScreen.main.scale;
        shapeLayer.shouldRasterize = false;
        shapeLayer.lineCap = CAShapeLayerLineCap.round;
        shapeLayer.lineJoin = CAShapeLayerLineJoin.round;
        
        self.layer.addSublayer(shapeLayer);
        
        displayLink = CADisplayLink(target: self, selector: #selector(NumberMorphView.updateAnimationFrame));
        displayLink?.frameInterval = 1;
        displayLink?.isPaused = true;
        displayLink?.add(to: RunLoop.current, forMode: RunLoop.Mode.common);
        
        endpoints_original[0] = [[500, 800], [740, 400], [500, 0],   [260, 400], [500, 800]];
        endpoints_original[1] = [[383, 712], [500, 800], [500, 0],   [500, 800], [383, 712]];
        endpoints_original[2] = [[300, 640], [700, 640], [591, 369], [300, 0],   [700, 0]];
        endpoints_original[3] = [[300, 600], [700, 600], [500, 400], [700, 200], [300, 200]];
        endpoints_original[4] = [[650, 0],   [650, 140], [650, 800], [260, 140], [760, 140]];
        endpoints_original[5] = [[645, 800], [400, 800], [300, 480], [690, 285], [272, 92]];
        endpoints_original[6] = [[640, 800], [321, 458], [715, 144], [257, 146], [321, 458]];
        endpoints_original[7] = [[275, 800], [725, 800], [586, 544], [424, 262], [275, 0]];
        endpoints_original[8] = [[500, 400], [500, 0],   [500, 400], [500, 800], [500, 400]];
        endpoints_original[9] = [[679, 342], [743, 654], [285, 656], [679, 342], [360, 0]];
        
        controlPoints1_original[0] = [[650, 800], [740, 200], [350, 0],   [260, 600]];
        controlPoints1_original[1] = [[383, 712], [500, 488], [500, 488], [383, 712]];
        controlPoints1_original[2] = [[335, 853], [710, 538], [477, 213], [450, 0]];
        controlPoints1_original[3] = [[300, 864], [700, 400], [500, 400], [700, -64]];
        controlPoints1_original[4] = [[650, 50],  [650, 340], [502, 572], [350, 140]];
        controlPoints1_original[5] = [[550, 800], [400, 800], [495, 567], [717, 30]];
        controlPoints1_original[6] = [[578, 730], [492, 613], [634, -50], [208, 264]];
        controlPoints1_original[7] = [[350, 800], [676, 700], [538, 456], [366, 160],];
        controlPoints1_original[8] = [[775, 400], [225, 0],   [225, 400], [775, 800]];
        controlPoints1_original[9] = [[746, 412], [662, 850], [164, 398], [561, 219]];
        
        controlPoints2_original[0] = [[740, 600], [650, 0],   [260, 200], [350, 800]];
        controlPoints2_original[1] = [[500, 800], [500, 312], [500, 312], [500, 800]];
        controlPoints2_original[2] = [[665, 853], [658, 461], [424, 164], [544, 1]];
        controlPoints2_original[3] = [[700, 864], [500, 400], [700, 400], [300, -64]];
        controlPoints2_original[4] = [[650, 100], [650, 600], [356, 347], [680, 140]];
        controlPoints2_original[5] = [[450, 800], [300, 480], [672, 460], [410, -100]];
        controlPoints2_original[6] = [[455, 602], [840, 444], [337, -46], [255, 387]];
        controlPoints2_original[7] = [[500, 800], [634, 631], [487, 372], [334, 102]];
        controlPoints2_original[8] = [[775, 0],   [225, 400], [225, 800], [775, 400]];
        controlPoints2_original[9] = [[792, 536], [371, 840], [475, 195], [432, 79]];
        
        for digit in 0..<endpoints_original.count {
            for pointIndex in 0..<endpoints_original[digit].count {
                endpoints_original[digit][pointIndex][1] = 800 - endpoints_original[digit][pointIndex][1];
                if pointIndex < 4 {
                    controlPoints1_original[digit][pointIndex][1] = 800 - controlPoints1_original[digit][pointIndex][1];
                    controlPoints2_original[digit][pointIndex][1] = 800 - controlPoints2_original[digit][pointIndex][1];
                }
            } // for pointIndex
        } // for digit
    }
    
    fileprivate func scalePoints() {
        let width = self.bounds.width;
        let height = self.bounds.height;
        
        for digit in 0..<endpoints_original.count {
            for pointIndex in 0..<endpoints_original[digit].count {
                
                endpoints_scaled[digit][pointIndex][0] = (endpoints_original[digit][pointIndex][0] / 1000.0 * 1.4 - 0.2) * width;
                endpoints_scaled[digit][pointIndex][1] = (endpoints_original[digit][pointIndex][1] / 800.0 * 0.6 + 0.2) * height;
                
                if pointIndex < 4 {
                    controlPoints1_scaled[digit][pointIndex][0] = (controlPoints1_original[digit][pointIndex][0] / 1000.0 * 1.4 - 0.2) * width;
                    controlPoints1_scaled[digit][pointIndex][1] = (controlPoints1_original[digit][pointIndex][1] / 800.0 * 0.6 + 0.2) * height;
                    
                    controlPoints2_scaled[digit][pointIndex][0] = (controlPoints2_original[digit][pointIndex][0] / 1000.0 * 1.4 - 0.2) * width;
                    controlPoints2_scaled[digit][pointIndex][1] = (controlPoints2_original[digit][pointIndex][1] / 800.0 * 0.6 + 0.2) * height;
                }
            } // for pointIndex
        } // for digit
    }
    
    fileprivate func initializePaths() {
        paths.removeAll();
        for digit in 0...9 {
            paths.append(UIBezierPath());
            let p = endpoints_scaled[digit];
            let cp1 = controlPoints1_scaled[digit];
            let cp2 = controlPoints2_scaled[digit];
            paths[digit].move(to: CGPoint(x: p[0][0], y: p[0][1]));
            for i in 1..<p.count {
                let endpoint = CGPoint(x: p[i][0], y: p[i][1]);
                let cp1 = CGPoint(x: cp1[i-1][0], y: cp1[i-1][1]);
                let cp2 = CGPoint(x: cp2[i-1][0], y: cp2[i-1][1]);
                paths[digit].addCurve(to: endpoint, controlPoint1: cp1, controlPoint2: cp2);
            }
        }
    }
    
    // *************************************************************************************************
    // * Interpolators for rate of change of animation
    // *************************************************************************************************
    
    open class LinearInterpolator: InterpolatorProtocol {
        
        public init() {
        }
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            return x;
        }
    }
    
    open class OvershootInterpolator: InterpolatorProtocol {
        
        fileprivate var tension: CGFloat;
        
        public convenience init() {
            self.init(tension: 2.0);
        }
        
        public init(tension: CGFloat) {
            self.tension = tension;
        }
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            let x2 = x - 1.0;
            return x2 * x2 * ((tension + 1) * x2 + tension) + 1.0;
        }
        
    }
    
    open class SpringInterpolator: InterpolatorProtocol {
        
        fileprivate var tension: CGFloat;
        fileprivate let PI = CGFloat(Double.pi);
        
        public convenience init() {
            self.init(tension: 0.3);
        }
        
        public init(tension: CGFloat) {
            self.tension = tension;
        }
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            return pow(2, -10 * x) * sin((x - tension / 4) * (2 * PI) / tension) + 1;
        }
        
    }
    
    open class BounceInterpolator: InterpolatorProtocol {
        
        public init() {
        }
        
        func bounce(_ t: CGFloat) -> CGFloat { return t * t * 8; }
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            if (x < 0.3535) {
                return bounce(x)
            } else if (x < 0.7408) {
                return bounce(x - 0.54719) + 0.7;
            } else if (x < 0.9644) {
                return bounce(x - 0.8526) + 0.9;
            } else {
                return bounce(x - 1.0435) + 0.95;
            }
        }
    }
    
    open class AnticipateOvershootInterpolator: InterpolatorProtocol {
        fileprivate var tension: CGFloat = 2.0;
        
        public convenience init() {
            self.init(tension: 2.0);
        }
        
        public init(tension: CGFloat) {
            self.tension = tension;
        }
        
        fileprivate func anticipate(_ x: CGFloat, tension: CGFloat) -> CGFloat { return x * x * ((tension + 1) * x - tension); }
        fileprivate func overshoot(_ x: CGFloat, tension: CGFloat) -> CGFloat { return x * x * ((tension + 1) * x + tension); }
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            if x < 0.5 {
                return 0.5 * anticipate(x * 2.0, tension: tension);
            } else {
                return 0.5 * (overshoot(x * 2.0 - 2.0, tension: tension) + 2.0);
            }
        }
    }
    
    open class CubicHermiteInterpolator: InterpolatorProtocol {
        fileprivate var tangent0: CGFloat;
        fileprivate var tangent1: CGFloat;
        
        public convenience init() {
            self.init(tangent0: 2.2, tangent1: 2.2);
        }
        
        public init(tangent0: CGFloat, tangent1: CGFloat) {
            self.tangent0 = tangent0;
            self.tangent1 = tangent1;
        }
        
        func cubicHermite(_ t: CGFloat, start: CGFloat, end: CGFloat, tangent0: CGFloat, tangent1: CGFloat) -> CGFloat {
            let t2 = t * t;
            let t3 = t2 * t;
            return (2 * t3 - 3 * t2 + 1) * start + (t3 - 2 * t2 + t) * tangent0 + (-2 * t3 + 3 * t2) * end + (t3 - t2) * tangent1;
        }
        
        
        open func getInterpolation(_ x: CGFloat) -> CGFloat {
            return cubicHermite(x, start: 0, end: 1, tangent0: tangent0, tangent1: tangent1);
        }
        
    }
}























