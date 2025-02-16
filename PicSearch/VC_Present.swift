//
//  VC_Present.swift
//  PicSearch
//
//  Created by chaostong on 2025/2/16.
//

import UIKit

class MainViewController: UIViewController {
    private var bottomSheet: CustomHeightView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        let button = UIButton(type: .system)
        button.setTitle("Show Bottom Sheet", for: .normal)
        button.addTarget(self, action: #selector(showBottomSheet), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func showBottomSheet() {
        if bottomSheet == nil {
            bottomSheet = CustomHeightView()
            view.addSubview(bottomSheet!)
        }
    }
}

class CustomHeightView: UIView {
    private let minHeight: CGFloat = 200
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9
    private let maxYOffset: CGFloat = 300 // 背景最多上移

    private var contentView: UIView!
    private var sliceContainer: UIView!
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 10
        layout.itemSize = CGSize(width: 40, height: 40)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(CustomHeightViewCell.self, forCellWithReuseIdentifier: CustomHeightViewCell.cellIdentifier)
        cv.dataSource = self
        cv.delegate = self
        return cv
    }()
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    private var initialFrame: CGRect = .zero // 记录初始 frame
    var selectedIndex = 0 {
        didSet {
            collectionView.reloadData()
        }
    }
    
    var dataList: [UIImage] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    var dismissBlock: (() -> Void)?
    var selectBlock: ((Int) -> Void)?

    init() {
        let initialHeight = minHeight
        let frame = CGRect(x: 0, y: UIScreen.main.bounds.height - initialHeight, width: UIScreen.main.bounds.width, height: initialHeight)
        super.init(frame: frame)
        initialFrame = frame // 记录初始 frame
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        contentView = UIView(frame: bounds)
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 10
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(contentView)
        
        sliceContainer = UIView()
        sliceContainer.translatesAutoresizingMaskIntoConstraints = false
        sliceContainer.backgroundColor = .gray
        contentView.addSubview(sliceContainer)
        sliceContainer.addSubview(collectionView)

        let grabberView = UIView()
        grabberView.backgroundColor = .lightGray
        grabberView.layer.cornerRadius = 3
        grabberView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(grabberView)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .black
        closeButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            sliceContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            sliceContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            sliceContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            sliceContainer.heightAnchor.constraint(equalToConstant: 60),
            
            collectionView.topAnchor.constraint(equalTo: sliceContainer.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: sliceContainer.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: sliceContainer.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: sliceContainer.bottomAnchor),
            
            grabberView.widthAnchor.constraint(equalToConstant: 60),
            grabberView.heightAnchor.constraint(equalToConstant: 6),
            grabberView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            grabberView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            closeButton.centerYAnchor.constraint(equalTo: sliceContainer.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20)
        ])

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        contentView.addGestureRecognizer(panGestureRecognizer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = bounds
    }

    @objc private func dismissSheet() {
        UIView.animate(withDuration: 0.3) {
            self.superview?.transform = .identity
            self.superview?.backgroundColor = .clear
            self.frame = self.initialFrame  // 归位
        } completion: { _ in
            self.dismissBlock?()
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)

        switch gesture.state {
        case .changed:
            let newHeight = frame.height - translation.y
            let clampedHeight = max(minHeight, min(newHeight, maxHeight)) // 限制高度范围
            frame.origin.y = UIScreen.main.bounds.height - clampedHeight
            frame.size.height = clampedHeight
            contentView.frame = bounds
            
            // 计算背景偏移量，确保 `superview` 的子视图平移不会累积误差
            let progress = (clampedHeight - minHeight) / (maxHeight - minHeight)
            let backgroundOffset = -maxYOffset * progress
            superview?.subviews.forEach { subview in
                if subview != self {
                    subview.transform = CGAffineTransform(translationX: 0, y: backgroundOffset)
                }
            }

            gesture.setTranslation(.zero, in: self)

        case .ended:
            let targetHeight: CGFloat = velocity.y > 0 ? minHeight : maxHeight
            
            UIView.animate(withDuration: 0.3) {
                self.frame.origin.y = UIScreen.main.bounds.height - targetHeight
                self.frame.size.height = targetHeight
                self.contentView.frame = self.bounds
                
                // 计算最终背景偏移量
                let progress = (targetHeight - self.minHeight) / (self.maxHeight - self.minHeight)
                let backgroundOffset = -self.maxYOffset * progress
                self.superview?.subviews.forEach { subview in
                    if subview != self {
                        subview.transform = CGAffineTransform(translationX: 0, y: backgroundOffset)
                    }
                }
            }
        default:
            break
        }
    }
}

extension CustomHeightView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // 返回 item 的数量
        return dataList.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CustomHeightViewCell.cellIdentifier, for: indexPath) as! CustomHeightViewCell
        cell.imageView.image = dataList[indexPath.item]
        if indexPath.item == selectedIndex {
            cell.imageView.layer.borderColor = UIColor.red.cgColor
            cell.imageView.layer.borderWidth = 2.0
        } else {
            cell.imageView.layer.borderColor = UIColor.clear.cgColor
            cell.imageView.layer.borderWidth = 0.0
        }
        return cell
    }

    // UICollectionViewDelegate 方法
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // 处理 item 点击事件
        selectBlock?(indexPath.item)
        selectedIndex = indexPath.item
    }
}

class CustomHeightViewCell: UICollectionViewCell {
    static let cellIdentifier = "CustomHeightViewCell"
    
    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
