import SwiftUI

enum AppMetrics {
    static let designWidth: CGFloat = 393
    static let designHeight: CGFloat = 852
}

enum AppColors {
    static let bgTop = Color(hex: 0x2C291F)
    static let bgBottom = Color(hex: 0x1D1D1D)

    static let gold = Color(hex: 0xEFD8B2)
    static let goldSoft = Color(hex: 0xF8DBB9)
    static let muted = Color(hex: 0x939393)
    static let placeholder = Color(hex: 0x656052)

    static let field = Color(hex: 0x201C17)
    static let fieldStroke = Color(hex: 0xF5C370, alpha: 0.2)

    static let greenTop = Color(hex: 0x2F8D00)
    static let greenBottom = Color(hex: 0x236601)

    static let glass = Color(hex: 0x8F6F58, alpha: 0.31)
    static let glassStrong = Color(hex: 0x8F6F58, alpha: 0.46)
    static let card = Color(hex: 0x8F6F58, alpha: 0.15)

    static let white = Color.white
    static let black = Color.black
}

enum AppTypography {
    enum Weight {
        case regular
        case medium
        case semibold
        case bold
        case extraBold
        case black

        fileprivate var fontName: String {
            switch self {
            case .regular:
                "Alegreya-Regular"
            case .medium:
                "Alegreya-Medium"
            case .semibold:
                "Alegreya-SemiBold"
            case .bold:
                "Alegreya-Bold"
            case .extraBold:
                "Alegreya-ExtraBold"
            case .black:
                "Alegreya-Black"
            }
        }
    }

    enum ItalicWeight {
        case regular
        case medium
        case semibold
        case bold
        case extraBold
        case black

        fileprivate var fontName: String {
            switch self {
            case .regular:
                "Alegreya-Italic"
            case .medium:
                "Alegreya-MediumItalic"
            case .semibold:
                "Alegreya-SemiBoldItalic"
            case .bold:
                "Alegreya-BoldItalic"
            case .extraBold:
                "Alegreya-ExtraBoldItalic"
            case .black:
                "Alegreya-BlackItalic"
            }
        }
    }

    static func font(_ weight: Weight = .regular, _ size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    static func italic(_ weight: ItalicWeight = .regular, _ size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    static func regular(_ size: CGFloat) -> Font {
        font(.regular, size)
    }

    static func medium(_ size: CGFloat) -> Font {
        font(.medium, size)
    }

    static func semibold(_ size: CGFloat) -> Font {
        font(.semibold, size)
    }

    static func bold(_ size: CGFloat) -> Font {
        font(.bold, size)
    }

    static func extraBold(_ size: CGFloat) -> Font {
        font(.extraBold, size)
    }

    static func black(_ size: CGFloat) -> Font {
        font(.black, size)
    }
}

extension View {
    func appFont(_ weight: AppTypography.Weight = .regular, _ size: CGFloat) -> some View {
        font(AppTypography.font(weight, size))
    }

    func appItalicFont(_ weight: AppTypography.ItalicWeight = .regular, _ size: CGFloat) -> some View {
        font(AppTypography.italic(weight, size))
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
