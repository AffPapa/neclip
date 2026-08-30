import Foundation
import ImageIO
import Vision

extension Notification.Name {
    static let neClipOCRDidFinish = Notification.Name("org.affpapa.neclip.ocrDidFinish")
    static let neClipOCRDidFail = Notification.Name("org.affpapa.neclip.ocrDidFail")
}

enum OCRService {
    private static let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "org.affpapa.neclip.ocr"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// OCR is intentionally serialized: several large screenshots must not
    /// compete for memory. Vision and the subsequent DB write both stay off
    /// the main thread.
    static func recognize(imageData: Data, clipID: Int64) {
        queue.addOperation {
            autoreleasepool {
                guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                    notifyFailure(clipID: clipID, error: OCRFailure.invalidImage)
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
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .neClipOCRDidFinish,
                            object: nil,
                            userInfo: ["clipID": clipID]
                        )
                    }
                } catch {
                    notifyFailure(clipID: clipID, error: error)
                }
            }
        }
    }

    private static func notifyFailure(clipID: Int64, error: Error) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .neClipOCRDidFail,
                object: nil,
                userInfo: ["clipID": clipID, "error": error]
            )
        }
    }

    private enum OCRFailure: Error {
        case invalidImage
    }
}
