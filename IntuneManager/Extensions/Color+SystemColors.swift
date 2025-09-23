import SwiftUI

extension Color {
    /// Converts system color name strings to SwiftUI Colors
    /// Used for compatibility with color names from data models
    static func systemColor(named name: String) -> Color {
        switch name {
        case "systemGreen": return .green
        case "systemRed": return .red
        case "systemOrange": return .orange
        case "systemBlue": return .blue
        case "systemGray": return .gray
        case "systemYellow": return .yellow
        case "systemPurple": return .purple
        case "systemPink": return .pink
        case "systemTeal": return .teal
        case "systemIndigo": return .indigo
        default: return .gray
        }
    }
}