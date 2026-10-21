
import SwiftUI

enum AppTheme {
    @AppStorage("vexo_theme_mode") private static var storedMode = "light"

    static var isBlackMode: Bool {
        storedMode == "black"
    }

    static let accent = Color(red: 0.12, green: 0.48, blue: 0.95)
    static let secondaryAccent = Color(red: 0.36, green: 0.72, blue: 1.0)

    static var pageBackground: Color {
        isBlackMode ? Color.black : Color.white
    }

    static var consoleBackground: Color {
        isBlackMode
            ? Color(red: 0.025, green: 0.035, blue: 0.065)
            : Color(red: 0.96, green: 0.975, blue: 1.0)
    }

    static var referenceCard: Color {
        isBlackMode
            ? Color(red: 0.055, green: 0.075, blue: 0.12)
            : Color(red: 0.94, green: 0.965, blue: 1.0)
    }

    static var primaryText: Color {
        isBlackMode ? .white : .black
    }

    static var secondaryText: Color {
        isBlackMode ? .white.opacity(0.68) : .black.opacity(0.62)
    }

    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
    }
}
