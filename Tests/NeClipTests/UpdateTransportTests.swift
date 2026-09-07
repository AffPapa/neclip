import Foundation
import XCTest
@testable import NeClip

private class UpdateResponseStub: URLProtocol {
    var headers: [String: String] { ["Content-Type": "application/json"] }
    var body: Data {
        Data("""
        {"version":"1.10.0","build":17,"release":"https://github.com/AffPapa/neclip/releases/download/v1.10.0/NeClip-1.10.0.dmg","sha256":"\(String(repeating: "a", count: 64))"}
        """.utf8)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class OversizedUpdateStub: UpdateResponseStub {
    override var body: Data { Data(repeating: 32, count: UpdateManifestPolicy.maximumResponseBytes + 1) }
}

private final class LargeDeclaredUpdateStub: UpdateResponseStub {
    override var headers: [String: String] {
        ["Content-Type": "application/json", "Content-Length": "999999999"]
    }
}

private final class WrongMIMEUpdateStub: UpdateResponseStub {
    override var headers: [String: String] { ["Content-Type": "text/html"] }
}

final class UpdateTransportTests: XCTestCase {
    private func configuration(_ stub: URLProtocol.Type) -> URLSessionConfiguration {
        let configuration = UpdateTransport.configuration()
        configuration.protocolClasses = [stub]
        return configuration
    }

    func testTransportDoesNotPersistCookiesOrURLCache() {
        let configuration = UpdateTransport.configuration()
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 15)
    }

    func testStreamAcceptsValidManifestWithoutExternalNetwork() async throws {
        let manifest = try await UpdateTransport.fetch(configuration: configuration(UpdateResponseStub.self))
        XCTAssertEqual(manifest.version, "1.10.0")
        XCTAssertEqual(manifest.build, 17)
    }

    func testStreamRejectsOversizedBodyEvenWithoutLengthHeader() async {
        do {
            _ = try await UpdateTransport.fetch(configuration: configuration(OversizedUpdateStub.self))
            XCTFail("Expected bounded-stream rejection")
        } catch { XCTAssertEqual(error as? UpdateCheckError, .oversizedResponse) }
    }

    func testStreamRejectsOversizedDeclaredLengthAndWrongMIME() async {
        for (stub, expected) in [(LargeDeclaredUpdateStub.self as URLProtocol.Type, UpdateCheckError.oversizedResponse),
                                  (WrongMIMEUpdateStub.self as URLProtocol.Type, .invalidResponse)] {
            do {
                _ = try await UpdateTransport.fetch(configuration: configuration(stub))
                XCTFail("Expected response rejection")
            } catch { XCTAssertEqual(error as? UpdateCheckError, expected) }
        }
    }

    func testRedirectIsRejectedBeforeSendingFollowUpRequest() async throws {
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: UpdateManifestPolicy.manifestURL)
        let response = try XCTUnwrap(HTTPURLResponse(url: UpdateManifestPolicy.manifestURL,
                                                    statusCode: 302, httpVersion: "HTTP/1.1", headerFields: nil))
        let result: URLRequest? = await withCheckedContinuation { continuation in
            UpdateRedirectPolicy().urlSession(session, task: task, willPerformHTTPRedirection: response,
                                             newRequest: URLRequest(url: URL(string: "https://example.com/redirect")!)) {
                continuation.resume(returning: $0)
            }
        }
        XCTAssertNil(result)
        XCTAssertEqual(task.state, .suspended, "The test never starts a real request")
    }
}
