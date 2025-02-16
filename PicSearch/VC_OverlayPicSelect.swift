//
// VC_OverlayPicSelect.swift
// PicSearch
//
// Created by ChaosTong on 2025/2/13
// Copyright © 2025 ChaosTong. All Rights Reserved.

import UIKit
import Combine

enum PanEdge {
    case none
    case top
    case bottom
    case left
    case right
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
}

let SCREEN_WIDTH = UIScreen.main.bounds.size.width

struct Position {
    let x1: CGFloat
    let x2: CGFloat
    let y1: CGFloat
    let y2: CGFloat
}

class VC_OverlayPicSelect: UIViewController {
    
    var containerView: UIView!
    
    var overlay: OverlayView = OverlayView()
    
    var topConstraint: NSLayoutConstraint!
    var leftConstraint: NSLayoutConstraint!
    var widthConstraint: NSLayoutConstraint!
    var heightConstraint: NSLayoutConstraint!
    
    var startPoint: CGPoint = .zero
    var panEdge: PanEdge = .none
    var startFrame: CGRect = .zero
    
    let maxWidth: CGFloat = 50
    let maxHeight: CGFloat = 50
    
    var panGesture: UIPanGestureRecognizer!
    
    lazy var shapeLayer = CAShapeLayer()
    let vScroll = UIScrollView()
    let iv = UIImageView()
    let bottomSheet = CustomHeightView()
    
    var image: UIImage!
    var positions: [Position] = []
    var flag = false
    
