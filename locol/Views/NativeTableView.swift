import SwiftUI
import AppKit

/// A high-performance table view that wraps NSTableView for displaying large datasets efficiently
struct NativeTableView: NSViewRepresentable {
    let result: QueryResult
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let tableView = NSTableView()
        
        // Configure table view
        tableView.style = .inset
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.headerView = NSTableHeaderView()
        
        // Set data source and delegate
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        
        // Configure scroll view
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        
        // Store references for updates
        context.coordinator.tableView = tableView
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.updateData(result)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        weak var tableView: NSTableView?
        weak var scrollView: NSScrollView?
        private var currentResult: QueryResult?
        
        func updateData(_ result: QueryResult) {
            guard let tableView = tableView else { return }
            
            let previousResult = currentResult
            currentResult = result
            
            // Remove existing columns if column structure changed
            if previousResult?.columns != result.columns {
                tableView.tableColumns.forEach { column in
                    tableView.removeTableColumn(column)
                }
                
                // Add new columns
                for (index, columnName) in result.columns.enumerated() {
                    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column\(index)"))
                    column.title = columnName
                    column.minWidth = 100
                    column.maxWidth = 500
                    column.width = 150
                    column.resizingMask = [.autoresizingMask, .userResizingMask]
                    tableView.addTableColumn(column)
                }
            }
            
            // Reload data
            tableView.reloadData()
        }
        
        // MARK: - NSTableViewDataSource
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return currentResult?.rows.count ?? 0
        }
        
        // MARK: - NSTableViewDelegate
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let result = currentResult,
                  let column = tableColumn,
                  let columnIndex = tableView.tableColumns.firstIndex(of: column),
                  row < result.rows.count,
                  columnIndex < result.rows[row].count else {
                return nil
            }
            
            let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
            
            // Try to reuse existing cell
            var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
            
            if cellView == nil {
                // Create new cell view
                cellView = NSTableCellView()
                cellView?.identifier = cellIdentifier
                
                // Create text field
                let textField = NSTextField()
                textField.isEditable = false
                textField.isBordered = false
                textField.backgroundColor = .clear
                textField.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                textField.lineBreakMode = .byTruncatingTail
                textField.cell?.truncatesLastVisibleLine = true
                textField.isSelectable = true
                
                // Set up constraints
                cellView?.addSubview(textField)
                cellView?.textField = textField
                textField.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                    textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                    textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
                ])
            }
            
            // Set cell value
            let value = result.rows[row][columnIndex]
            cellView?.textField?.stringValue = value
            cellView?.textField?.toolTip = value.count > 50 ? value : nil // Show tooltip for long values
            
            return cellView
        }
        
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            return 22 // Compact row height similar to Activity Monitor
        }
        
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            return true
        }
        
        // Enable copying selected cell values
        func tableView(_ tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
            return proposedSelectionIndexes
        }
    }
}

#Preview {
    let sampleResult = QueryResult(
        columns: ["ID", "Name", "Value", "Timestamp"],
        rows: [
            ["1", "Sample Row 1", "100.5", "2024-01-01 10:00:00"],
            ["2", "Sample Row 2", "200.7", "2024-01-01 10:01:00"],
            ["3", "Sample Row 3", "300.2", "2024-01-01 10:02:00"],
        ]
    )
    
    NativeTableView(result: sampleResult)
        .frame(width: 600, height: 400)
}