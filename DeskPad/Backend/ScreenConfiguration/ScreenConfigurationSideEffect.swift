import Foundation
import ReSwift

private var isObserving = false

enum ScreenConfigurationAction: Action {
    case set(resolution: CGSize, scaleFactor: CGFloat)
    case isActiveOutMainScreen(window: NSWindow, mainScreen: NSScreen)
}

func screenConfigurationSideEffect() -> SideEffect {
    return { action, dispatch, getState in
        if isObserving == false {
            isObserving = true
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: NSApplication.shared,
                queue: .main
            ) { _ in
                guard let screen = NSScreen.screens.first(where: {
                    $0.displayID == getState()?.screenConfigurationState.displayID
                }) else {
                    return
                }
                dispatch(ScreenConfigurationAction.set(
                    resolution: screen.frame.size,
                    scaleFactor: screen.backingScaleFactor
                ))
            }

            NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: NSApplication.shared,
                queue: .main
            ) { _ in
                guard let delegate = NSApplication.shared.delegate as? AppDelegate, let window = delegate.window else { return }
                let mainScreen = NSScreen.screens.first { $0.displayID != getState()?.screenConfigurationState.displayID }
                let isOutMainScreen = window.screen?.displayID == getState()?.screenConfigurationState.displayID
                if let mainScreen, isOutMainScreen {
                    dispatch(ScreenConfigurationAction.isActiveOutMainScreen(window: window, mainScreen: mainScreen))
                }
            }
        }

        switch action {
        case let ScreenConfigurationAction.isActiveOutMainScreen(window, mainScreen):
            let visibleFrame = mainScreen.visibleFrame
            let newOrigin = NSPoint(
                x: visibleFrame.midX - window.frame.width / 2,
                y: visibleFrame.midY - window.frame.height / 2
            )
            window.setFrameOrigin(newOrigin)
            if window.screen != mainScreen {
                window.setFrame(window.frame, display: false)
            }
        default: break
        }
    }
}
