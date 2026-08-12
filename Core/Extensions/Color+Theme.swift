import SwiftUI

/// Central design-token palette for the app. Black + Yellow, Islamic-inspired, premium.
enum AppTheme {
    static let primaryBlack = Color(hex: 0x0A0A0A)
    static let secondaryBlack = Color(hex: 0x151515)
    static let primaryYellow = Color(hex: 0xFFD21F)
    static let lightYellow = Color(hex: 0xFFE66B)
    static let white = Color(hex: 0xFFFFFF)
    static let secondaryText = Color(hex: 0xB8B8B8)
    static let success = Color(hex: 0x38C172)
    static let error = Color(hex: 0xE74C3C)

    static let cardCornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 18
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

/// Reusable premium card container used across the app.
struct PrayerCard<Content: View>: View {
    @ViewBuilder var content: Content
    var highlighted: Bool = false

    var body: some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(AppTheme.secondaryBlack)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                            .strokeBorder(highlighted ? AppTheme.primaryYellow.opacity(0.6) : .clear, lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            )
    }
}
