import CoreGraphics
import Foundation

/// A user-defined window size/position, stored as fractions (0–1) of a
/// screen's work area so it adapts to any display.
struct CustomSize: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static func makeDefault() -> CustomSize {
        CustomSize(name: "New Size", x: 0.2, y: 0.2, width: 0.6, height: 0.6)
    }

    func frame(in workArea: CGRect) -> CGRect {
        CGRect(
            x: workArea.minX + CGFloat(x) * workArea.width,
            y: workArea.minY + CGFloat(y) * workArea.height,
            width: CGFloat(width) * workArea.width,
            height: CGFloat(height) * workArea.height
        ).integral
    }
}
