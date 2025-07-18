import Foundation

extension Array {
    /// Returns the element at the given index if it is within bounds, otherwise nil.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
