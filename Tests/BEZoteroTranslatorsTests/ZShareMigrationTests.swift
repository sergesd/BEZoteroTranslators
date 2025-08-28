//
//  ZShareMigrationTests.swift
//  BEZoteroTranslatorsTests
//
//  Created based on ZShare migration
//

import XCTest
import RxSwift
import RxTest
import RxBlocking
@testable import BEZoteroTranslators

final class ZShareMigrationTests: XCTestCase {
    
    var disposeBag: DisposeBag!
    var scheduler: TestScheduler!
    
    override func setUp() {
        super.setUp()
        disposeBag = DisposeBag()
        scheduler = TestScheduler(initialClock: 0)
    }
    
    override func tearDown() {
        disposeBag = nil
        scheduler = nil
        super.tearDown()
    }
    
    // MARK: - RawAttachment Tests
    
    func testRawAttachmentRemoteFileUrl() {
        let url = URL(string: "https://example.com/document.pdf")!
        let attachment = RawAttachment.remoteFileUrl(
            url: url,
            contentType: "application/pdf",
            cookies: "session=123",
            userAgent: "TestAgent",
            referrer: "https://example.com"
        )
        
        XCTAssertEqual(attachment.url, url)
        XCTAssertEqual(attachment.cookies, "session=123")
        XCTAssertEqual(attachment.userAgent, "TestAgent")
        XCTAssertEqual(attachment.referrer, "https://example.com")
        XCTAssertTrue(attachment.isDirectFile)
        XCTAssertEqual(attachment.contentType, "application/pdf")
        XCTAssertNil(attachment.title)
        XCTAssertNil(attachment.html)
        XCTAssertNil(attachment.frames)
    }
    
    func testRawAttachmentWeb() {
        let url = URL(string: "https://example.com/article")!
        let attachment = RawAttachment.web(
            title: "Test Article",
            url: url,
            html: "<html><body>Test</body></html>",
            cookies: "session=123",
            frames: ["<frame>content</frame>"],
            userAgent: "TestAgent",
            referrer: "https://example.com"
        )
        
        XCTAssertEqual(attachment.url, url)
        XCTAssertEqual(attachment.cookies, "session=123")
        XCTAssertEqual(attachment.userAgent, "TestAgent")
        XCTAssertEqual(attachment.referrer, "https://example.com")
        XCTAssertFalse(attachment.isDirectFile)
        XCTAssertNil(attachment.contentType)
        XCTAssertEqual(attachment.title, "Test Article")
        XCTAssertEqual(attachment.html, "<html><body>Test</body></html>")
        XCTAssertEqual(attachment.frames, ["<frame>content</frame>"])
    }
    
    // MARK: - AttachmentState Tests
    
    func testAttachmentStateProperties() {
        // Test decoding state
        let decodingState = AttachmentState.decoding
        XCTAssertFalse(decodingState.isCompleted)
        XCTAssertFalse(decodingState.isFailed)
        XCTAssertFalse(decodingState.isInProgress)
        XCTAssertNil(decodingState.progress)
        XCTAssertNil(decodingState.progressMessage)
        XCTAssertNil(decodingState.error)
        
        // Test translating state
        let translatingState = AttachmentState.translating("Processing...")
        XCTAssertFalse(translatingState.isCompleted)
        XCTAssertFalse(translatingState.isFailed)
        XCTAssertTrue(translatingState.isInProgress)
        XCTAssertNil(translatingState.progress)
        XCTAssertEqual(translatingState.progressMessage, "Processing...")
        XCTAssertNil(translatingState.error)
        
        // Test downloading state
        let downloadingState = AttachmentState.downloading(progress: 0.5)
        XCTAssertFalse(downloadingState.isCompleted)
        XCTAssertFalse(downloadingState.isFailed)
        XCTAssertTrue(downloadingState.isInProgress)
        XCTAssertEqual(downloadingState.progress, 0.5)
        XCTAssertNil(downloadingState.progressMessage)
        XCTAssertNil(downloadingState.error)
        
        // Test done state
        let doneState = AttachmentState.done
        XCTAssertTrue(doneState.isCompleted)
        XCTAssertFalse(doneState.isFailed)
        XCTAssertFalse(doneState.isInProgress)
        XCTAssertNil(doneState.progress)
        XCTAssertNil(doneState.progressMessage)
        XCTAssertNil(doneState.error)
        
        // Test failed state
        let testError = NSError(domain: "Test", code: 1, userInfo: nil)
        let failedState = AttachmentState.failed(testError)
        XCTAssertTrue(failedState.isCompleted)
        XCTAssertTrue(failedState.isFailed)
        XCTAssertFalse(failedState.isInProgress)
        XCTAssertNil(failedState.progress)
        XCTAssertNil(failedState.progressMessage)
        XCTAssertEqual(failedState.error as? NSError, testError)
    }
    
