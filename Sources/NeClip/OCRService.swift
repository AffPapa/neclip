import Foundation
import ImageIO
import OSLog
import Vision

enum OCRService {
    private static let logger = Logger(subsystem: "org.affpapa.neclip", category: "OCR")
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "org.affpapa.neclip.ocr"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// OCR is intentionally serialized: several large screenshots must not
    /// compete for memory. Only the running job and newest pending image are
    /// retained; rapid screenshot copies still preserve every original image,
    /// while obsolete queued OCR work cannot accumulate hundreds of megabytes.
    /// Vision and the subsequent DB write both stay off the main thread.
    static func recognize(imageData: Data, clipID: Int64) {
        queue.operations
            .filter { !$0.isExecuting }
            .forEach { $0.cancel() }
        queue.addOperation {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    logger.error("OCR image decoding failed")
                    return
                }

                var recognizedText: String?
                let request = VNRecognizeTextRequest { request, error in
                    guard error == nil,
                          let observations = request.results as? [VNRecognizedTextObservation] else {
                        return
                    }
                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty { recognizedText = text }
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["ru-RU", "en-US"]
                request.usesLanguageCorrection = true

                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                    guard let recognizedText else { return }
                    try Storage.shared.setOCRText(recognizedText, forClipID: clipID)
                } catch {
                    // Never log clipboard text, source paths or raw errors.
                    logger.error("OCR recognition or storage failed")
                }
            }
        }
    }

}
