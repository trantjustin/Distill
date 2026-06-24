import SwiftUI

struct CoverColors {
    static func color(for name: String) -> Color {
        switch name {
        case "blue":    return .blue
        case "purple":  return .purple
        case "teal":    return .teal
        case "green":   return .green
        case "orange":  return .orange
        case "pink":    return .pink
        case "red":     return .red
        default:        return .indigo
        }
    }
}