    private var cancellables = Set<AnyCancellable>()
    private var panGestureSubject = PassthroughSubject<UIPanGestureRecognizer, Never>()
    private var networkRequestCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        let rightButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(buttonTapped))
        navigationItem.rightBarButtonItem = rightButton
        
        iv.image = image
        vScroll.contentSize = CGSize(width: SCREEN_WIDTH, height: SCREEN_WIDTH/(image.size.width/image.size.height))
        view.addSubview(vScroll)
        vScroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vScroll.topAnchor.constraint(equalTo: view.topAnchor),
            vScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -200),
            vScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        vScroll.layoutIfNeeded()

        vScroll.addSubview(iv)
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: vScroll.leadingAnchor),
            iv.topAnchor.constraint(equalTo: vScroll.topAnchor),
            iv.widthAnchor.constraint(equalToConstant: SCREEN_WIDTH),
            iv.heightAnchor.constraint(equalToConstant: SCREEN_WIDTH / (image.size.width / image.size.height))
        ])

        containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        vScroll.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: vScroll.leadingAnchor),
            containerView.topAnchor.constraint(equalTo: vScroll.topAnchor),
            containerView.widthAnchor.constraint(equalToConstant: SCREEN_WIDTH),
            containerView.heightAnchor.constraint(equalToConstant: SCREEN_WIDTH / (image.size.width / image.size.height))
        ])
        
        vScroll.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        configButtons()

        guard var p = positions.first else {
            fatalError("position can't be empty!")
        }
        if let target = positions.get(1) {
            p = target
        }
        let scale = image.size.width / vScroll.contentSize.width
        topConstraint = overlay.topAnchor.constraint(equalTo: vScroll.topAnchor, constant: p.y1/scale)
        topConstraint.isActive = true
        leftConstraint = overlay.leftAnchor.constraint(equalTo: vScroll.leftAnchor, constant: p.x1/scale)
        leftConstraint.isActive = true
        widthConstraint = overlay.widthAnchor.constraint(equalToConstant: (p.x2-p.x1)/scale)
        widthConstraint.isActive = true
        heightConstraint = overlay.heightAnchor.constraint(equalToConstant: (p.y2-p.y1)/scale)
        heightConstraint.isActive = true
        for v in vScroll.subviews {
            if v.tag - 9900 == 0 {
                v.isHidden = true
            }
        }
        
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGestureAnction(_:)))
        panGestureSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] pan in
                self?.performNetworkRequest()
            }
            .store(in: &cancellables)
        overlay.addGestureRecognizer(panGesture)
        
        bottomSheet.selectBlock = { [weak self] i in
            guard let self = self else { return }
            let p = positions[i]
            setOverlayFrameByFourPoints(x1: p.x1+(p.x2-p.x1)/2-5, y1: p.y1+(p.y2-p.y1)/2-5, x2: p.x1+(p.x2-p.x1)/2+5, y2: p.y1+(p.y2-p.y1)/2+5)
            setOverlayFrameByFourPoints(x1: p.x1, y1: p.y1, x2: p.x2, y2: p.y2, true)
            addLouKong(true)
            for v in vScroll.subviews {
                if v.tag - 9900 == i {
                    v.isHidden = true
                } else {
                    v.isHidden = false
                }
            }
        }
        var dataList: [UIImage] = []
        for p in positions {
            let cropRect = CGRect(x: p.x1, y: p.y1, width: p.x2-p.x1, height: p.y2-p.y1)
            if let croppedImage = cropImage(image: image, toRect: cropRect, viewWidth: vScroll.contentSize.width, viewHeight: vScroll.contentSize.height) {
                dataList.append(croppedImage)
            }
        }
        bottomSheet.selectedIndex = dataList.count > 1 ? 1 : 0
        bottomSheet.dataList = dataList
        bottomSheet.dismissBlock = {
            self.navigationController?.popViewController(animated: true)
        }
        view.addSubview(bottomSheet)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        addLouKong()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    func configButtons() {
        let scale = image.size.width / vScroll.contentSize.width
        for (i, p) in positions.enumerated() {
            if i == 0 { continue }
            let btn = UIButton.init(type: .system, primaryAction: UIAction.init(handler: { [weak self] _ in
                guard let self = self else { return }
                let p = positions[i]
                setOverlayFrameByFourPoints(x1: p.x1+(p.x2-p.x1)/2-5, y1: p.y1+(p.y2-p.y1)/2-5, x2: p.x1+(p.x2-p.x1)/2+5, y2: p.y1+(p.y2-p.y1)/2+5)
                setOverlayFrameByFourPoints(x1: p.x1, y1: p.y1, x2: p.x2, y2: p.y2, true)
                addLouKong(true)
                for v in vScroll.subviews {
                    if v.tag - 9900 == i {
                        v.isHidden = true
                    } else {
                        v.isHidden = false
                    }
                }
                
                bottomSheet.selectedIndex = i
            }))
            btn.tag = 9900 + i
            btn.frame = CGRect(origin: CGPoint(x: (p.x1+(p.x2-p.x1)/2)/scale-15, y: (p.y1+(p.y2-p.y1)/2)/scale-15), size: CGSize(width: 30, height: 30))
            btn.setImage(UIImage(systemName: "target"), for: .normal)
            btn.tintColor = .white
            UIView.animate(withDuration: 0.6,
                           delay: 0,
                           options: [.repeat, .autoreverse, .allowUserInteraction],
                           animations: {
                btn.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }, completion: nil)
            vScroll.addSubview(btn)
        }
    }
    
    @objc func buttonTapped() {
//        let cropRect = overlay.frame
//        
//        // 截取图片的部分区域
//        if let croppedImage = cropImage(image: image, toRect: cropRect, viewWidth: vScroll.contentSize.width, viewHeight: vScroll.contentSize.height) {
//            
//            let vc = VC_Result()
//            vc.originImage = image
//            vc.image = croppedImage
//            navigationController?.pushViewController(VC_Present(), animated: true)
//        }
        
//        if bottomSheet == nil {
//            bottomSheet = CustomHeightView()
//            bottomSheet?.dismissBlock = {
//                self.navigationController?.popViewController(animated: true)
//            }
//            view.addSubview(bottomSheet!)
//        } else {
//            bottomSheet?.removeFromSuperview()
//            bottomSheet = CustomHeightView()
//            bottomSheet?.dismissBlock = {
//                self.navigationController?.popViewController(animated: true)
//            }
//            view.addSubview(bottomSheet!)
//        }
    }
    
    func cropImage(image: UIImage, toRect rect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
        let scale = image.size.width / viewWidth
        let scaledRect = CGRect(x: rect.origin.x * scale, y: rect.origin.y * scale, width: rect.size.width * scale, height: rect.size.height * scale)
#if DEBUG
        print("position in view, x1: \(rect.origin.x), x2: \(rect.origin.x+rect.width), y1: \(rect.origin.y), y2:\(rect.origin.y+rect.height)")
        print("position in image, x1: \(scaledRect.origin.x), x2: \(scaledRect.origin.x+scaledRect.width), y1: \(scaledRect.origin.y), y2:\(scaledRect.origin.y+scaledRect.height)")
#endif
        guard let cgImage = image.cgImage?.cropping(to: scaledRect) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func scaledPoint(_ point: CGPoint, for image: UIImage) -> CGPoint {
        // 按宽度进行缩放
        let scale = SCREEN_WIDTH / image.size.width
        return CGPoint(x: point.x * scale, y: point.y * scale)
    }

    func setOverlayFrameByFourPoints(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat, _ animate: Bool = false) {
        // 计算四个角点的坐标
        let topLeft = CGPoint(x: x1, y: y1)
        let topRight = CGPoint(x: x2, y: y1)
        let bottomLeft = CGPoint(x: x1, y: y2)
        let bottomRight = CGPoint(x: x2, y: y2)

        // 先将原图坐标转换为缩放后的坐标
        let tL = scaledPoint(topLeft, for: image)
        let tR = scaledPoint(topRight, for: image)
        let bL = scaledPoint(bottomLeft, for: image)
        let bR = scaledPoint(bottomRight, for: image)

        // 然后与滚动视图的 contentSize 对比
        let minX = max(0, min(tL.x, bL.x))
        let maxX = min(vScroll.contentSize.width, max(tR.x, bR.x))
        let minY = max(0, min(tL.y, tR.y))
        let maxY = min(vScroll.contentSize.height, max(bL.y, bR.y))

        if animate {
            UIView.animate(withDuration: 0.3) {
                self.leftConstraint.constant = minX
                self.topConstraint.constant = minY
                self.widthConstraint.constant = max(0, maxX - minX)
                self.heightConstraint.constant = max(0, maxY - minY)
                
                self.vScroll.layoutIfNeeded()
            }
        } else {
            leftConstraint.constant = minX
            topConstraint.constant = minY
            widthConstraint.constant = max(0, maxX - minX)
            heightConstraint.constant = max(0, maxY - minY)
            
            vScroll.layoutIfNeeded()
        }
    }
    
    /// 镂空部分
    func addLouKong(_ animate: Bool = false) {
        let gap: CGFloat = 6
        let path = UIBezierPath(rect: containerView.frame)
        let overlayPath = UIBezierPath(roundedRect: CGRect(x: overlay.frame.origin.x+gap, y: overlay.frame.origin.y+gap, width: overlay.frame.width-gap*2, height: overlay.frame.height-gap*2), cornerRadius: 4)
        path.append(overlayPath)
        
        shapeLayer.path = path.cgPath
        shapeLayer.fillRule = .evenOdd
        containerView.layer.mask = shapeLayer
        
        if animate {
            let initialPath = UIBezierPath(rect: containerView.frame)
            let initialOverlayPath = UIBezierPath(roundedRect: CGRect(x: overlay.frame.midX, y: overlay.frame.midY, width: 0, height: 0), cornerRadius: 4)
            initialPath.append(initialOverlayPath)
            
            // 添加动画效果
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = initialPath.cgPath
            animation.toValue = path.cgPath
            animation.duration = 0.3 // 动画持续时间
            shapeLayer.add(animation, forKey: "pathAnimation")
        }
    }
    
    @objc func handlePanGestureAnction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: vScroll)
        
        switch pan.state {
        case .began:
            startPoint = point
            startFrame = overlay.frame
            
            panEdge = calculatePanEdge(at: point)
        case .changed:
            updateOverlayFrame(at: point)
            performNetworkRequest()
            
            addLouKong()
        default:
            panEdge = .none
        }
    }
    
    private func performNetworkRequest() {
        let scale = image.size.width / vScroll.contentSize.width
        // 取消之前的网络请求
        networkRequestCancellable?.cancel()
        
        // 发起新的网络请求
        networkRequestCancellable = URLSession.shared.dataTaskPublisher(for: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
            .receive(on: DispatchQueue.main) // 确保在主线程上接收
            .sink(receiveCompletion: { [weak self] completion in
                // 处理完成
                guard let self = self else { return }
                print("completion")
                let cropRect = self.overlay.frame
                if let croppedImage = self.cropImage(image: self.image, toRect: cropRect, viewWidth: self.vScroll.contentSize.width, viewHeight: self.vScroll.contentSize.height) {
                    var dataList = bottomSheet.dataList
                    if flag {
                        dataList[dataList.count-1] = croppedImage
                        positions[positions.count-1] = Position(x1: cropRect.origin.x*scale, x2: (cropRect.origin.x+cropRect.size.width)*scale, y1: cropRect.origin.y*scale, y2: (cropRect.origin.y+cropRect.size.height)*scale)
                    } else {
                        flag = true
                        dataList.append(croppedImage)
                        positions.append(Position(x1: cropRect.origin.x*scale, x2: (cropRect.origin.x+cropRect.size.width)*scale, y1: cropRect.origin.y*scale, y2: (cropRect.origin.y+cropRect.size.height)*scale))
                    }
                    self.bottomSheet.dataList = dataList
                    self.bottomSheet.selectedIndex = self.bottomSheet.dataList.count - 1
                }
            }, receiveValue: { data, response in
                // 处理响应
            })
    }
    
    func calculatePanEdge(at point: CGPoint) -> PanEdge {
        let frame = overlay.frame.insetBy(dx: -20, dy: -20)
        
        if !CGRectContainsPoint(frame, point) {
            return .none
        }
        
        let cornerSize = CGSize(width: 50, height: 50)
        
        let topLeftRect = CGRect(origin: frame.origin, size: cornerSize)
        if topLeftRect.contains(point) {
            return .topLeft
        }
        
        let topRightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.minY), size: cornerSize)
        if topRightRect.contains(point) {
            return .topRight
        }
        
        let bottomLeftRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY - cornerSize.height), size: cornerSize)
        if bottomLeftRect.contains(point) {
            return .bottomLeft
        }
        
        let bottomRightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.maxY - cornerSize.height), size: cornerSize)
        if bottomRightRect.contains(point) {
            return .bottomRight
        }
        
        let topRect = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: cornerSize.height))
        if topRect.contains(point) {
            return .top
        }
        
        let bottomRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY - cornerSize.height), size: CGSize(width: frame.width, height: cornerSize.height))
        if bottomRect.contains(point) {
            return .bottom
        }
        
        let leftRect = CGRect(origin: frame.origin, size: CGSize(width: cornerSize.width, height: frame.height))
        if leftRect.contains(point) {
            return .left
        }
        
        let rightRect = CGRect(origin: CGPoint(x: frame.maxX - cornerSize.width, y: frame.minY), size: CGSize(width: cornerSize.width, height: frame.height))
        if rightRect.contains(point) {
            return .right
        }
        
        return .center
    }
    
    func updateOverlayFrame(at point: CGPoint) {
        if panEdge == .none { return }
        
        for v in vScroll.subviews {
            if v.tag - 9900 >= 0 {
                v.isHidden = false
            }
        }
        
        let movedWidth = point.x  - startPoint.x
        let movedHeight = point.y - startPoint.y
        
        switch panEdge {
        case .topLeft:
            leftConstraint.constant = min(CGRectGetMaxX(startFrame) - maxWidth, max(CGRectGetMinX(startFrame) + movedWidth, 0))
            widthConstraint.constant = CGRectGetMaxX(startFrame) - leftConstraint.constant
            
            topConstraint.constant = min(CGRectGetMaxY(startFrame) - maxHeight, max(CGRectGetMinY(startFrame) + movedHeight, 0))
            heightConstraint.constant = CGRectGetMaxY(startFrame) - topConstraint.constant
        case .topRight:
            widthConstraint.constant = min(max(CGRectGetWidth(startFrame) + movedWidth, maxWidth), CGRectGetWidth(vScroll.frame) - leftConstraint.constant)
            
            topConstraint.constant = min(CGRectGetMaxY(startFrame) - maxHeight, max(CGRectGetMinY(startFrame) + movedHeight, 0))
            heightConstraint.constant =  CGRectGetMaxY(startFrame) - topConstraint.constant
            
        case .bottomLeft:
            leftConstraint.constant = min(CGRectGetMaxX(startFrame) - maxWidth, max(CGRectGetMinX(startFrame) + movedWidth, 0))
            widthConstraint.constant = CGRectGetMaxX(startFrame) - leftConstraint.constant
            
            heightConstraint.constant = min(
                    vScroll.contentSize.height - CGRectGetMinY(overlay.frame),
                    max(CGRectGetHeight(startFrame) + movedHeight, maxHeight)
                )
            
        case .bottomRight:
            widthConstraint.constant = min(max(CGRectGetWidth(startFrame) + movedWidth, maxWidth), CGRectGetWidth(vScroll.frame) - leftConstraint.constant)
            heightConstraint.constant = min(
                max(CGRectGetHeight(startFrame) + movedHeight, maxHeight),
                vScroll.contentSize.height - topConstraint.constant
            )
        
        case .center:
            leftConstraint.constant = min(max(startFrame.origin.x + movedWidth, 0), CGRectGetWidth(vScroll.frame) - CGRectGetWidth(startFrame))
            topConstraint.constant = min(
                max(startFrame.origin.y + movedHeight, 0),
                vScroll.contentSize.height - CGRectGetHeight(startFrame)
            )
            
        case .top:
            topConstraint.constant = min(CGRectGetMaxY(startFrame) - maxHeight, max(CGRectGetMinY(startFrame) + movedHeight, 0))
            heightConstraint.constant = CGRectGetMaxY(startFrame) - topConstraint.constant
            
        case .left:
            leftConstraint.constant = min(CGRectGetMaxX(startFrame) - maxWidth, max(CGRectGetMinX(startFrame) + movedWidth, 0))
            widthConstraint.constant = CGRectGetMaxX(startFrame) - leftConstraint.constant
            
        case .bottom:
            let newHeight = CGRectGetHeight(startFrame) + movedHeight
            let maxAvailableHeight = vScroll.contentSize.height - topConstraint.constant

            // 确保 newHeight 在 maxHeight 和 maxAvailableHeight 之间
            heightConstraint.constant = max(min(newHeight, maxAvailableHeight), maxHeight)
            
        case .right:
            widthConstraint.constant = min(max(CGRectGetWidth(startFrame) + movedWidth, maxWidth), CGRectGetWidth(vScroll.frame) - leftConstraint.constant)
        case .none:
            print("")
        }
        
        // 确保 overlay 不会超出 superview 的边界
        leftConstraint.constant = max(leftConstraint.constant, 0)
        topConstraint.constant = max(topConstraint.constant, 0)
        widthConstraint.constant = min(
            widthConstraint.constant,
            vScroll.contentSize.width - leftConstraint.constant
        )
        heightConstraint.constant = min(
            heightConstraint.constant,
            vScroll.contentSize.height - topConstraint.constant
        )
    }

}

