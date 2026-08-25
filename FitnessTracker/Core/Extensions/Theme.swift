//
//  Theme.swift
//  Strict dark-mode palette. No blue accents anywhere in the app.
//

import SwiftUI

enum AppTheme {
    static let background = Color(hex: 0x000000)
    static let card = Color(hex: 0x1C1C1E)
    static let cardElevated = Color(hex: 0x2C2C2E)
    static let accent = Color(hex: 0x34C759)      // Emerald / neon green
    static let warning = Color(hex: 0xFF9500)      // Warm orange — streaks/alerts
    static let danger = Color(hex: 0xFF3B30)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: 0x8E8E93)
    static let separator = Color(hex: 0x38383A)

    static let cornerRadius: CGFloat = 18
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// Reusable dark card container used across all tabs.
struct CardView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}

/// Applies the app's forced dark appearance + RTL environment.
struct AppRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(.dark)
            .environment(\.layoutDirection, .rightToLeft)
            .tint(AppTheme.accent)
    }
}

extension View {
    func appRootStyle() -> some View { modifier(AppRootModifier()) }
}
