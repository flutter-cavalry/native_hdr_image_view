import CoreGraphics

enum ImageLayout {
  static func frame(imageSize: CGSize, bounds: CGRect, fit: String) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0,
      bounds.width > 0, bounds.height > 0
    else {
      return .zero
    }

    let widthScale = bounds.width / imageSize.width
    let heightScale = bounds.height / imageSize.height
    let size: CGSize
    if fit == "fill" {
      size = bounds.size
    } else {
      let scale: CGFloat
      switch fit {
      case "cover":
        scale = max(widthScale, heightScale)
      case "fitWidth":
        scale = widthScale
      case "fitHeight":
        scale = heightScale
      case "none":
        scale = 1
      case "scaleDown":
        scale = min(1, min(widthScale, heightScale))
      default:
        scale = min(widthScale, heightScale)
      }
      size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    return CGRect(
      x: bounds.midX - size.width / 2,
      y: bounds.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
  }
}
