//
//  MetalCombine.swift
//  MetalCombine
//
//  Created by Akio Takei on 2017/12/23.
//

import Foundation
import MobileCoreServices
import UIKit
import AVKit
import Metal

public class MetalCombine: NSObject {
    
    public static var shared = MetalCombine()
    
    let metal = ATMetal.shared
    var completion: ((UIImage?, Double?) -> Void)?
    
    public override init() {
        super.init()
        
        metal.setup(with: getAssetPath(name: "ATKernels", ofType: "metallib") ?? "")
    }
    
    public func combineVideoFrames(viewController: UIViewController,  completion: @escaping (UIImage?, Double?) -> Void) {
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            return
        }
        
        self.completion = completion
        
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [kUTTypeMovie as String]
        picker.delegate = self
        picker.allowsEditing = true
        picker.videoMaximumDuration = 5
        picker.videoQuality = .typeMedium
        viewController.present(picker, animated: true)
    }
    
    fileprivate func combineManyFrames(_ url: URL) {
        
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            var cgImages = [CGImage]()
            for i in 0..<Int(asset.duration.seconds * 60) {
                let time = CMTimeMake(Int64(i), 60)
                guard let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) else {
                    break
                }
                cgImages.append(cgImage)
            }
            let startTime = Date()
            self.metal.combineImages(cgImages, { (combinedImage) in
                let duration = Date().timeIntervalSince1970 - startTime.timeIntervalSince1970
                self.completion?(combinedImage, duration)
            })
        }
    }
    
    private func getAssetPath(name: String, ofType type: String) -> String? {
        
        let podBundle = Bundle(for: self.classForCoder)
        if let bundleURL = podBundle.url(forResource: "MetalCombine", withExtension: "bundle") {
            if let bundle = Bundle(url: bundleURL) {
                return bundle.path(forResource: name, ofType: type)
            }
        }
        return nil
    }
}

extension MetalCombine: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        let mediaType = info[UIImagePickerControllerMediaType] as! String
        if mediaType == kUTTypeMovie as String, let url = info[UIImagePickerControllerMediaURL] as? URL {
            combineManyFrames(url)
        }
        picker.dismiss(animated: true)
    }
}
