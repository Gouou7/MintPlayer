import AppKit
import SwiftUI

struct EmbeddedLyricsPresentationLayer: NSViewRepresentable {
    let song: Song?
    let isPresented: Bool
    let showsImmersiveControls: Bool
    let audioPlayer: AudioPlayer
    let settings: SettingsManager
    let onClose: () -> Void
    let onDismissed: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    func makeNSView(context: Context) -> Viewport {
        Viewport(frame: .zero)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: Viewport, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ viewport: Viewport, context: Context) {
        let page = song.map {
            LyricsPage(
                song: $0,
                showsImmersiveControls: showsImmersiveControls,
                audioPlayer: audioPlayer,
                settings: settings,
                onClose: onClose
            )
        }
        viewport.update(page: page, isPresented: isPresented, reducesMotion: reducesMotion, onDismissed: onDismissed)
    }

    static func dismantleNSView(_ viewport: Viewport, coordinator: ()) {
        viewport.removePage()
    }

    fileprivate struct LyricsPage: View {
        let song: Song
        let showsImmersiveControls: Bool
        let audioPlayer: AudioPlayer
        let settings: SettingsManager
        let onClose: () -> Void

        var body: some View {
            LyricsOverlayView(song: song, extendsBackgroundIntoSafeArea: false, onClose: onClose)
                .overlay(alignment: .topTrailing) {
                    if showsImmersiveControls {
                        ImmersiveLyricsControls(onClose: onClose)
                            .padding(.top, 20)
                            .padding(.trailing, 24)
                    }
                }
                .environmentObject(audioPlayer)
                .environmentObject(settings)
                .environment(\.colorScheme, .dark)
        }
    }

    final class Viewport: NSView {
        private let surface = NSView()
        private var hostingView: NSHostingView<LyricsPage>?
        private var wantsPresentation = false
        private var targetIsPresented = false
        private var isAnimating = false
        private var reducesMotion = false
        private var transitionID = 0
        private var onDismissed: (() -> Void)?

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            clipsToBounds = true
            surface.wantsLayer = true
            surface.clipsToBounds = true
            // Both layers position and clip their children without drawing content of their own.
            layerContentsRedrawPolicy = .never
            layerContentsPlacement = .scaleAxesIndependently
            surface.layerContentsRedrawPolicy = .never
            surface.layerContentsPlacement = .scaleAxesIndependently
            addSubview(surface)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        fileprivate func update(page: LyricsPage?, isPresented: Bool, reducesMotion: Bool, onDismissed: @escaping () -> Void) {
            let presentationChanged = wantsPresentation != isPresented
            let motionChanged = self.reducesMotion != reducesMotion
            self.reducesMotion = reducesMotion

            guard let page else {
                if hostingView != nil { removePage() }
                if motionChanged { needsLayout = true }
                return
            }

            wantsPresentation = isPresented
            self.onDismissed = isPresented ? nil : onDismissed
            if let hostingView {
                let previousPage = hostingView.rootView
                if previousPage.song != page.song || previousPage.showsImmersiveControls != page.showsImmersiveControls {
                    hostingView.rootView = page
                }
            } else {
                // The viewport already owns the parked surface before the first lyric page is mounted.
                surface.frame = CGRect(origin: surfaceOrigin(isPresented: false), size: bounds.size)
                surface.alphaValue = reducesMotion ? 0 : 1
                let host = NSHostingView(rootView: page)
                host.sizingOptions = []
                host.safeAreaRegions = []
                host.appearance = NSAppearance(named: .darkAqua)
                host.frame = surface.bounds
                host.autoresizingMask = [.width, .height]
                host.setAccessibilityHidden(true)
                surface.addSubview(host)
                hostingView = host
            }

            if presentationChanged || motionChanged {
                needsLayout = true
            }
            if !isPresented && !targetIsPresented && !isAnimating {
                finishDismissal()
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            needsLayout = true
        }

        override func layout() {
            super.layout()
            let heightChanged = surface.frame.height != bounds.height
            if surface.frame.size != bounds.size {
                surface.setFrameSize(bounds.size)
            }

            if !isAnimating {
                placeSurface(isPresented: targetIsPresented)
            }

            guard window != nil, !bounds.isEmpty, hostingView != nil else { return }
            let closingTargetMoved = heightChanged && isAnimating && !targetIsPresented && !reducesMotion
            guard wantsPresentation != targetIsPresented || closingTargetMoved else { return }
            if !isAnimating {
                surface.layoutSubtreeIfNeeded()
            }
            animateSurface(isPresented: wantsPresentation)
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard wantsPresentation, targetIsPresented, !isAnimating else { return nil }
            return super.hitTest(point)
        }

        func removePage() {
            transitionID += 1
            let wasAnimating = isAnimating
            wantsPresentation = false
            targetIsPresented = false
            isAnimating = false
            onDismissed = nil
            hostingView?.removeFromSuperview()
            hostingView = nil
            if wasAnimating {
                NSAnimationContext.animate(.linear(duration: 0)) {
                    placeSurface(isPresented: false)
                }
            } else {
                placeSurface(isPresented: false)
            }
        }

        private func surfaceOrigin(isPresented: Bool) -> CGPoint {
            CGPoint(x: bounds.minX, y: isPresented || reducesMotion ? bounds.minY : bounds.minY - bounds.height)
        }

        private func placeSurface(isPresented: Bool) {
            let origin = surfaceOrigin(isPresented: isPresented)
            if surface.frame.origin != origin {
                surface.frame.origin = origin
            }

            let alpha: CGFloat = isPresented || !reducesMotion ? 1 : 0
            if surface.alphaValue != alpha {
                surface.alphaValue = alpha
            }
        }

        private func animateSurface(isPresented: Bool) {
            transitionID += 1
            let id = transitionID
            targetIsPresented = isPresented
            isAnimating = true
            hostingView?.setAccessibilityHidden(true)

            NSAnimationContext.animate(.easeInOut(duration: reducesMotion ? 0.16 : 0.38)) {
                placeSurface(isPresented: isPresented)
            } completion: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.transitionID == id else { return }
                    self.isAnimating = false
                    self.placeSurface(isPresented: isPresented)
                    self.hostingView?.setAccessibilityHidden(!isPresented || !self.wantsPresentation)
                    if !isPresented && !self.wantsPresentation {
                        self.finishDismissal()
                    }
                }
            }
        }

        private func finishDismissal() {
            guard let onDismissed else { return }
            self.onDismissed = nil
            let id = transitionID
            Task { @MainActor [weak self] in
                guard let self, self.transitionID == id, !self.wantsPresentation else { return }
                onDismissed()
            }
        }
    }
}

private struct ImmersiveLyricsControls: View {
    @EnvironmentObject private var settings: SettingsManager
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            Image(systemName: "chevron.down")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(MintPlainIconButtonStyle(hoverSize: CGSize(width: 36, height: 36)))
        .modifier(CircleGlassButtonSurface())
        .help(settings.text(.close))
        .accessibilityLabel(settings.text(.close))
    }
}
