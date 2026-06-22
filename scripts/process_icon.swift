import Foundation
import Cocoa
import CoreGraphics

func processIcon(inputPath: String, outputDir: String) {
    let fileURL = URL(fileURLWithPath: inputPath)
    guard let image = NSImage(contentsOf: fileURL),
          let tiffData = image.tiffRepresentation,
          let imageRep = NSBitmapImageRep(data: tiffData),
          let cgImage = imageRep.cgImage else {
        print("Error: Could not load image from \(inputPath)")
        exit(1)
    }
    
    let width = cgImage.width
    let height = cgImage.height
    print("Loaded image: \(width)x\(height)")
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8
    
    var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
    
    guard let context = CGContext(
        data: &rawData,
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    ) else {
        print("Error: Could not create CGContext")
        exit(1)
    }
    
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    // Flood fill to find outer white background
    var visited = [Bool](repeating: false, count: width * height)
    var queue = [(Int, Int)]()
    
    // Helper to check if pixel is white-ish
    func isWhite(x: Int, y: Int) -> Bool {
        let offset = (y * width + x) * bytesPerPixel
        let r = rawData[offset]
        let g = rawData[offset + 1]
        let b = rawData[offset + 2]
        let a = rawData[offset + 3]
        
        // If it's already transparent, it's fine
        if a == 0 { return true }
        
        // Pure or near pure white
        return r > 245 && g > 245 && b > 245
    }
    
    // Add corners
    let corners = [
        (0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)
    ]
    
    for corner in corners {
        if isWhite(x: corner.0, y: corner.1) {
            queue.append(corner)
            visited[corner.1 * width + corner.0] = true
        }
    }
    
    var head = 0
    while head < queue.count {
        let (cx, cy) = queue[head]
        head += 1
        
        // Make this pixel fully transparent
        let offset = (cy * width + cx) * bytesPerPixel
        rawData[offset] = 0     // R
        rawData[offset + 1] = 0 // G
        rawData[offset + 2] = 0 // B
        rawData[offset + 3] = 0 // A
        
        // Check 4-neighbors
        let neighbors = [
            (cx + 1, cy),
            (cx - 1, cy),
            (cx, cy + 1),
            (cx, cy - 1)
        ]
        
        for (nx, ny) in neighbors {
            if nx >= 0 && nx < width && ny >= 0 && ny < height {
                let idx = ny * width + nx
                if !visited[idx] && isWhite(x: nx, y: ny) {
                    visited[idx] = true
                    queue.append((nx, ny))
                }
            }
        }
    }
    
    // Create new CGImage from modified rawData
    guard let newProvider = CGDataProvider(data: Data(rawData) as CFData),
          let transparentCgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerComponent * bytesPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: newProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          ) else {
        print("Error: Could not create new CGImage")
        exit(1)
    }
    
    // Save various sizes to outputDir
    let fm = FileManager.default
    try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true, attributes: nil)
    
    let sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024)
    ]
    
    for (filename, targetSize) in sizes {
        let destPath = (outputDir as NSString).appendingPathComponent(filename)
        
        // Resize using CGContext
        let targetRect = CGRect(x: 0, y: 0, width: targetSize, height: targetSize)
        guard let resizeContext = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: 4 * targetSize,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            print("Error: Could not create context to resize to \(targetSize)")
            continue
        }
        
        resizeContext.interpolationQuality = .high
        resizeContext.draw(transparentCgImage, in: targetRect)
        
        guard let resizedCgImage = resizeContext.makeImage() else {
            print("Error: Could not extract resized image of size \(targetSize)")
            continue
        }
        
        let newRep = NSBitmapImageRep(cgImage: resizedCgImage)
        guard let pngData = newRep.representation(using: .png, properties: [:]) else {
            print("Error: Could not convert to PNG data for size \(targetSize)")
            continue
        }
        
        do {
            try pngData.write(to: URL(fileURLWithPath: destPath))
            print("Saved: \(filename) (\(targetSize)x\(targetSize))")
        } catch {
            print("Error: Could not write file to \(destPath): \(error)")
        }
    }
}

// Parse args
let args = CommandLine.arguments
if args.count < 3 {
    print("Usage: swift process_icon.swift <input_path> <output_dir>")
    exit(1)
}

processIcon(inputPath: args[1], outputDir: args[2])
