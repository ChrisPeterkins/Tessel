import CoreGraphics

extension CGRect {
    func approximatelyEquals(_ other: CGRect, tolerance: CGFloat = 1.5) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }

    var area: CGFloat {
        isNull || isEmpty ? 0 : width * height
    }
}
