#if os(iOS)
  import Flutter
  import UIKit
  private typealias ImageContainer = UIView
  private typealias PlatformImage = UIImage
  private typealias PlatformImageView = UIImageView
#elseif os(macOS)
  import FlutterMacOS
  import Cocoa
  private typealias ImageContainer = NSView
  private typealias PlatformImage = NSImage
  private typealias PlatformImageView = NSImageView
#endif

final class NativeHdrImageViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  #if os(iOS)
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
      FlutterStandardMessageCodec.sharedInstance()
    }
  #elseif os(macOS)
    func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
      FlutterStandardMessageCodec.sharedInstance()
    }
  #endif

  #if os(iOS)
    func create(
      withFrame frame: CGRect,
      viewIdentifier viewId: Int64,
      arguments args: Any?
    ) -> FlutterPlatformView {
      NativeHdrPlatformView(
        container: NativeHdrImageContainer(
          frame: frame, viewId: viewId, arguments: args, messenger: messenger
        ))
    }
  #elseif os(macOS)
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
      NativeHdrImageContainer(
        frame: .zero, viewId: viewId, arguments: args, messenger: messenger
      )
    }
  #endif
}

#if os(iOS)
  private final class NativeHdrPlatformView: NSObject, FlutterPlatformView {
    private let container: NativeHdrImageContainer

    init(container: NativeHdrImageContainer) {
      self.container = container
      super.init()
    }

    func view() -> UIView { container }
  }
#endif

private final class NativeHdrImageContainer: ImageContainer {
  private let imageView = PlatformImageView()
  private let channel: FlutterMethodChannel
  private var fit = "contain"
  private var imagePath: String?

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    channel = FlutterMethodChannel(
      name: "native_hdr_image_view/\(viewId)", binaryMessenger: messenger
    )
    super.init(frame: frame)

    #if os(iOS)
      clipsToBounds = true
      imageView.contentMode = .scaleToFill
      imageView.preferredImageDynamicRange = .high
    #elseif os(macOS)
      wantsLayer = true
      layer?.masksToBounds = true
      imageView.imageScaling = .scaleAxesIndependently
      imageView.preferredImageDynamicRange = .high
    #endif
    addSubview(imageView)
    _ = update(arguments)

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(FlutterError(code: "disposed", message: "Image view was disposed.", details: nil))
        return
      }
      result(self.update(call.arguments))
    }
  }

  required init?(coder: NSCoder) { nil }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func update(_ arguments: Any?) -> FlutterError? {
    guard let parameters = arguments as? [String: Any] else {
      return FlutterError(
        code: "invalid_arguments", message: "Expected image parameters.", details: nil)
    }
    let path = parameters["imagePath"] as? String
    if path != imagePath {
      if let path = path {
        guard let image = PlatformImage(contentsOfFile: path) else {
          return FlutterError(
            code: "invalid_image", message: "Cannot load image file.", details: path
          )
        }
        imageView.image = image
      } else {
        imageView.image = nil
      }
      imagePath = path
    }
    fit = parameters["fit"] as? String ?? "contain"
    layoutImage()
    return nil
  }

  private func layoutImage() {
    imageView.frame = ImageLayout.frame(
      imageSize: imageView.image?.size ?? .zero, bounds: bounds, fit: fit
    )
  }

  #if os(iOS)
    override func layoutSubviews() {
      super.layoutSubviews()
      layoutImage()
    }
  #elseif os(macOS)
    override var isFlipped: Bool { true }

    override func layout() {
      super.layout()
      layoutImage()
    }
  #endif
}
