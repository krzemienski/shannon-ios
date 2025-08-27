import SwiftUI

/// Provides icons and colors for different file types
public struct FileIconProvider {
    
    /// Get icon configuration for a file node
    public static func icon(for node: FileTreeNode) -> FileIconConfig {
        if node.isDirectory {
            return directoryIcon(name: node.name)
        }
        
        return fileIcon(for: node.fileType, name: node.name)
    }
    
    /// Get icon for a directory with special folder detection
    private static func directoryIcon(name: String) -> FileIconConfig {
        let lowercasedName = name.lowercased()
        
        // Special folder icons
        switch lowercasedName {
        case "sources", "src":
            return FileIconConfig(systemName: "folder.fill.badge.gearshape", color: .blue)
        case "tests", "test", "__tests__":
            return FileIconConfig(systemName: "folder.fill.badge.checkmark", color: .green)
        case "docs", "documentation":
            return FileIconConfig(systemName: "folder.fill.badge.questionmark", color: .orange)
        case "assets", "resources":
            return FileIconConfig(systemName: "folder.fill.badge.photo", color: .purple)
        case "build", "dist", "output":
            return FileIconConfig(systemName: "folder.fill.badge.hammer", color: .gray)
        case ".git":
            return FileIconConfig(systemName: "folder.fill.badge.gearshape", color: .orange)
        case "node_modules", "packages", "pods":
            return FileIconConfig(systemName: "shippingbox.fill", color: .brown)
        case "views", "ui":
            return FileIconConfig(systemName: "folder.fill.badge.rectangle", color: .teal)
        case "models", "data":
            return FileIconConfig(systemName: "folder.fill.badge.cylinder", color: .indigo)
        case "controllers", "viewmodels":
            return FileIconConfig(systemName: "folder.fill.badge.gear", color: .mint)
        case "services", "api":
            return FileIconConfig(systemName: "folder.fill.badge.network", color: .cyan)
        case "config", "configuration", "settings":
            return FileIconConfig(systemName: "folder.fill.badge.gearshape", color: .gray)
        default:
            if name.hasPrefix(".") {
                return FileIconConfig(systemName: "folder.fill", color: .secondary)
            }
            return FileIconConfig(systemName: "folder.fill", color: .blue)
        }
    }
    
    /// Get icon for a file based on its type
    private static func fileIcon(for type: FileType, name: String) -> FileIconConfig {
        let lowercasedName = name.lowercased()
        
        // Special file icons
        switch lowercasedName {
        case "readme.md", "readme", "readme.txt":
            return FileIconConfig(systemName: "doc.text.fill", color: .blue)
        case "license", "license.txt", "license.md":
            return FileIconConfig(systemName: "doc.seal.fill", color: .green)
        case "package.json":
            return FileIconConfig(systemName: "shippingbox.fill", color: .green)
        case "podfile":
            return FileIconConfig(systemName: "cube.box.fill", color: .red)
        case "dockerfile":
            return FileIconConfig(systemName: "cube.transparent.fill", color: .blue)
        case "makefile":
            return FileIconConfig(systemName: "hammer.fill", color: .orange)
        case ".gitignore":
            return FileIconConfig(systemName: "eye.slash.fill", color: .gray)
        case ".env", ".env.local", ".env.production":
            return FileIconConfig(systemName: "key.fill", color: .yellow)
        default:
            break
        }
        
        // Type-based icons
        switch type {
        case .swift:
            return FileIconConfig(customImage: "swift", color: .orange)
        case .javascript:
            return FileIconConfig(systemName: "curlybraces", color: .yellow)
        case .typescript:
            return FileIconConfig(systemName: "curlybraces.square.fill", color: .blue)
        case .python:
            return FileIconConfig(systemName: "chevron.left.forwardslash.chevron.right", color: Color(red: 0.2, green: 0.5, blue: 0.7))
        case .java:
            return FileIconConfig(systemName: "cup.and.saucer.fill", color: .red)
        case .csharp:
            return FileIconConfig(systemName: "number", color: .purple)
        case .cpp, .c:
            return FileIconConfig(systemName: "c.square.fill", color: Color(red: 0.0, green: 0.4, blue: 0.8))
        case .header:
            return FileIconConfig(systemName: "h.square.fill", color: .indigo)
        case .html:
            return FileIconConfig(systemName: "globe", color: .orange)
        case .css:
            return FileIconConfig(systemName: "paintbrush.fill", color: .blue)
        case .json:
            return FileIconConfig(systemName: "curlybraces.square", color: .green)
        case .xml:
            return FileIconConfig(systemName: "chevron.left.slash.chevron.right", color: .orange)
        case .yaml:
            return FileIconConfig(systemName: "doc.text", color: .red)
        case .markdown:
            return FileIconConfig(systemName: "text.alignleft", color: .gray)
        case .text:
            return FileIconConfig(systemName: "doc.plaintext.fill", color: .secondary)
        case .image:
            return FileIconConfig(systemName: "photo.fill", color: .purple)
        case .video:
            return FileIconConfig(systemName: "video.fill", color: .red)
        case .audio:
            return FileIconConfig(systemName: "speaker.wave.2.fill", color: .pink)
        case .pdf:
            return FileIconConfig(systemName: "doc.richtext.fill", color: .red)
        case .archive:
            return FileIconConfig(systemName: "archivebox.fill", color: .brown)
        case .binary:
            return FileIconConfig(systemName: "gearshape.fill", color: .gray)
        case .configuration:
            return FileIconConfig(systemName: "gear", color: .indigo)
        case .database:
            return FileIconConfig(systemName: "cylinder.fill", color: .teal)
        case .font:
            return FileIconConfig(systemName: "textformat", color: .black)
        case .directory:
            return FileIconConfig(systemName: "folder.fill", color: .blue)
        case .unknown:
            return FileIconConfig(systemName: "doc.fill", color: .secondary)
        }
    }
    
    /// Format file size for display
    public static func formatFileSize(_ bytes: Int64?) -> String {
        guard let bytes = bytes else { return "" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Format date for display
    public static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateComponents([.day], from: date, to: Date()).day! < 7 {
            formatter.dateFormat = "EEEE"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        
        return formatter.string(from: date)
    }
}

/// Configuration for file icons
public struct FileIconConfig {
    let systemName: String?
    let customImage: String?
    let color: Color
    
    init(systemName: String, color: Color) {
        self.systemName = systemName
        self.customImage = nil
        self.color = color
    }
    
    init(customImage: String, color: Color) {
        self.systemName = nil
        self.customImage = customImage
        self.color = color
    }
    
    /// Create the icon view
    @ViewBuilder
    public var iconView: some View {
        if let systemName = systemName {
            Image(systemName: systemName)
                .foregroundColor(color)
        } else if let customImage = customImage {
            Image(customImage)
                .foregroundColor(color)
        } else {
            Image(systemName: "doc.fill")
                .foregroundColor(.secondary)
        }
    }
}

/// View modifier for file icon styling
struct FileIconStyle: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .frame(width: size * 1.5, height: size * 1.2)
    }
}

extension View {
    func fileIconStyle(size: CGFloat = 16) -> some View {
        self.modifier(FileIconStyle(size: size))
    }
}