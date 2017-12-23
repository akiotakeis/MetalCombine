//
//  ATMetal.metal
//  MetalCombine
//
//  Created by Akio Takei on 2017/12/23.
//

import Foundation
import Metal
import MetalKit

class ATMetal {
    
    public static var shared = ATMetal()
    
    public var metalLibPath: String!
    public var bundle: Bundle!
    
    let bytesPerPixel: Int = 4
    
    let queue = DispatchQueue(label: "com.metal.queue")
    
    var device: MTLDevice!
    var defaultLibrary: MTLLibrary!
    lazy var commandQueue: MTLCommandQueue! = {
        return self.device.makeCommandQueue()
    }()
    
    var outTexture: MTLTexture!
    
    var pipelineState: MTLComputePipelineState!
    
    let threadGroupCount = MTLSizeMake(16, 16, 1)
    
    init() {
        
    }
    
    public func setup(with libPath: String) {
        
        metalLibPath = libPath
        device = MTLCreateSystemDefaultDevice()
        defaultLibrary = try? self.device.makeLibrary(filepath: metalLibPath)
        queue.async {
            self.setUpMetal(name: "combineHorizontal")
        }
    }
    
    private func setUpMetal(name: String) {
        
        if let kernelFunction = defaultLibrary.makeFunction(name: name) {
            do {
                pipelineState = try device.makeComputePipelineState(function: kernelFunction)
            }
            catch {
                fatalError("Impossible to setup Metal")
            }
        }
    }
    
    private func getImageFromTexture(_ texture: MTLTexture?) -> UIImage? {
        
        guard let texture = texture else {
            return nil
        }
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        let bytesPerRow = texture.width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        
        let bitmapInfo = CGBitmapInfo(rawValue:
            (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let context = CGContext(data: &src,
                                width: texture.width,
                                height: texture.height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        let dstImageFilter = context?.makeImage()
        
        return UIImage(cgImage: dstImageFilter!, scale: 0.0, orientation: UIImageOrientation.up)
    }
    
    private func applyCombine(inTextures: [MTLTexture], width: Int, height: Int) -> MTLTexture? {
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        guard let outTexture = self.device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(outTexture, index: 0)
        commandEncoder.setTextures(inTextures, range: Range<Int>(1...inTextures.count))
        
        var pixelSize = inTextures[0].width
        let buffer = device.makeBuffer(bytes: &pixelSize, length: MemoryLayout<UInt>.size,
                                       options: MTLResourceOptions.storageModeShared)
        commandEncoder.setBuffer(buffer, offset: 0, index: 0)
        
        let threadGroups = MTLSizeMake(
            Int(outTexture.width) / self.threadGroupCount.width,
            Int(outTexture.height) / self.threadGroupCount.height, 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return outTexture
    }
    
    internal func combineImages(_ cgImages: [CGImage], _ completion: @escaping (UIImage?) -> Void) {
        
        queue.async {
            let textureLoader = MTKTextureLoader(device: self.device)
            var inTextures = [MTLTexture]()
            for cgImage in cgImages {
                do {
                    inTextures.append(try textureLoader.newTexture(cgImage: cgImage, options: nil))
                } catch {
                    break
                }
            }
            if inTextures.count < 10 {
                completion(nil)
                return
            }
            
            self.setUpMetal(name: "combineHorizontal")
            var horizontalOutTextures = [MTLTexture]()
            
            let width = inTextures[0].width * 10
            var height = inTextures[0].height
            for i in 0..<(inTextures.count / 10) {
                var textures = [MTLTexture]()
                for j in 0..<10 {
                    textures.append(inTextures[10 * i + j])
                }
                if let outTexture = self.applyCombine(inTextures: textures, width: width, height: height) {
                    horizontalOutTextures.append(outTexture)
                }
            }
            
            var outTexture: MTLTexture?
            if horizontalOutTextures.count == 1 {
                outTexture = horizontalOutTextures[0]
            } else {
                height = inTextures[0].height * (inTextures.count / 10)
                self.setUpMetal(name: "combineVertical")
                outTexture = self.applyCombine(inTextures: horizontalOutTextures, width: width, height: height)
            }
            
            let resultImage = self.getImageFromTexture(outTexture)
            DispatchQueue.main.async {
                completion(resultImage)
            }
        }
    }
}
