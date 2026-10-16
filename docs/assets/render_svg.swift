// Render an SVG to a PNG at its exact size with WebKit (used by make_graphics.py).
//
//     swift docs/assets/render_svg.swift <input.svg> <output.png> <width> <height>

import AppKit
import WebKit

let arguments = CommandLine.arguments
guard arguments.count == 5, let width = Double(arguments[3]), let height = Double(arguments[4]) else {
    FileHandle.standardError.write(Data("usage: render_svg <input.svg> <output.png> <width> <height>\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])

final class Renderer: NSObject, WKNavigationDelegate {
    let view: WKWebView
    init(width: Double, height: Double) {
        view = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        super.init()
        view.navigationDelegate = self
        view.setValue(false, forKey: "drawsBackground")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Give images embedded as data URLs a moment to decode.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let configuration = WKSnapshotConfiguration()
            configuration.rect = webView.bounds
            configuration.snapshotWidth = NSNumber(value: Double(webView.bounds.width))
            webView.takeSnapshot(with: configuration) { image, error in
                guard let image, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write(Data("snapshot failed: \(String(describing: error))\n".utf8))
                    exit(1)
                }
                try? png.write(to: output)
                exit(0)
            }
        }
    }
}

let svg = try String(contentsOf: input, encoding: .utf8)
let page = "<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent}svg{display:block}</style></head><body>\(svg)</body></html>"
let renderer = Renderer(width: width, height: height)
renderer.view.loadHTMLString(page, baseURL: input.deletingLastPathComponent())
RunLoop.main.run()