class OverlayView: UIView {
    
    let cornerLineWidth: CGFloat = 5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let boldLineLength: CGFloat = 20
        let cornerRadius: CGFloat = 8
        let strokeWidth: CGFloat = 5 // 线条宽度
        let halfStroke = strokeWidth / 2

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineJoin(.round)  // 让线条转角更圆滑
        context.setLineCap(.round)   // 让线条端点更圆滑

        context.beginPath()

        // 左上角
        context.move(to: CGPoint(x: halfStroke, y: boldLineLength + halfStroke)) // 垂直线
        context.addLine(to: CGPoint(x: halfStroke, y: cornerRadius + halfStroke))
        context.addArc(tangent1End: CGPoint(x: halfStroke, y: halfStroke),
                       tangent2End: CGPoint(x: cornerRadius + halfStroke, y: halfStroke),
                       radius: cornerRadius)
        context.addLine(to: CGPoint(x: boldLineLength + halfStroke, y: halfStroke))


        // 右上角
        context.move(to: CGPoint(x: rect.width - boldLineLength - halfStroke, y: halfStroke))
        context.addLine(to: CGPoint(x: rect.width - cornerRadius - halfStroke, y: halfStroke))
        context.addArc(tangent1End: CGPoint(x: rect.width - halfStroke, y: halfStroke),
                       tangent2End: CGPoint(x: rect.width - halfStroke, y: cornerRadius + halfStroke),
                       radius: cornerRadius)
        context.addLine(to: CGPoint(x: rect.width - halfStroke, y: boldLineLength))

