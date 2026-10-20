// Import the correct Flutter module and UI framework for each platform
#if os(iOS)
  import Flutter
  import UIKit
#elseif os(macOS)
  import FlutterMacOS
  import Cocoa
#endif

public class NativeHdrImageViewPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    // The registrar's `messenger` is a method on iOS and a property on macOS.
    // Use a compile-time condition to handle this difference.
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "native_hdr_image_view", binaryMessenger: messenger)
    let instance = NativeHdrImageViewPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.register(
      NativeHdrImageViewFactory(messenger: messenger),
      withId: "native_hdr_image_view"
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasHdrSupport":
      result(nativeHdrSupportAvailable())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

func nativeHdrSupportAvailable() -> Bool {
  #if os(iOS)
    if #available(iOS 17.0, *) { return true }
  #elseif os(macOS)
    if #available(macOS 14.0, *) { return true }
  #endif
  return false
}
