import SwiftUI
import UIKit

// 沿用網頁版的暖紙色 + 金色 accent，深色模式自動切換
extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let gold = Color(hex: 0xD4A017)
    static let goldBright = Color(hex: 0xF6D860)
    static let paper = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.059, blue: 0.063, alpha: 1)   // #0f0f10
            : UIColor(red: 0.969, green: 0.965, blue: 0.953, alpha: 1)   // #f7f6f3
    })
    static let panel = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.094, green: 0.094, blue: 0.106, alpha: 1)   // #18181b
            : UIColor.white
    })
}

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.panel)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

extension View {
    func panel() -> some View { modifier(PanelStyle()) }
}

struct TagPill: View {
    let text: String
    let colorHex: UInt32

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color(hex: colorHex).opacity(0.12))
            .foregroundColor(Color(hex: colorHex))
            .clipShape(Capsule())
    }
}
