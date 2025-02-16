//
//  VC_Result.swift
//  PicSearch
//
//  Created by chaostong on 2025/2/15.
//

import UIKit

class VC_Result: UIViewController {
    
    let iv = UIImageView()
    var originImage: UIImage?
    var image: UIImage? {
        didSet {
            iv.image = image
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        iv.contentMode = .scaleAspectFit
        view.addSubview(iv)
        iv.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            iv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            iv.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
}
