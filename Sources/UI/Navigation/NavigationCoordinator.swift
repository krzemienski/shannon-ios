//
//  NavigationCoordinator.swift
//  ClaudeCode
//
//  Navigation state management and deep linking support
//

import SwiftUI

/// Navigation destinations for chat tab
public enum ChatDestination: Hashable {
    case conversation(id: String)
    case newConversation
    case settings
    case toolDetail(id: String)
    case search
}

/// Navigation destinations for projects tab
public enum ProjectDestination: Hashable {
    case project(id: String)
    case newProject
    case fileEditor(projectId: String, path: String)
    case terminal(projectId: String)
    case settings(projectId: String)
}

/// Navigation destinations for terminal tab
public enum TerminalDestination: Hashable {
    case session(id: String)
    case newSession
    case history
    case settings
}

/// Navigation destinations for settings tab
public enum SettingsDestination: Hashable {
    case api
    case appearance
    case ssh
    case data
    case about
    case licenses
}

/// Manages navigation state across the app
@MainActor
public final class NavigationCoordinator: ObservableObject {
    // MARK: - Navigation Paths
    
    @Published public var chatPath = NavigationPath()
    @Published public var projectsPath = NavigationPath()
    @Published public var terminalPath = NavigationPath()
    @Published public var settingsPath = NavigationPath()
    
    // MARK: - Sheet Presentation
    
    @Published public var presentedSheet: SheetType?
    @Published public var presentedFullScreenCover: FullScreenCoverType?
    
    // MARK: - Alert State
    
    @Published public var alertItem: AlertItem?
    
    // MARK: - Tab Selection
    
    @Published public var selectedTab: Int = 0
    
    // MARK: - Sheet Types
    
    public enum SheetType: Identifiable {
        case newChat
        case newProject
        case newTerminalSession
        case shareContent(content: ShareContent)
        case imageViewer(image: UIImage)
        case pdfViewer(url: URL)
        case codeEditor(content: String, language: String)
        case export(data: Data, filename: String)
        
        public var id: String {
            switch self {
            case .newChat: return "newChat"
            case .newProject: return "newProject"
            case .newTerminalSession: return "newTerminalSession"
            case .shareContent: return "shareContent"
            case .imageViewer: return "imageViewer"
            case .pdfViewer: return "pdfViewer"
            case .codeEditor: return "codeEditor"
            case .export: return "export"
            }
        }
    }
    
    // MARK: - Full Screen Cover Types
    
    public enum FullScreenCoverType: Identifiable {
        case onboarding
        case authentication
        case projectWizard
        
        public var id: String {
            switch self {
            case .onboarding: return "onboarding"
            case .authentication: return "authentication"
            case .projectWizard: return "projectWizard"
            }
        }
    }
    
    // MARK: - Share Content
    
    public struct ShareContent {
        let title: String
        let items: [Any]
    }
    
    // MARK: - Alert Item
    
    public struct AlertItem: Identifiable {
        public let id = UUID()
        let title: String
        let message: String?
        let dismissButton: Alert.Button
        let primaryButton: Alert.Button?
        let secondaryButton: Alert.Button?
        
        public init(
            title: String,
            message: String? = nil,
            dismissButton: Alert.Button = .default(Text("OK")),
            primaryButton: Alert.Button? = nil,
            secondaryButton: Alert.Button? = nil
        ) {
            self.title = title
            self.message = message
            self.dismissButton = dismissButton
            self.primaryButton = primaryButton
            self.secondaryButton = secondaryButton
        }
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to chat destination
    public func navigateToChat(_ destination: ChatDestination) {
        selectedTab = 0
        chatPath.append(destination)
    }
    
    /// Navigate to project destination
    public func navigateToProject(_ destination: ProjectDestination) {
        selectedTab = 1
        projectsPath.append(destination)
    }
    
    /// Navigate to terminal destination
    public func navigateToTerminal(_ destination: TerminalDestination) {
        selectedTab = 2
        terminalPath.append(destination)
    }
    
    /// Navigate to settings destination
    public func navigateToSettings(_ destination: SettingsDestination) {
        selectedTab = 3
        settingsPath.append(destination)
    }
    
    // MARK: - Pop Navigation
    
    /// Pop to root of current tab
    public func popToRoot() {
        switch selectedTab {
        case 0:
            chatPath = NavigationPath()
        case 1:
            projectsPath = NavigationPath()
        case 2:
            terminalPath = NavigationPath()
        case 3:
            settingsPath = NavigationPath()
        default:
            break
        }
    }
    
    /// Pop one level in current tab
    public func pop() {
        switch selectedTab {
        case 0:
            if !chatPath.isEmpty {
                chatPath.removeLast()
            }
        case 1:
            if !projectsPath.isEmpty {
                projectsPath.removeLast()
            }
        case 2:
            if !terminalPath.isEmpty {
                terminalPath.removeLast()
            }
        case 3:
            if !settingsPath.isEmpty {
                settingsPath.removeLast()
            }
        default:
            break
        }
    }
    
