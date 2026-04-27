import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    if let screen = self.screen ?? NSScreen.main {
      let visibleFrame = screen.visibleFrame
      let width = min(max(visibleFrame.width * 0.9, 1180), visibleFrame.width - 80)
      let height = min(max(visibleFrame.height * 0.9, 760), visibleFrame.height - 80)
      let origin = NSPoint(
        x: visibleFrame.midX - (width / 2),
        y: visibleFrame.midY - (height / 2)
      )
      let targetFrame = NSRect(origin: origin, size: NSSize(width: width, height: height))
      self.setFrame(targetFrame, display: true)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
