import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()

    // Set a comfortable initial size and enforce a sensible minimum.
    let initialSize = CGSize(width: 1100, height: 750)
    let screen = NSScreen.main ?? NSScreen.screens.first
    let origin: CGPoint
    if let screenFrame = screen?.visibleFrame {
      origin = CGPoint(
        x: screenFrame.midX - initialSize.width / 2,
        y: screenFrame.midY - initialSize.height / 2
      )
    } else {
      origin = CGPoint(x: 200, y: 200)
    }
    let windowFrame = CGRect(origin: origin, size: initialSize)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = CGSize(width: 800, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
