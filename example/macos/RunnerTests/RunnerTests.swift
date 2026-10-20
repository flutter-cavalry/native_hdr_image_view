import Cocoa
import FlutterMacOS
import XCTest

// If your plugin has been explicitly set to "type: .dynamic" in the Package.swift,
// you will need to add your plugin as a dependency of RunnerTests within Xcode.

@testable import native_hdr_image_view

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testHasHdrSupport() {
    let plugin = NativeHdrImageViewPlugin()

    let call = FlutterMethodCall(methodName: "hasHdrSupport", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      if #available(macOS 14.0, *) {
        XCTAssertEqual(result as? Bool, true)
      } else {
        XCTAssertEqual(result as? Bool, false)
      }
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
