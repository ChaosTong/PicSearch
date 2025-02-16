//
//  VC_Main.swift
//  PicSearch
//
//  Created by chaostong on 2025/2/15.
//

import UIKit

class VC_Main: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        let btn = UIButton(primaryAction: UIAction.init(handler: { [weak self] _ in
            let vc = VC_OverlayPicSelect()
            vc.image = UIImage(named: "test")!
            vc.positions = [
                Position(x1: 10, x2: vc.image.size.width-20, y1: 10, y2: vc.image.size.height-20),
                Position(x1: 37, x2: 230, y1: 66, y2: 431),
                Position(x1: 223, x2: 434, y1: 72, y2: 440)
            ]
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        
        let btn2 = UIButton(primaryAction: UIAction.init(handler: { [weak self] _ in
            let vc = VC_OverlayPicSelect()
            vc.image = UIImage(named: "test2")!
            vc.positions = [
                Position(x1: 10, x2: vc.image.size.width-20, y1: 10, y2: vc.image.size.height-20)
            ]
            self?.navigationController?.pushViewController(vc, animated: true)
        }))
        
        view.addSubview(btn)
        btn.setTitle("normal pic", for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(btn2)
        btn2.setTitle("long pic", for: .normal)
        btn2.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        NSLayoutConstraint.activate([
            btn2.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn2.topAnchor.constraint(equalTo: btn.bottomAnchor)
        ])
    }
}

