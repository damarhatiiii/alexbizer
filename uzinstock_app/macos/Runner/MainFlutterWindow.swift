import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "UzinStock — PT Uzin Utz Indonesia"
    self.minSize = NSSize(width: 960, height: 640)

    if let screen = self.screen ?? NSScreen.main {
      let visible = screen.visibleFrame
      let width = min(1320.0, visible.width * 0.9)
      let height = min(840.0, visible.height * 0.88)
      let x = visible.origin.x + (visible.width - width) / 2.0
      let y = visible.origin.y + (visible.height - height) / 2.0
      self.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