        // 右下角
        context.move(to: CGPoint(x: rect.width - halfStroke, y: rect.height - boldLineLength - halfStroke))
        context.addLine(to: CGPoint(x: rect.width - halfStroke, y: rect.height - cornerRadius - halfStroke))
        context.addArc(tangent1End: CGPoint(x: rect.width - halfStroke, y: rect.height - halfStroke),
                       tangent2End: CGPoint(x: rect.width - cornerRadius - halfStroke, y: rect.height - halfStroke),
                       radius: cornerRadius)
        context.addLine(to: CGPoint(x: rect.width - boldLineLength - halfStroke, y: rect.height - halfStroke))

        // 左下角
        context.move(to: CGPoint(x: boldLineLength + halfStroke, y: rect.height - halfStroke))
        context.addLine(to: CGPoint(x: cornerRadius + halfStroke, y: rect.height - halfStroke))
        context.addArc(tangent1End: CGPoint(x: halfStroke, y: rect.height - halfStroke),
                       tangent2End: CGPoint(x: halfStroke, y: rect.height - cornerRadius - halfStroke),
                       radius: cornerRadius)
        context.addLine(to: CGPoint(x: halfStroke, y: rect.height - boldLineLength - halfStroke))

        context.strokePath()
    }

}

extension Array {
    func get(_ index: Int) -> Element? {
        if 0 <= index && index < count {
            return self[index]
        } else {
            return nil
        }
    }
}
