import CoreGraphics

@main
enum ImageLayoutTests {
  static func main() {
    let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
    let imageSize = CGSize(width: 200, height: 50)
    let expected: [String: CGRect] = [
      "fill": CGRect(x: 0, y: 0, width: 100, height: 100),
      "contain": CGRect(x: 0, y: 37.5, width: 100, height: 25),
      "cover": CGRect(x: -150, y: 0, width: 400, height: 100),
      "fitWidth": CGRect(x: 0, y: 37.5, width: 100, height: 25),
      "fitHeight": CGRect(x: -150, y: 0, width: 400, height: 100),
      "none": CGRect(x: -50, y: 25, width: 200, height: 50),
      "scaleDown": CGRect(x: 0, y: 37.5, width: 100, height: 25),
    ]
    for (fit, frame) in expected {
      precondition(ImageLayout.frame(imageSize: imageSize, bounds: bounds, fit: fit) == frame, fit)
      let portraitFrame = ImageLayout.frame(
        imageSize: CGSize(width: imageSize.height, height: imageSize.width),
        bounds: bounds,
        fit: fit == "fitWidth" ? "fitHeight" : fit == "fitHeight" ? "fitWidth" : fit
      )
      precondition(
        portraitFrame
          == CGRect(
            x: frame.origin.y, y: frame.origin.x, width: frame.height, height: frame.width
          ), "portrait \(fit)")
    }
    precondition(
      ImageLayout.frame(
        imageSize: CGSize(width: 20, height: 10), bounds: bounds, fit: "scaleDown"
      ) == CGRect(x: 40, y: 45, width: 20, height: 10))
    precondition(ImageLayout.frame(imageSize: .zero, bounds: bounds, fit: "cover") == .zero)
    precondition(ImageLayout.frame(imageSize: imageSize, bounds: .zero, fit: "contain") == .zero)
    print("ImageLayout: all seven fits, portrait/landscape, scaleDown, and empty bounds passed.")
  }
}
