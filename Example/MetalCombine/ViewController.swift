//
//  ViewController.swift
//  MetalCombine
//
//  Created by akiotakeis on 12/23/2017.
//  Copyright (c) 2017 akiotakeis. All rights reserved.
//

import UIKit
import MetalCombine

class ViewController: UIViewController {

    @IBOutlet weak var combinedIv: UIImageView!
    @IBOutlet weak var imageSizeLb: UILabel!
    
    @IBAction func onVideoButtonPressed(_ sender: Any) {
        
        self.combinedIv.image = nil
        self.imageSizeLb.text = ""
        
        MetalCombine.shared.combineVideoFrames(viewController: self) { (combinedImage, duration) in
            if let image = combinedImage, let duration = duration {
                self.imageSizeLb.text = "\(image.size) : \(duration)"
                self.combinedIv.image = image
            }
        }
    }
}
