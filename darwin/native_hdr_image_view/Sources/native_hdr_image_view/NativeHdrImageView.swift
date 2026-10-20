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
  private enum Source: Equatable {
    case file(String)
    case bytes(Data)
    case network(URL)
  }

  private let imageView = PlatformImageView()
  private let channel: FlutterMethodChannel
  private var fit = "contain"
  private var source: Source?
  private var request: URLSessionDataTask?
  private var requestID = 0
  private var pendingResults: [FlutterResult] = []

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
    update(arguments) { _ in }

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self else {
        result(FlutterError(code: "disposed", message: "Image view was disposed.", details: nil))
        return
      }
      self.update(call.arguments, result: result)
    }
  }

  required init?(coder: NSCoder) { nil }

  deinit {
    request?.cancel()
    for result in pendingResults { result(nil) }
    channel.setMethodCallHandler(nil)
  }

  private func update(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let parameters = arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_arguments", message: "Expected image parameters.", details: nil))
      return
    }
    let nextSource: Source?
    if let urlString = parameters["imageUrl"] as? String {
      guard let url = URL(string: urlString),
        let scheme = url.scheme?.lowercased(),
        ["https", "http"].contains(scheme), url.host != nil
      else {
        result(
          FlutterError(
            code: "invalid_url", message: "Expected an HTTP or HTTPS image URL.", details: urlString
          ))
        return
      }
      nextSource = .network(url)
    } else if let bytes = parameters["imageBytes"] as? FlutterStandardTypedData {
      nextSource = .bytes(bytes.data)
    } else if let path = parameters["imagePath"] as? String {
      nextSource = .file(path)
    } else {
      nextSource = nil
    }

    fit = parameters["fit"] as? String ?? "contain"
    layoutImage()
    if nextSource == source {
      if request != nil {
        pendingResults.append(result)
      } else {
        result(nil)
      }
      return
    }

    requestID += 1
    request?.cancel()
    request = nil
    completePending(nil)
    source = nil
    imageView.image = nil
    layoutImage()

    switch nextSource {
    case .file(let path):
      guard let image = PlatformImage(contentsOfFile: path) else {
        result(
          FlutterError(
            code: "invalid_image", message: "Cannot load image file.", details: path))
        return
      }
      imageView.image = image
    case .bytes(let data):
      guard let image = PlatformImage(data: data) else {
        result(
          FlutterError(
            code: "invalid_image", message: "Cannot decode image bytes.", details: nil))
        return
      }
      imageView.image = image
    case .network(let url):
      source = nextSource
      pendingResults.append(result)
      let currentRequestID = requestID
      request = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
        DispatchQueue.main.async { [weak self] in
          guard let self = self, self.requestID == currentRequestID else { return }
          self.request = nil
          let failure: FlutterError?
          if let error = error {
            failure = FlutterError(
              code: "network_error", message: error.localizedDescription,
              details: url.absoluteString)
          } else if let response = response as? HTTPURLResponse,
            !(200...299).contains(response.statusCode)
          {
            failure = FlutterError(
              code: "network_error", message: "HTTP \(response.statusCode)",
              details: url.absoluteString)
          } else if let data = data, let image = PlatformImage(data: data) {
            self.imageView.image = image
            failure = nil
          } else {
            failure = FlutterError(
              code: "invalid_image", message: "Cannot decode downloaded image.",
              details: url.absoluteString)
          }
          if failure != nil { self.source = nil }
          self.layoutImage()
          self.completePending(failure)
        }
      }
      request?.resume()
      return
    case nil:
      break
    }
    source = nextSource
    layoutImage()
    result(nil)
  }

  private func completePending(_ error: FlutterError?) {
    let results = pendingResults
    pendingResults.removeAll()
    for result in results { result(error) }
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
