import Foundation
import Vision
import AppKit

func printHelp() {
    print("""
    Usage:
      macos-comic-ocr [options]
    
    Options:
      -f, --file <file>         Specify a single image file to process
      -d, --directory <dir>     Specify a directory containing images to process
      -r, --recursive           Recursively process images in the specified directory and subdirectories
      -n, --rows <num>          Specify the number of horizontal rows to split the images into (default: auto-detect based on aspect ratio)
      -h, --help                Display this help message
    """)
}

func recognizeTextWithSentenceEndings(from imagePath: String, rows: Int?) -> String {
    guard let image = NSImage(contentsOfFile: imagePath) else {
        print("Image could not be loaded: \(imagePath)")
        return ""
    }
    
    guard let tiffData = image.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        print("Failed to extract TIFF representation for: \(imagePath)")
        return ""
    }
    
    // Determine image width and height for aspect ratio
    let imageWidth = ciImage.extent.width
    let imageHeight = ciImage.extent.height

    // Define ROIs based on specified rows or aspect ratio
    var regionsOfInterest: [CGRect] = []
    if let rows = rows, rows > 1 {
        // Split the image into the specified number of rows, ensuring top-to-bottom order
        let rowHeight = 1.0 / CGFloat(rows)
        for i in 0..<rows {
            let yPosition = 1.0 - rowHeight * CGFloat(i + 1) // Start from the top row
            let region = CGRect(x: 0, y: yPosition, width: 1.0, height: rowHeight)
            regionsOfInterest.append(region)
        }
    } else {
        // Use aspect ratio to decide on 1 or 2 rows
        let aspectRatio = imageWidth / imageHeight
        if aspectRatio < 2.5 { // For images with ratio close to 2.25 (split horizontally)
            let topHalf = CGRect(x: 0, y: 0.5, width: 1.0, height: 0.5)
            let bottomHalf = CGRect(x: 0, y: 0, width: 1.0, height: 0.5)
            regionsOfInterest = [topHalf, bottomHalf]
        } else { // For images with ratio closer to 3.2 (process left-to-right as a single block)
            let fullImage = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
            regionsOfInterest = [fullImage]
        }
    }

    var recognizedText = ""

    // Process each region of interest
    for roi in regionsOfInterest {
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("Text recognition failed: \(error)")
                return
            }
            
            for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
                let boxWidth = observation.boundingBox.width
                let boxHeight = observation.boundingBox.height
                
                if boxWidth >= boxHeight * 0.4 || (boxWidth > 0.1 && boxHeight > 0.1) {
                    if let topCandidate = observation.topCandidates(1).first {
                        recognizedText += topCandidate.string
                        
                        // Add a newline if the line ends with ., ?, or !
                        if topCandidate.string.hasSuffix(".") || topCandidate.string.hasSuffix("?") || topCandidate.string.hasSuffix("!") {
                            recognizedText += "\n"
                        }
                        
                        recognizedText += "\n"
                    }
                }
            }
        }
        
        request.regionOfInterest = roi

        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform text recognition request: \(error)")
        }
    }

    return recognizedText
}

func processFile(at filePath: String, rows: Int?) {
    let recognizedText = recognizeTextWithSentenceEndings(from: filePath, rows: rows)
    let outputFilePath = (filePath as NSString).deletingPathExtension + ".txt"
    do {
        try recognizedText.write(toFile: outputFilePath, atomically: true, encoding: .utf8)
        print("Text recognition completed. Output saved to \(outputFilePath)")
    } catch {
        print("Failed to write output file for \(filePath): \(error)")
    }
}

func processDirectory(at directoryPath: String, rows: Int?, recursive: Bool) {
    let fileManager = FileManager.default

    if recursive {
        // Process files recursively
        let enumerator = fileManager.enumerator(atPath: directoryPath)
        while let element = enumerator?.nextObject() as? String {
            let filePath = (directoryPath as NSString).appendingPathComponent(element)
            do {
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if attributes[.type] as? FileAttributeType == .typeRegular &&
                    (filePath.lowercased().hasSuffix(".jpg") || filePath.lowercased().hasSuffix(".jpeg") ||
                     filePath.lowercased().hasSuffix(".png") || filePath.lowercased().hasSuffix(".gif")) {
                    
                    print("Processing \(filePath)...")
                    processFile(at: filePath, rows: rows)
                }
            } catch {
                print("Failed to get attributes for \(filePath): \(error)")
            }
        }
    } else {
        // Process files only in the top-level directory
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
            for element in contents {
                let filePath = (directoryPath as NSString).appendingPathComponent(element)
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if attributes[.type] as? FileAttributeType == .typeRegular &&
                    (filePath.lowercased().hasSuffix(".jpg") || filePath.lowercased().hasSuffix(".jpeg") ||
                     filePath.lowercased().hasSuffix(".png") || filePath.lowercased().hasSuffix(".gif")) {
                    
                    print("Processing \(filePath)...")
                    processFile(at: filePath, rows: rows)
                }
            }
        } catch {
            print("Failed to list contents of directory \(directoryPath): \(error)")
        }
    }
}

// Main Command-line Argument Parsing
var filePath: String? = nil
var directoryPath: String? = nil
var recursive = false
var rows: Int? = nil

let args = CommandLine.arguments

if args.contains("-h") || args.contains("--help") || args.count == 1 {
    printHelp()
    exit(0)
}

var index = 1
while index < args.count {
    switch args[index] {
    case "-f", "--file":
        index += 1
        filePath = args[index]
    case "-d", "--directory":
        index += 1
        directoryPath = args[index]
    case "-r", "--recursive":
        recursive = true
    case "-n", "--rows":
        index += 1
        rows = Int(args[index]) ?? nil
    default:
        print("Unknown argument: \(args[index])")
        printHelp()
        exit(1)
    }
    index += 1
}

if let file = filePath {
    processFile(at: file, rows: rows)
} else if let directory = directoryPath {
    processDirectory(at: directory, rows: rows, recursive: recursive)
} else {
    printHelp()
}
