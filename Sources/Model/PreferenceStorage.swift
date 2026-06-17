import Foundation

/// Shared UserDefaults read helpers for the single-value preference stores.
///
/// These collapse the three init-time patterns that the per-pref stores
/// otherwise hand-roll identically: decoding a string-backed enum with a
/// fallback default, clamping an integer to an allowed set/range, and
/// first-run seeding of a bool (where `UserDefaults.bool` returns `false`
/// for a missing key and would silently clobber an intended `true` default).
///
/// The write side stays inline in each store's `didSet` — a one-line
/// `UserDefaults.standard.set(_:forKey:)` is clearer there than behind a call.
enum Pref {
    /// Decode a string-backed enum, falling back to `default` for missing or
    /// unrecognized raw values.
    static func enumValue<T: RawRepresentable>(key: String, default fallback: T) -> T
    where T.RawValue == String {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        return T(rawValue: raw) ?? fallback
    }

    /// Read an integer, falling back to `default` unless the stored value is a
    /// member of `allowed`.
    static func int(key: String, default fallback: Int, allowed: [Int]) -> Int {
        let stored = UserDefaults.standard.integer(forKey: key)
        return allowed.contains(stored) ? stored : fallback
    }

    /// Seed `default` on first run, then read the integer back, clamping out
    /// of-range values (e.g. a direct UserDefaults edit) to `default`.
    static func int(key: String, default fallback: Int, range: ClosedRange<Int>) -> Int {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) == nil {
            defaults.set(fallback, forKey: key)
        }
        let stored = defaults.integer(forKey: key)
        return range.contains(stored) ? stored : fallback
    }

    /// Seed `default` on first run, then read the bool back. Avoids the
    /// `UserDefaults.bool` "missing key reads as false" footgun for prefs that
    /// default to `true`.
    static func seededBool(key: String, default fallback: Bool) -> Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: key) == nil {
            defaults.set(fallback, forKey: key)
        }
        return defaults.bool(forKey: key)
    }
}
