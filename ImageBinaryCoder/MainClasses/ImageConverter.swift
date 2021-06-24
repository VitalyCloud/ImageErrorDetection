
import Cocoa

class ImageConverter: NSObject {

    func pixelValues(fromCGImage imageRef: CGImage?) -> (pixelValues: [UInt8]?, width: Int, height: Int) {
        var width = 0
        var height = 0
        var pixelValues: [UInt8]?
        if let imageRef = imageRef {
            width = imageRef.width
            height = imageRef.height
            let bitsPerComponent = imageRef.bitsPerComponent
            let bytesPerRow = imageRef.bytesPerRow
            let totalBytes = height * bytesPerRow
            
            let colorSpace = CGColorSpaceCreateDeviceGray()
            var intensities = [UInt8](repeating: 0, count: totalBytes)
            
            let contextRef = CGContext(data: &intensities, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: 0)
            contextRef?.draw(imageRef, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(width), height: CGFloat(height)))
            
            pixelValues = intensities
        }
        
        return (pixelValues, width, height)
    }
    
    func imageFromPixelValues(pixelValues: [UInt8], width: Int, height: Int) -> CGImage? {
        let numComponents = 1
        let numBytes = height * width * numComponents
        let colorspace = CGColorSpaceCreateDeviceGray()
        let rgbData = CFDataCreate(nil, pixelValues, numBytes)!
        let provider = CGDataProvider(data: rgbData)!
        let rgbImageRef = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 8 * numComponents,
                                  bytesPerRow: width * numComponents,
                                  space: colorspace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue).union(CGBitmapInfo()),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: CGColorRenderingIntent.defaultIntent)!
        
        return rgbImageRef
    }
    
    func imageRGBA(fromPixelValues pixelValues: [UInt8], width: Int, height: Int) -> CGImage? {
        let numComponents = 4
        let numBytes = height * width * numComponents
        let colorspace = CGColorSpaceCreateDeviceRGB()
        let rgbData = CFDataCreate(nil, pixelValues, numBytes)!
        let provider = CGDataProvider(data: rgbData)!
        let rgbImageRef = CGImage(width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 8 * numComponents,
                                  bytesPerRow: width * numComponents,
                                  space: colorspace,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue).union(CGBitmapInfo()),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: true,
                                  intent: CGColorRenderingIntent.defaultIntent)!

        return rgbImageRef
    }
    
    func convertToGrayScale(image: CGImage) -> CGImage {
        let height = image.height
        let width = image.width
        let colorSpace = CGColorSpaceCreateDeviceGray();
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let context = CGContext.init(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: image.width, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: rect)
        return context.makeImage()!
    }
}

