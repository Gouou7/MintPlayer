import AppKit
import SwiftUI

enum SidebarWidth {
    static let minimum: CGFloat = 200
    static let ideal: CGFloat = 260
    static let maximum: CGFloat = 300
}

final class LibrarySidebarState: ObservableObject {
    private static let defaultsKey = AppConfiguration.userDefaultsKey("sidebar.isCollapsed")

    @Published var columnVisibility: NavigationSplitViewVisibility {
        didSet {
            guard columnVisibility != oldValue else { return }
            switch columnVisibility {
            case .detailOnly:
                UserDefaults.standard.set(true, forKey: Self.defaultsKey)
            case .all, .doubleColumn:
                UserDefaults.standard.set(false, forKey: Self.defaultsKey)
            default:
                break
            }
        }
    }

    var isCollapsed: Bool { columnVisibility == .detailOnly }

    init() {
        columnVisibility = UserDefaults.standard.bool(forKey: Self.defaultsKey) ? .detailOnly : .all
    }

    func toggle() {
        columnVisibility = isCollapsed ? .all : .detailOnly
    }
}

/// Lets NavigationSplitView own the sidebar button, toolbar sections, and collapse animation.
struct NativeLibrarySplitView<Sidebar: View, Detail: View>: View {
    @ObservedObject var sidebarState: LibrarySidebarState
    let minimumDetailWidth: CGFloat
    let toolbar: LibraryToolbarState
    @ViewBuilder var sidebar: () -> Sidebar
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarState.columnVisibility) {
            sidebar()
                .navigationSplitViewColumnWidth(
                    min: SidebarWidth.minimum,
                    ideal: SidebarWidth.ideal,
                    max: SidebarWidth.maximum
                )
                .background {
                    SidebarColumnWidthConfigurator()
                        .frame(width: 0, height: 0)
                }
        } detail: {
            detail()
                .frame(minWidth: minimumDetailWidth)
                .onPreferenceChange(LibraryToolbarPreferenceKey.self) { configuration in
                    toolbar.update(configuration)
                }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct SidebarColumnWidthConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> HostView {
        HostView()
    }

    func updateNSView(_ nsView: HostView, context: Context) {
        nsView.configureWidth()
    }

    static func dismantleNSView(_ nsView: HostView, coordinator: ()) {
        nsView.restoreWidth()
    }

    final class HostView: NSView {
        private weak var configuredItem: NSSplitViewItem?
        private var originalMinimum = NSSplitViewItem.unspecifiedDimension
        private var originalMaximum = NSSplitViewItem.unspecifiedDimension

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            configureWidth()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            configureWidth()
        }

        override func layout() {
            super.layout()
            configureWidth()
        }

        func configureWidth() {
            var ancestor = superview
            while let view = ancestor {
                if let splitView = view as? NSSplitView,
                   let controller = splitViewController(for: splitView),
                   let item = controller.splitViewItems.first(where: {
                       $0.behavior == .sidebar && isDescendant(of: $0.viewController.view)
                   }) {
                    if configuredItem !== item {
                        restoreWidth()
                        configuredItem = item
                        originalMinimum = item.minimumThickness
                        originalMaximum = item.maximumThickness
                    }

                    // SwiftUI column widths are preferences; AppKit enforces divider limits.
                    if item.minimumThickness != SidebarWidth.minimum {
                        item.minimumThickness = SidebarWidth.minimum
                    }
                    if item.maximumThickness != SidebarWidth.maximum {
                        item.maximumThickness = SidebarWidth.maximum
                    }
                    return
                }
                ancestor = view.superview
            }
        }

        private func splitViewController(for splitView: NSSplitView) -> NSSplitViewController? {
            if let controller = splitView.delegate as? NSSplitViewController {
                return controller
            }

            var responder = splitView.nextResponder
            while let current = responder {
                if let controller = current as? NSSplitViewController, controller.splitView === splitView {
                    return controller
                }
                responder = current.nextResponder
            }
            return nil
        }

        func restoreWidth() {
            guard let item = configuredItem else { return }
            configuredItem = nil
            item.minimumThickness = originalMinimum
            item.maximumThickness = originalMaximum
        }
    }
}
