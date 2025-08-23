//
//  Icons.swift
//  ClaudeCode
//
//  SF Symbols catalog
//

import SwiftUI

/// SF Symbols catalog organized by category
public struct Icons {
    
    // MARK: - Navigation
    public struct Navigation {
        public static let back = "chevron.left"
        public static let forward = "chevron.right"
        public static let up = "chevron.up"
        public static let down = "chevron.down"
        public static let menu = "line.3.horizontal"
        public static let close = "xmark"
        public static let home = "house.fill"
        public static let search = "magnifyingglass"
        public static let filter = "line.3.horizontal.decrease.circle"
        public static let sort = "arrow.up.arrow.down"
    }
    
    // MARK: - Actions
    public struct Actions {
        public static let add = "plus"
        public static let addCircle = "plus.circle.fill"
        public static let edit = "pencil"
        public static let delete = "trash"
        public static let save = "square.and.arrow.down"
        public static let share = "square.and.arrow.up"
        public static let copy = "doc.on.doc"
        public static let paste = "doc.on.clipboard"
        public static let refresh = "arrow.clockwise"
        public static let download = "arrow.down.circle"
        public static let upload = "arrow.up.circle"
        public static let play = "play.fill"
        public static let pause = "pause.fill"
        public static let stop = "stop.fill"
    }
    
    // MARK: - Status
    public struct Status {
        public static let success = "checkmark.circle.fill"
        public static let error = "xmark.circle.fill"
        public static let warning = "exclamationmark.triangle.fill"
        public static let info = "info.circle.fill"
        public static let loading = "circle.dotted"
        public static let pending = "clock.fill"
        public static let completed = "checkmark.seal.fill"
        public static let cancelled = "xmark.octagon.fill"
    }
    
    // MARK: - Communication
    public struct Communication {
        public static let message = "message.fill"
        public static let chat = "bubble.left.and.bubble.right.fill"
        public static let send = "paperplane.fill"
        public static let notification = "bell.fill"
        public static let email = "envelope.fill"
        public static let phone = "phone.fill"
        public static let video = "video.fill"
        public static let mic = "mic.fill"
        public static let micOff = "mic.slash.fill"
    }
    
    // MARK: - Files
    public struct Files {
        public static let file = "doc.fill"
        public static let folder = "folder.fill"
        public static let code = "chevron.left.forwardslash.chevron.right"
        public static let terminal = "terminal.fill"
        public static let image = "photo.fill"
        public static let video = "play.rectangle.fill"
        public static let pdf = "doc.richtext"
        public static let zip = "doc.zipper"
        public static let cloud = "icloud.fill"
    }
    
    // MARK: - System
    public struct System {
        public static let settings = "gearshape.fill"
        public static let profile = "person.circle.fill"
        public static let security = "lock.fill"
        public static let privacy = "hand.raised.fill"
        public static let appearance = "paintbrush.fill"
        public static let network = "network"
        public static let battery = "battery.100"
        public static let wifi = "wifi"
        public static let bluetooth = "bluetooth"
    }
    
    // MARK: - Development
    public struct Development {
        public static let bug = "ladybug.fill"
        public static let branch = "arrow.triangle.branch"
        public static let commit = "circle.fill"
        public static let merge = "arrow.triangle.merge"
        public static let pullRequest = "arrow.up.arrow.down.square.fill"
        public static let issue = "exclamationmark.circle.fill"
        public static let deployment = "rocket.fill"
        public static let database = "cylinder.fill"
        public static let api = "app.connected.to.app.below.fill"
    }
    
    // MARK: - AI
    public struct AI {
        public static let sparkles = "sparkles"
        public static let brain = "brain"
        public static let cpu = "cpu.fill"
        public static let robot = "figure.wave"
        public static let magic = "wand.and.stars"
        public static let auto = "wand.and.rays"
    }
}

// MARK: - Icon View
public struct IconView: View {
    let name: String
    let size: CGFloat
    let color: Color
    
    public init(
        _ name: String,
        size: CGFloat = 20,
        color: Color = .primary
    ) {
        self.name = name
        self.size = size
        self.color = color
    }
    
    public var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(color)
            .frame(width: size * 1.5, height: size * 1.5)
    }
}

// MARK: - Animated Icon View
public struct AnimatedIcon: View {
    let name: String
    let size: CGFloat
    let color: Color
    let animation: Animation
    
    @State private var isAnimating = false
    
    public init(
        _ name: String,
        size: CGFloat = 20,
        color: Color = .primary,
        animation: Animation = .easeInOut(duration: 1).repeatForever()
    ) {
        self.name = name
        self.size = size
        self.color = color
        self.animation = animation
    }
    
    public var body: some View {
        IconView(name, size: size, color: color)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.8 : 1.0)
            .animation(animation, value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Icon Button
public struct IconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let color: Color
    let backgroundColor: Color?
    
    public init(
        icon: String,
        size: CGFloat = 20,
        color: Color = .primary,
        backgroundColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            IconView(icon, size: size, color: color)
                .padding(8)
                .background(backgroundColor ?? Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}