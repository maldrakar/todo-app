import AppKit
import WebKit

// Usage: snap <html path> <out dir>. Renders the page at 1180 pt wide in the light and the dark appearance.
let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let size = NSRect(x: 0, y: 0, width: 1180, height: 6000)

final class Shot: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let window: NSWindow
    let name: String
    let done: () -> Void
    init(appearance: NSAppearance.Name, name: String, done: @escaping () -> Void) {
        web = WKWebView(frame: size, configuration: WKWebViewConfiguration())
        web.appearance = NSAppearance(named: appearance)
        window = NSWindow(contentRect: size, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = web
        window.appearance = NSAppearance(named: appearance)
        self.name = name
        self.done = done
        super.init()
        web.navigationDelegate = self
        web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let config = WKSnapshotConfiguration()
            config.rect = size
            self.web.takeSnapshot(with: config) { image, error in
                if let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: outDir.appendingPathComponent(self.name + ".png"))
                    print("wrote", self.name, Int(image.size.height))
                } else {
                    print("snapshot failed", self.name, error.map { "\($0)" } ?? "")
                }
                self.done()
            }
        }
    }
}

var shots: [Shot] = []
var remaining = 2
func finish() { remaining -= 1; if remaining == 0 { exit(0) } }
shots.append(Shot(appearance: .aqua, name: "light", done: finish))
shots.append(Shot(appearance: .darkAqua, name: "dark", done: finish))
app.run()
