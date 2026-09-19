import AppKit
import SwiftUI

enum SidebarWidth {
    static let minimum: CGFloat = 200
    static let ideal: CGFloat = 260
    static let maximum: CGFloat = 300
}

final class LibrarySidebarState: ObservableObject {
    private static let defaultsKey = AppConfiguration.userDefaultsKey("sidebar.isCollapsed")
    @Published private(set) var isCollapsed = UserDefaults.standard.bool(forKey: LibrarySidebarState.defaultsKey)
    fileprivate var toggleAction: (() -> Void)?

    func toggle() {
        toggleAction?()
    }

    fileprivate func didToggle(_ collapsed: Bool) {
        guard isCollapsed != collapsed else { return }
        isCollapsed = collapsed
        UserDefaults.standard.set(collapsed, forKey: Self.defaultsKey)
    }
}

/// Owns the split controller so SwiftUI never rewrites its items or interrupts its animator.
struct NativeLibrarySplitView<Sidebar: View, Detail: View>: NSViewControllerRepresentable {
    let sidebarState: LibrarySidebarState
    let minimumDetailWidth: CGFloat
    let toolbar: LibraryToolbarState
    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail

    func makeCoordinator() -> Coordinator {
        Coordinator(toolbar: toolbar, sidebarState: sidebarState)
    }

    func makeNSViewController(context: Context) -> Controller {
        let controller = Controller(
            sidebar: AnyView(sidebar().environment(\.self, context.environment)),
            detail: hostedDetail(context: context),
            isSidebarCollapsed: sidebarState.isCollapsed,
            minimumDetailWidth: minimumDetailWidth
        )
        controller.reducesMotion = context.environment.accessibilityReduceMotion
        controller.onCollapsedChanged = { [weak sidebarState] collapsed in
            sidebarState?.didToggle(collapsed)
        }
        sidebarState.toggleAction = { [weak controller] in
            controller?.toggleFromToolbar()
        }
        return controller
    }

    func updateNSViewController(_ controller: Controller, context: Context) {
        controller.sidebarHost.rootView = AnyView(sidebar().environment(\.self, context.environment))
        controller.detailHost.rootView = hostedDetail(context: context)
        controller.reducesMotion = context.environment.accessibilityReduceMotion
    }

    static func dismantleNSViewController(_ controller: Controller, coordinator: Coordinator) {
        coordinator.isActive = false
        coordinator.sidebarState.toggleAction = nil
        controller.onCollapsedChanged = nil
    }

    private func hostedDetail(context: Context) -> AnyView {
        let coordinator = context.coordinator
        return AnyView(
            detail()
                .environment(\.self, context.environment)
                .onPreferenceChange(LibraryToolbarPreferenceKey.self) { configuration in
                    coordinator.receive(configuration)
                }
        )
    }

    final class Coordinator {
        let sidebarState: LibrarySidebarState
        private let toolbar: LibraryToolbarState
        private var generation = 0
        var isActive = true

        init(toolbar: LibraryToolbarState, sidebarState: LibrarySidebarState) {
            self.toolbar = toolbar
            self.sidebarState = sidebarState
        }

        func receive(_ configuration: LibraryToolbarConfiguration) {
            generation += 1
            let currentGeneration = generation
            // Deliver preferences outside the hosted SwiftUI update, without rebuilding the split view.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isActive, self.generation == currentGeneration else { return }
                self.toolbar.update(configuration)
            }
        }
    }

    final class Controller: NSSplitViewController {
        let sidebarHost: NSHostingController<AnyView>
        let detailHost: NSHostingController<AnyView>
        private let sidebarItem: NSSplitViewItem
        var reducesMotion = false
        var onCollapsedChanged: ((Bool) -> Void)?

        init(sidebar: AnyView, detail: AnyView, isSidebarCollapsed: Bool, minimumDetailWidth: CGFloat) {
            let sidebarController = NSHostingController(rootView: sidebar)
            sidebarHost = sidebarController
            detailHost = NSHostingController(rootView: detail)
            sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
            super.init(nibName: nil, bundle: nil)

            // Only the split items set pane minimums. A hosting view's fitting size must not grow
            // the window when the sidebar opens. 300 + 648 + divider fits the 980-point window.
            sidebarHost.sizingOptions = []
            detailHost.sizingOptions = []
            minimumThicknessForInlineSidebars = 0
            sidebarItem.minimumThickness = SidebarWidth.minimum
            sidebarItem.maximumThickness = SidebarWidth.maximum
            sidebarItem.canCollapse = false
            sidebarItem.canCollapseFromWindowResize = false
            sidebarItem.isSpringLoaded = false
            sidebarItem.preferredThicknessFraction = NSSplitViewItem.unspecifiedDimension
            // Hold the sidebar ahead of the detail (250), but yield to native divider drags (490).
            sidebarItem.holdingPriority = NSLayoutConstraint.Priority(rawValue: 260)
            sidebarItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView
            sidebarItem.isCollapsed = isSidebarCollapsed

            let detailItem = NSSplitViewItem(viewController: detailHost)
            detailItem.minimumThickness = minimumDetailWidth
            detailItem.holdingPriority = .defaultLow
            addSplitViewItem(sidebarItem)
            addSplitViewItem(detailItem)

            // A low-priority initial width yields to AppKit's native divider dragging and restoration.
            let initialWidth = sidebarHost.view.widthAnchor.constraint(equalToConstant: SidebarWidth.ideal)
            initialWidth.priority = NSLayoutConstraint.Priority(rawValue: 249)
            initialWidth.isActive = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            splitView.isVertical = true
            splitView.dividerStyle = .thin
        }

        func toggleFromToolbar() {
            let collapsed = !sidebarItem.isCollapsed
            if reducesMotion {
                sidebarItem.isCollapsed = collapsed
            } else {
                // Programmatic collapse remains available when canCollapse disables user gestures.
                // Animate the item itself instead of routing through the controller's toggle action.
                sidebarItem.animator().isCollapsed = collapsed
            }
            onCollapsedChanged?(collapsed)
        }
    }
}
