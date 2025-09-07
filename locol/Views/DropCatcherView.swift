import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropCatcherView: NSViewRepresentable {
    let acceptedTypes: [UTType]
    let onPerformDrop: (NSPasteboard) -> Bool
    var isActive: Binding<Bool>? = nil

    func makeNSView(context: Context) -> NSView {
        let v = DropCatcherNSView(acceptedTypes: acceptedTypes, onPerformDrop: onPerformDrop, isActive: isActive)
        v.wantsLayer = true
        v.layer?.backgroundColor = .clear
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DropCatcherNSView: NSView {
        let acceptedTypes: [NSPasteboard.PasteboardType]
        let onPerformDrop: (NSPasteboard) -> Bool
        var isActive: Binding<Bool>?

        init(acceptedTypes: [UTType], onPerformDrop: @escaping (NSPasteboard) -> Bool, isActive: Binding<Bool>?) {
            self.acceptedTypes = acceptedTypes.map { NSPasteboard.PasteboardType($0.identifier) }
            self.onPerformDrop = onPerformDrop
            self.isActive = isActive
            super.init(frame: .zero)
            registerForDraggedTypes(self.acceptedTypes)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            let pb = sender.draggingPasteboard
            let ok = pb.types?.contains(where: acceptedTypes.contains) == true
            if ok { isActive?.wrappedValue = true }
            return ok ? .copy : []
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            defer { isActive?.wrappedValue = false }
            return onPerformDrop(sender.draggingPasteboard)
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            isActive?.wrappedValue = false
        }

        // Pass through mouse interactions to underlying editor
        override func hitTest(_ point: NSPoint) -> NSView? {
            if let e = NSApp.currentEvent, e.type == .leftMouseDown || e.type == .rightMouseDown || e.type == .otherMouseDown {
                return nil
            }
            // For drags and mouse moves, return self so we can be a dragging destination
            return self
        }
    }
}
