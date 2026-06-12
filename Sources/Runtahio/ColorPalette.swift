import SwiftUI
import RuntahioCore

/// Maps `RadialSegment`s to colors for the Runtah Map.
///
/// Color encodes **file type** (category hue), depth modulates lightness, and selection/
/// hover add emphasis. A calm, cool "bloom" palette — deliberately not DaisyDisk's bright
/// orange ring. Adapts to light/dark mode.
enum RuntahPalette {
    static func color(
        for segment: RadialSegment,
        colorScheme: ColorScheme,
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        color(
            hue: segment.hue, category: segment.category, depth: segment.depth,
            colorScheme: colorScheme, isSelected: isSelected, isHovered: isHovered)
    }

    static func color(
        for tile: TreemapTile,
        colorScheme: ColorScheme,
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        color(
            hue: tile.hue, category: tile.category, depth: tile.depth,
            colorScheme: colorScheme, isSelected: isSelected, isHovered: isHovered)
    }

    /// Shared color logic: hue from file type, lightness modulated by depth, plus
    /// selection/hover emphasis. Adapts to light/dark mode.
    static func color(
        hue: Double, category: FileCategory, depth: Int,
        colorScheme: ColorScheme, isSelected: Bool, isHovered: Bool
    ) -> Color {
        let isDark = colorScheme == .dark
        var sat: Double = category.isNeutral ? 0.06 : (isDark ? 0.42 : 0.46)

        let baseBrightness: Double = isDark ? 0.52 : 0.78
        let depthStep = Double(max(0, depth - 1)) * (isDark ? 0.07 : -0.06)
        var brightness = clamp(baseBrightness + depthStep, 0.30, 0.95)

        if isSelected {
            sat = clamp(sat + 0.22, 0, 1)
            brightness = clamp(brightness + (isDark ? 0.16 : -0.04), 0.25, 1)
        } else if isHovered {
            brightness = clamp(brightness + (isDark ? 0.09 : 0.06), 0.25, 1)
        }

        return Color(hue: hue, saturation: sat, brightness: brightness)
    }

    /// Swatch color for a category, for legends/inspector chips.
    static func swatch(for category: FileCategory, colorScheme: ColorScheme) -> Color {
        let isDark = colorScheme == .dark
        let sat: Double = category.isNeutral ? 0.06 : (isDark ? 0.42 : 0.5)
        let brightness: Double = isDark ? 0.6 : 0.72
        return Color(hue: category.hue, saturation: sat, brightness: brightness)
    }

    static func stroke(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.55)
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }
}