    // MARK: - Sheet Presentation
    
    /// Present a sheet
    public func presentSheet(_ sheet: SheetType) {
        presentedSheet = sheet
    }
    
    /// Dismiss current sheet
    public func dismissSheet() {
        presentedSheet = nil
    }
    
    /// Present a full screen cover
    public func presentFullScreenCover(_ cover: FullScreenCoverType) {
        presentedFullScreenCover = cover
    }
    
    /// Dismiss current full screen cover
    public func dismissFullScreenCover() {
        presentedFullScreenCover = nil
    }
    
    // MARK: - Alert Presentation
    
    /// Show an alert
    public func showAlert(_ alert: AlertItem) {
        alertItem = alert
    }
    
    /// Show error alert
    public func showError(_ error: Error) {
        alertItem = AlertItem(
            title: "Error",
            message: error.localizedDescription,
            dismissButton: .default(Text("OK"))
        )
    }
    
    /// Show confirmation alert
    public func showConfirmation(
        title: String,
        message: String?,
        confirmTitle: String = "Confirm",
        confirmAction: @escaping () -> Void
    ) {
        alertItem = AlertItem(
            title: title,
            message: message,
            dismissButton: .cancel(),
            primaryButton: .destructive(Text(confirmTitle), action: confirmAction)
        )
    }
    
    // MARK: - Deep Linking
    
    /// Handle deep link URL
    public func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        
        switch components.host {
        case "chat":
            handleChatDeepLink(components)
        case "project":
            handleProjectDeepLink(components)
        case "terminal":
            handleTerminalDeepLink(components)
        case "settings":
            handleSettingsDeepLink(components)
        default:
            break
        }
    }
    
    private func handleChatDeepLink(_ components: URLComponents) {
        selectedTab = 0
        
        guard let path = components.path.components(separatedBy: "/").last else {
            return
        }
        
        switch path {
        case "new":
            presentSheet(.newChat)
        default:
            if !path.isEmpty {
                navigateToChat(.conversation(id: path))
            }
        }
    }
    
    private func handleProjectDeepLink(_ components: URLComponents) {
        selectedTab = 1
        
        guard let path = components.path.components(separatedBy: "/").last else {
            return
        }
        
        switch path {
        case "new":
            presentSheet(.newProject)
        default:
            if !path.isEmpty {
                navigateToProject(.project(id: path))
            }
        }
    }
    
    private func handleTerminalDeepLink(_ components: URLComponents) {
        selectedTab = 2
        
        guard let path = components.path.components(separatedBy: "/").last else {
            return
        }
        
        switch path {
        case "new":
            presentSheet(.newTerminalSession)
        default:
            if !path.isEmpty {
                navigateToTerminal(.session(id: path))
            }
        }
    }
    
    private func handleSettingsDeepLink(_ components: URLComponents) {
        selectedTab = 3
        
        guard let path = components.path.components(separatedBy: "/").last else {
            return
        }
        
        switch path {
        case "api":
            navigateToSettings(.api)
        case "appearance":
            navigateToSettings(.appearance)
        case "ssh":
            navigateToSettings(.ssh)
        case "data":
            navigateToSettings(.data)
        case "about":
            navigateToSettings(.about)
        default:
            break
        }
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply navigation coordinator to view
    func withNavigationCoordinator(_ coordinator: NavigationCoordinator) -> some View {
        self
            .sheet(item: coordinator.$presentedSheet) { sheet in
                sheetContent(for: sheet)
            }
            .fullScreenCover(item: coordinator.$presentedFullScreenCover) { cover in
                fullScreenCoverContent(for: cover)
            }
            .alert(item: coordinator.$alertItem) { alert in
                Alert(
                    title: Text(alert.title),
                    message: alert.message.map { Text($0) },
                    dismissButton: alert.dismissButton
                )
            }
    }
    
    @ViewBuilder
    private func sheetContent(for sheet: NavigationCoordinator.SheetType) -> some View {
        switch sheet {
        case .newChat:
            NewConversationView(coordinator: nil)
        case .newProject:
            NewProjectView()
        case .newTerminalSession:
            Text("New Terminal Session") // Placeholder
        case .shareContent(let content):
            ShareSheet(activityItems: content.items)
        case .imageViewer(let image):
            ImageViewer(image: image)
        case .pdfViewer(let url):
            PDFViewerView()
        case .codeEditor(let content, let language):
            CodeEditorView()
        case .export(let data, let filename):
            ExportDataView()
        }
    }
    
    @ViewBuilder
    private func fullScreenCoverContent(for cover: NavigationCoordinator.FullScreenCoverType) -> some View {
        switch cover {
        case .onboarding:
            OnboardingView(onComplete: {})
        case .authentication:
            AuthenticationView()
        case .projectWizard:
            Text("Project Wizard") // Placeholder
        }
    }
}

// Note: Bindings are now created directly using $ syntax on @Published properties

// MARK: - Helper Views

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ImageViewer: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}