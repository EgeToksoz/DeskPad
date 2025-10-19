import Cocoa
import ReSwift

enum ScreenViewAction: Action {
    case setDisplayID(CGDirectDisplayID)
}

class ScreenViewController: SubscriberViewController<ScreenViewData>, NSWindowDelegate {
    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(didClickOnScreen)))
    }

    private var display: CGVirtualDisplay!
    private var stream: CGDisplayStream?
    private var isWindowHighlighted = false
    private var previousResolution: CGSize?
    private var previousScaleFactor: CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()
        SerialNumberManager.shared.claimSerial()
        let serial = SerialNumberManager.shared.claimedSerial ?? 0x0001
        title = "Screen \(serial)"

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = "DeskPad Display \(serial)"
        descriptor.maxPixelsWide = 5120
        descriptor.maxPixelsHigh = 2160
        descriptor.sizeInMillimeters = CGSize(width: 1600, height: 1000)
        descriptor.productID = 0x1234
        descriptor.vendorID = 0x3456
        descriptor.serialNum = serial

        let display = CGVirtualDisplay(descriptor: descriptor)
        store.dispatch(ScreenViewAction.setDisplayID(display.displayID))
        self.display = display

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = [
            // 32:9
            CGVirtualDisplayMode(width: 5120, height: 1440, refreshRate: 120),
            // 21:9 (239:100, 12:5)
            CGVirtualDisplayMode(width: 5120, height: 2160, refreshRate: 120),
            CGVirtualDisplayMode(width: 3840, height: 1600, refreshRate: 120),
            CGVirtualDisplayMode(width: 3440, height: 1440, refreshRate: 120),
            // 16:9
            CGVirtualDisplayMode(width: 3840, height: 2160, refreshRate: 120),
            CGVirtualDisplayMode(width: 2560, height: 1440, refreshRate: 120),
            CGVirtualDisplayMode(width: 1920, height: 1080, refreshRate: 120),
            CGVirtualDisplayMode(width: 1600, height: 900, refreshRate: 120),
            CGVirtualDisplayMode(width: 1366, height: 768, refreshRate: 120),
            CGVirtualDisplayMode(width: 1280, height: 720, refreshRate: 120),
            // 16:10
            CGVirtualDisplayMode(width: 2560, height: 1600, refreshRate: 120),
            CGVirtualDisplayMode(width: 1920, height: 1200, refreshRate: 120),
            CGVirtualDisplayMode(width: 1680, height: 1050, refreshRate: 120),
            CGVirtualDisplayMode(width: 1440, height: 900, refreshRate: 120),
            CGVirtualDisplayMode(width: 1280, height: 800, refreshRate: 120),
            // 21:9
            CGVirtualDisplayMode(width: 3440, height: 1440, refreshRate: 120),
            CGVirtualDisplayMode(width: 1720, height: 720, refreshRate: 120),
            // Macs with Notch
            CGVirtualDisplayMode(width: 1512, height: 945, refreshRate: 120),
            CGVirtualDisplayMode(width: 1800, height: 1125, refreshRate: 120),
            CGVirtualDisplayMode(width: 1512, height: 915, refreshRate: 120),
            CGVirtualDisplayMode(width: 1800, height: 1095, refreshRate: 120),
        ]
        display.apply(settings)
    }

    override func update(with viewData: ScreenViewData) {
        if viewData.isWindowHighlighted != isWindowHighlighted {
            isWindowHighlighted = viewData.isWindowHighlighted
            view.window?.backgroundColor = isWindowHighlighted
                ? NSColor(named: "TitleBarActive")
                : NSColor(named: "TitleBarInactive")
            if isWindowHighlighted {
                view.window?.orderFrontRegardless()
            }
        }
        if let window = view.window, let screen = window.screen {
            let visibleFrame = screen.visibleFrame
            var frame = window.frame

            // Clamp width and height to not exceed screen
            frame.size.width = min(frame.size.width, visibleFrame.size.width)
            frame.size.height = min(frame.size.height, visibleFrame.size.height)

            // Reposition if needed to keep it fully visible
            if frame.origin.x < visibleFrame.origin.x {
                frame.origin.x = visibleFrame.origin.x
            }
            if frame.origin.y < visibleFrame.origin.y {
                frame.origin.y = visibleFrame.origin.y
            }
            if frame.maxX > visibleFrame.maxX {
                frame.origin.x = visibleFrame.maxX - frame.size.width
            }
            if frame.maxY > visibleFrame.maxY {
                frame.origin.y = visibleFrame.maxY - frame.size.height
            }

            window.setFrame(frame, display: true, animate: true)
        }
        if
            viewData.resolution != .zero,
            viewData.resolution != previousResolution
            || viewData.scaleFactor != previousScaleFactor
        {
            previousResolution = viewData.resolution
            previousScaleFactor = viewData.scaleFactor
            stream = nil
            if let window = view.window, let screen = window.screen {
                let visibleFrame = screen.visibleFrame
                var targetSize = viewData.resolution
                // Clamp the resolution to the visible frame size
                if targetSize.width > visibleFrame.size.width || targetSize.height > visibleFrame.size.height {
                    let widthRatio = visibleFrame.size.width / targetSize.width
                    let heightRatio = visibleFrame.size.height / targetSize.height
                    let scale = min(widthRatio, heightRatio, 1.0) // Only shrink, never enlarge
                    targetSize.width = floor(targetSize.width * scale)
                    targetSize.height = floor(targetSize.height * scale)
                }
                window.setContentSize(targetSize)
                window.contentAspectRatio = targetSize
                window.center()
            }
            let stream = CGDisplayStream(
                dispatchQueueDisplay: display.displayID,
                outputWidth: Int(viewData.resolution.width * viewData.scaleFactor),
                outputHeight: Int(viewData.resolution.height * viewData.scaleFactor),
                pixelFormat: 1_111_970_369,
                properties: [
                    CGDisplayStream.showCursor: true,
                ] as CFDictionary,
                queue: .main,
                handler: { [weak self] _, _, frameSurface, _ in
                    if let surface = frameSurface {
                        self?.view.layer?.contents = surface
                    }
                }
            )
            self.stream = stream
            stream?.start()
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    func windowWillResize(_ window: NSWindow, to frameSize: NSSize) -> NSSize {
        let snappingOffset: CGFloat = 30
        let contentRect = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize))
        let contentSize = contentRect.size
        print("contentsize=\(contentSize), abs=\(contentSize.width - (previousResolution?.width ?? 0))")
        guard
            let screenResolution = previousResolution,
            abs(contentSize.width - screenResolution.width) < snappingOffset
        else {
            return frameSize
        }
        return window.frameRect(forContentRect: NSRect(origin: .zero, size: screenResolution)).size
    }

    @objc private func didClickOnScreen(_ gestureRecognizer: NSGestureRecognizer) {
        guard let screenResolution = previousResolution else {
            return
        }
        let clickedPoint = gestureRecognizer.location(in: view)
        let onScreenPoint = NSPoint(
            x: clickedPoint.x / view.frame.width * screenResolution.width,
            y: (view.frame.height - clickedPoint.y) / view.frame.height * screenResolution.height
        )
        store.dispatch(MouseLocationAction.requestMove(toPoint: onScreenPoint))
    }

    func stopDisplayStream() {
        stream?.stop()
        stream = nil
    }

    func applicationWillTerminate(_: Notification) {
        SerialNumberManager.shared.releaseSerial()
    }
}
