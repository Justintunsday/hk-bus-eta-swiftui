import Foundation

/// Traditional/Simplified Chinese conversion based on the ICU transliterators,
/// with a memoized cache.
///
/// If a transliterator is unavailable the original text is returned unchanged,
/// so callers always have a safe fallback.
enum ChineseConverter {
    private static let toSimplifiedTransform = StringTransform(rawValue: "Traditional-Simplified")
    private static let toTraditionalTransform = StringTransform(rawValue: "Simplified-Traditional")
    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [String: String] = [:]

    static func simplified(_ text: String) -> String {
        convert(text, transform: toSimplifiedTransform, tag: "S")
    }

    static func traditional(_ text: String) -> String {
        convert(text, transform: toTraditionalTransform, tag: "T")
    }

    private static func convert(_ text: String, transform: StringTransform, tag: String) -> String {
        guard !text.isEmpty else { return text }
        let key = tag + text

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let converted = text.applyingTransform(transform, reverse: false) ?? text

        lock.lock()
        cache[key] = converted
        lock.unlock()
        return converted
    }
}