    func testAttachmentStateEquatable() {
        let state1 = AttachmentState.decoding
        let state2 = AttachmentState.decoding
        let state3 = AttachmentState.translating("Test")
        let state4 = AttachmentState.translating("Test")
        let state5 = AttachmentState.translating("Different")
        
        XCTAssertEqual(state1, state2)
        XCTAssertEqual(state3, state4)
        XCTAssertNotEqual(state3, state5)
        XCTAssertNotEqual(state1, state3)
    }
    
    // MARK: - AttachmentDownloader Tests
    
    func testAttachmentDownloaderInitialization() {
        let downloader = AttachmentDownloader()
        XCTAssertNotNil(downloader)
    }
    
    func testAttachmentDownloaderContentTypeExtensions() {
        let downloader = AttachmentDownloader()
        
        // Test private method through reflection or make it internal for testing
        // For now, we'll test the downloader creation
        XCTAssertNotNil(AttachmentDownloader())
    }
    
    // MARK: - DownloadResult Tests
    
    func testDownloadResultSuccess() {
        let url = URL(string: "file:///tmp/test.pdf")!
        let originalURL = URL(string: "https://example.com/test.pdf")!
        
        let success = DownloadResult.Success(
            fileURL: url,
            contentType: "application/pdf",
            fileSize: 1024,
            originalURL: originalURL
        )
        
        XCTAssertEqual(success.fileURL, url)
        XCTAssertEqual(success.contentType, "application/pdf")
        XCTAssertEqual(success.fileSize, 1024)
        XCTAssertEqual(success.originalURL, originalURL)
    }
    
    func testDownloadResultEnum() {
        let url = URL(string: "file:///tmp/test.pdf")!
        let originalURL = URL(string: "https://example.com/test.pdf")!
        
        let success = DownloadResult.Success(
            fileURL: url,
            contentType: "application/pdf",
            fileSize: 1024,
            originalURL: originalURL
        )
        
        let completedResult = DownloadResult.completed(success)
        let failedResult = DownloadResult.failed(NSError(domain: "Test", code: 1, userInfo: nil))
        
        switch completedResult {
        case .completed(let result):
            XCTAssertEqual(result.fileURL, url)
            XCTAssertEqual(result.contentType, "application/pdf")
        case .failed:
            XCTFail("Expected completed result")
        }
        
        switch failedResult {
        case .completed:
            XCTFail("Expected failed result")
        case .failed(let error):
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - DownloadProgress Tests
    
    func testDownloadProgress() {
        let progressState = DownloadProgress.progress(percentage: 0.5)
        let url = URL(string: "file:///tmp/test.pdf")!
        let originalURL = URL(string: "https://example.com/test.pdf")!
        
        let success = DownloadResult.Success(
            fileURL: url,
            contentType: "application/pdf",
            fileSize: 1024,
            originalURL: originalURL
        )
        
        let completedState = DownloadProgress.completed(success)
        let failedState = DownloadProgress.failed(NSError(domain: "Test", code: 1, userInfo: nil))
        
        switch progressState {
        case .progress(let percentage):
            XCTAssertEqual(percentage, 0.5)
        case .completed, .failed:
            XCTFail("Expected progress state")
        }
        
        switch completedState {
        case .progress:
            XCTFail("Expected completed state")
        case .completed(let result):
            XCTAssertEqual(result.fileURL, url)
        case .failed:
            XCTFail("Expected completed state")
        }
        
        switch failedState {
        case .progress, .completed:
            XCTFail("Expected failed state")
        case .failed(let error):
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - AttachmentDownloaderError Tests
    
    func testAttachmentDownloaderError() {
        let invalidResponse = AttachmentDownloaderError.invalidResponse
        let httpError = AttachmentDownloaderError.httpError(404)
        let noData = AttachmentDownloaderError.noData
        let invalidContentType = AttachmentDownloaderError.invalidContentType
        let fileWriteFailed = AttachmentDownloaderError.fileWriteFailed
        
        XCTAssertEqual(invalidResponse.errorDescription, "Invalid HTTP response")
        XCTAssertEqual(httpError.errorDescription, "HTTP error: 404")
        XCTAssertEqual(noData.errorDescription, "No data received")
        XCTAssertEqual(invalidContentType.errorDescription, "Invalid content type")
        XCTAssertEqual(fileWriteFailed.errorDescription, "Failed to write file")
    }
}
