import SwiftUI

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .padding(18)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color.line, lineWidth: 1) }
    }
}

extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.orangeAccent)
    }
}

extension Label where Title == Text, Icon == Image {
    func statusLine(color: Color) -> some View {
        self.font(.caption).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

extension Color {
    static let canvas = Color(red: 0.055, green: 0.054, blue: 0.050)
    static let card = Color(red: 0.105, green: 0.103, blue: 0.095)
    static let kitSlot = Color(red: 0.092, green: 0.091, blue: 0.084)
    static let controlPanel = Color(red: 0.82, green: 0.78, blue: 0.69)
    static let ink = Color(red: 0.15, green: 0.145, blue: 0.13)
    static let line = Color.white.opacity(0.14)
    static let orangeAccent = Color(red: 0.92, green: 0.31, blue: 0.12)
    static let coral = orangeAccent
}
