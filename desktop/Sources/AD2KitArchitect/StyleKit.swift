import SwiftUI

struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .padding(20)
            .background(Color.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1) }
    }
}

extension Text {
    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(Color.coral)
    }
}

extension Label where Title == Text, Icon == Image {
    func statusLine(color: Color) -> some View {
        self.font(.caption).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}

extension Color {
    static let canvas = Color(red: 0.074, green: 0.070, blue: 0.066)
    static let card = Color(red: 0.118, green: 0.112, blue: 0.105)
    static let coral = Color(red: 1.0, green: 0.38, blue: 0.25)
}
