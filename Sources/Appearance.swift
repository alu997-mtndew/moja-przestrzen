import SwiftUI
import UIKit

enum SpacePalette {
    static let background = adaptive(0xF7F4EF, 0x1B2123)
    static let surface = adaptive(0xFFFDF9, 0x242C2F)
    static let ink = adaptive(0x353D42, 0xF1EEE7)
    static let muted = adaptive(0x545F64, 0xBAC4C3)
    static let border = adaptive(0xE5DED4, 0x3B4749)
    static let sage = adaptive(0xB6C7B0, 0x35473C)
    static let lavender = adaptive(0xDAD1E9, 0x453D55)
    static let peach = adaptive(0xE6C6BE, 0x503C3B)
    static let accent = adaptive(0x406052, 0xC4D9C1)
    static let destructive = adaptive(0x953E42, 0xA54B50)

    static func tint(for segment: Segment) -> Color {
        switch segment {
        case .title, .daily, .archive: sage
        case .weekly, .ideas: lavender
        case .problems, .behavior, .commandments: peach
        }
    }

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255,
                alpha: 1
            )
        })
    }
}

struct SpaceButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    var fill = SpacePalette.surface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SpacePalette.ink)
            .background(fill, in: RoundedRectangle(cornerRadius: 16))
            .opacity(enabled ? (configuration.isPressed ? 0.76 : 1) : 0.38)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct EmptyCard: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(SpacePalette.ink)
            if let detail { Text(detail).font(.footnote).foregroundStyle(SpacePalette.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .spaceCard(fill: SpacePalette.surface.opacity(0.64))
        .spaceListRow()
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func spaceCard(fill: Color = SpacePalette.surface) -> some View {
        padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20).fill(fill)
                    .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(SpacePalette.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    func spaceListRow() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func spaceList() -> some View {
        listStyle(.plain)
            .environment(\.defaultMinListHeaderHeight, 44)
            .scrollContentBackground(.hidden)
            .background(SpacePalette.background)
    }

    func spaceSectionTitle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(SpacePalette.muted)
            .textCase(nil)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}
