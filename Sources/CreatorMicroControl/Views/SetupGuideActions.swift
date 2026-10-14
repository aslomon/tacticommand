import AppKit

/// AppKit side effects for `SetupGuideView`'s backup row, split out to keep that file
/// focused on layout. Both are read-only with respect to the backup file itself.
extension SetupGuideView {
    func copyBackupPath(_ path: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        didCopyBackupPath = true
    }

    func revealBackupPath(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
