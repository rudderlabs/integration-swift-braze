//
//  EcommerceUtil.swift
//  RudderIntegrationBraze
//
//  Maps RudderStack ecommerce track events to Braze recommended `ecommerce.*` events.
//  Opt-in via the `useEcommerceRecommendedEvents` destination flag; when off, this module
//  is never invoked and behavior is unchanged.
//
//  Mirrors the cloud transformer + web JS SDK ports: per-event field mappings, ordered
//  fallback chains, lossless type coercion, and a send-anyway posture (never throws or drops;
//  surfaces missing-required and type-mismatched fields via a single warning each).
//

import Foundation
import RudderStackAnalytics

// MARK: - Braze recommended ecommerce event names

/**
 * Braze recommended ecommerce event names.
 * https://www.braze.com/docs/user_guide/data/activation/events/recommended_events
 */
enum BrazeEcommerceEvent {
    static let productViewed = "ecommerce.product_viewed"
    static let cartUpdated = "ecommerce.cart_updated"
    static let checkoutStarted = "ecommerce.checkout_started"
    static let orderPlaced = "ecommerce.order_placed"
    static let orderRefunded = "ecommerce.order_refunded"
    static let orderCancelled = "ecommerce.order_cancelled"
}

/// On the iOS SDK the Braze `source` field is always `"ios"` (envelope/source derivation is
/// web-only); an incoming `properties.source` is ignored and never echoed into metadata.
private let brazeSource = "ios"

// MARK: - Mapping models

/**
 * The type Braze expects for a recommended-event field. Resolved values are coerced to this
 * type where the conversion is safe and lossless; an un-coercible value is sent verbatim and
 * surfaced via the type-mismatch warning.
 */
enum BrazeFieldType {
    case string
    case integer
    case float
    case array
    case stringArray
}

/**
 * A single field mapping.
 *
 * - Parameters:
 *   - destKey: The Braze field name in the outgoing payload.
 *   - sourceKeys: Ordered fallback chain of source key paths (first present value wins).
 *     Event-level keys carry the `properties.` prefix; per-product keys are bare.
 *   - type: The Braze-expected type, driving coercion and the type-mismatch warning.
 *   - brazeRequired: Whether Braze requires the field (drives the missing-required warning).
 */
struct EcommerceFieldMapping {
    let destKey: String
    let sourceKeys: [String]
    let type: BrazeFieldType
    let brazeRequired: Bool

    init(destKey: String, sourceKeys: [String], type: BrazeFieldType = .string, brazeRequired: Bool = false) {
        self.destKey = destKey
        self.sourceKeys = sourceKeys
        self.type = type
        self.brazeRequired = brazeRequired
    }
}

/**
 * Resolved Braze event + optional action for a given RS event name.
 *
 * - Parameters:
 *   - brazeEvent: The Braze recommended event name (`ecommerce.*`).
 *   - action: The action discriminator, set only for `cart_updated` (`add`/`remove`).
 */
struct EcommerceEventMapping {
    let brazeEvent: String
    let action: String?
}

// MARK: - Event-name → Braze event mapping

/**
 * Case-insensitive RS event name → Braze recommended event. Keys are lowercased/trimmed RS
 * names. `Cart Viewed` and `Cart Updated` are intentionally absent — both fall through to the
 * legacy custom-event path.
 */
private let eventNameToBraze: [String: EcommerceEventMapping] = [
    "product viewed": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.productViewed, action: nil),
    "product added": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.cartUpdated, action: "add"),
    "product removed": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.cartUpdated, action: "remove"),
    "checkout started": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.checkoutStarted, action: nil),
    "order completed": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.orderPlaced, action: nil),
    "order refunded": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.orderRefunded, action: nil),
    "order cancelled": EcommerceEventMapping(brazeEvent: BrazeEcommerceEvent.orderCancelled, action: nil)
]

// MARK: - Per-event field mappings (mirror of the cloud `data/ecommerce/*.json` files)

/// Shared fallback chains reused across checkout/order events.
private let totalValueSources = ["properties.total", "properties.revenue", "properties.value"]
private let totalDiscountsSources = ["properties.discount", "properties.total_discounts"]

private let productViewedMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "product_id", sourceKeys: ["properties.product_id", "properties.sku"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "product_name", sourceKeys: ["properties.name"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "variant_id", sourceKeys: ["properties.variant", "properties.sku", "properties.product_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "price", sourceKeys: ["properties.price"], type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "image_url", sourceKeys: ["properties.image_url"], type: .string, brazeRequired: false),
    EcommerceFieldMapping(destKey: "product_url", sourceKeys: ["properties.url"], type: .string, brazeRequired: false),
    EcommerceFieldMapping(destKey: "type", sourceKeys: ["properties.type"], type: .stringArray, brazeRequired: false)
]

private let cartUpdatedMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "cart_id", sourceKeys: ["properties.cart_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "total_value", sourceKeys: totalValueSources, type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "subtotal_value", sourceKeys: ["properties.subtotal_value"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "tax", sourceKeys: ["properties.tax"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "shipping", sourceKeys: ["properties.shipping"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true)
]

private let checkoutStartedMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "checkout_id", sourceKeys: ["properties.checkout_id", "properties.order_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "cart_id", sourceKeys: ["properties.cart_id"], type: .string, brazeRequired: false),
    EcommerceFieldMapping(destKey: "total_value", sourceKeys: totalValueSources, type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "subtotal_value", sourceKeys: ["properties.subtotal_value"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "tax", sourceKeys: ["properties.tax"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "shipping", sourceKeys: ["properties.shipping"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true)
]

private let orderPlacedMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "order_id", sourceKeys: ["properties.order_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "total_value", sourceKeys: totalValueSources, type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "cart_id", sourceKeys: ["properties.cart_id"], type: .string, brazeRequired: false),
    EcommerceFieldMapping(destKey: "tax", sourceKeys: ["properties.tax"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "shipping", sourceKeys: ["properties.shipping"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "total_discounts", sourceKeys: totalDiscountsSources, type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "subtotal_value", sourceKeys: ["properties.subtotal_value"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "discounts", sourceKeys: ["properties.discounts"], type: .array, brazeRequired: false)
]

private let orderRefundedMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "order_id", sourceKeys: ["properties.order_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "total_value", sourceKeys: totalValueSources, type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "total_discounts", sourceKeys: totalDiscountsSources, type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "discounts", sourceKeys: ["properties.discounts"], type: .array, brazeRequired: false)
]

private let orderCancelledMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "order_id", sourceKeys: ["properties.order_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "total_value", sourceKeys: totalValueSources, type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "currency", sourceKeys: ["properties.currency"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "cancel_reason", sourceKeys: ["properties.cancel_reason", "properties.reason"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "tax", sourceKeys: ["properties.tax"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "shipping", sourceKeys: ["properties.shipping"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "total_discounts", sourceKeys: totalDiscountsSources, type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "subtotal_value", sourceKeys: ["properties.subtotal_value"], type: .float, brazeRequired: false),
    EcommerceFieldMapping(destKey: "discounts", sourceKeys: ["properties.discounts"], type: .array, brazeRequired: false)
]

/// Shared per-product mapping (bare keys — read from each `products[i]` / from `properties`
/// directly for the cart_updated wrap case, no `properties.` prefix).
private let productMapping: [EcommerceFieldMapping] = [
    EcommerceFieldMapping(destKey: "product_id", sourceKeys: ["product_id", "sku"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "product_name", sourceKeys: ["name"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "variant_id", sourceKeys: ["variant", "sku", "product_id"], type: .string, brazeRequired: true),
    EcommerceFieldMapping(destKey: "quantity", sourceKeys: ["quantity"], type: .integer, brazeRequired: true),
    EcommerceFieldMapping(destKey: "price", sourceKeys: ["price"], type: .float, brazeRequired: true),
    EcommerceFieldMapping(destKey: "image_url", sourceKeys: ["image_url"], type: .string, brazeRequired: false),
    EcommerceFieldMapping(destKey: "product_url", sourceKeys: ["url"], type: .string, brazeRequired: false)
]

private let perEventMapping: [String: [EcommerceFieldMapping]] = [
    BrazeEcommerceEvent.productViewed: productViewedMapping,
    BrazeEcommerceEvent.cartUpdated: cartUpdatedMapping,
    BrazeEcommerceEvent.checkoutStarted: checkoutStartedMapping,
    BrazeEcommerceEvent.orderPlaced: orderPlacedMapping,
    BrazeEcommerceEvent.orderRefunded: orderRefundedMapping,
    BrazeEcommerceEvent.orderCancelled: orderCancelledMapping
]

// MARK: - Presence + resolver

/**
 * A value counts as "present" iff it isn't nil/NSNull, an empty String, an empty Array, or an
 * empty Dictionary. `0`/`false` are present. This single predicate drives fallback resolution,
 * the missing-required check, and the final scrub so they can never drift apart.
 */
private func isPresent(_ value: Any?) -> Bool {
    guard let value = value, !(value is NSNull) else { return false }
    if let string = value as? String { return !string.isEmpty }
    if let array = value as? [Any] { return !array.isEmpty }
    if let dictionary = value as? [String: Any] { return !dictionary.isEmpty }
    return true
}

/**
 * Resolve a dotted key path (e.g. `properties.total`, or a bare `quantity`) against a root
 * dictionary, walking nested dictionaries. Returns nil if any segment is missing.
 */
private func valueAtKeyPath(_ keyPath: String, in root: [String: Any]) -> Any? {
    var current: Any? = root
    for segment in keyPath.split(separator: ".").map(String.init) {
        guard let dictionary = current as? [String: Any] else { return nil }
        current = dictionary[segment]
    }
    return current
}

/**
 * For each mapping entry, resolve the first present value across its `sourceKeys` fallback
 * chain. Never throws; unresolved fields are simply absent from the result.
 */
private func constructPayload(from root: [String: Any], mapping: [EcommerceFieldMapping]) -> [String: Any] {
    var result: [String: Any] = [:]
    for entry in mapping {
        for sourceKey in entry.sourceKeys {
            let value = valueAtKeyPath(sourceKey, in: root)
            if isPresent(value), let value = value {
                result[entry.destKey] = value
                break
            }
        }
    }
    return result
}

// MARK: - Coercion + type matching

/// A safe, lossless numeric-string conversion accepts only plain decimal literals (no
/// scientific notation, Infinity, or NaN). Integer additionally forbids a fractional part.
private let floatStringPattern = "^[+-]?(\\d+\\.?\\d*|\\.\\d+)$"
private let integerStringPattern = "^[+-]?\\d+$"

private func matchesPattern(_ string: String, _ pattern: String) -> Bool {
    return string.range(of: pattern, options: .regularExpression) != nil
}

/**
 * Coerce a resolved value to the Braze-expected type when the conversion is safe and lossless;
 * otherwise return it unchanged (the residual mismatch is surfaced by the type-mismatch
 * warning). Three conversions only:
 *   - numeric String  → Float    (`"29.99"` → `29.99`)
 *   - integer String  → Integer  (`"2"` → `2`; `"2.5"`/`"2.0"` left as-is)
 *   - Number          → String   (`12345` → `"12345"`)
 * `Bool` is never stringified (only `Number → String`); arrays/objects are never coerced.
 * Values arrive as native Swift types (the SDK's `rawDictionary` disambiguates `NSNumber`
 * into `Bool`/`Int`/`Double`), so `as?` checks are unambiguous.
 */
private func coerce(_ value: Any, to type: BrazeFieldType) -> Any {
    switch type {
    case .string:
        if value is String { return value }
        if value is Bool { return value }
        if let intValue = value as? Int { return String(intValue) }
        if let doubleValue = value as? Double { return String(doubleValue) }
        return value
    case .float:
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if matchesPattern(trimmed, floatStringPattern), let doubleValue = Double(trimmed) {
                return doubleValue
            }
        }
        return value
    case .integer:
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if matchesPattern(trimmed, integerStringPattern), let intValue = Int(trimmed) {
                return intValue
            }
        }
        return value
    case .array, .stringArray:
        return value
    }
}

/// Coerce every mapped field present in `payload` to its Braze-expected type, in place.
private func applyCoercions(to payload: inout [String: Any], mapping: [EcommerceFieldMapping]) {
    for entry in mapping {
        guard let value = payload[entry.destKey] else { continue }
        payload[entry.destKey] = coerce(value, to: entry.type)
    }
}

/**
 * Whether `value` already matches the Braze-expected type. A numeric written as a String does
 * NOT match a numeric type, so an un-coercible value still warns. `0`/`false` are valid; `Bool`
 * never satisfies a numeric type.
 */
private func matchesType(_ value: Any, _ type: BrazeFieldType) -> Bool {
    switch type {
    case .string:
        return value is String
    case .integer:
        if value is Bool { return false }
        if value is Int { return true }
        if let doubleValue = value as? Double { return doubleValue.isFinite && doubleValue.truncatingRemainder(dividingBy: 1) == 0 }
        return false
    case .float:
        if value is Bool { return false }
        return value is Int || value is Double
    case .stringArray:
        return value as? [String] != nil
    case .array:
        return value as? [Any] != nil
    }
}

private func typeLabel(_ type: BrazeFieldType) -> String {
    switch type {
    case .string: return "string"
    case .integer: return "integer"
    case .float: return "float"
    case .array: return "array"
    case .stringArray: return "stringArray"
    }
}

// MARK: - Metadata routing

/**
 * The subset of `source` whose keys aren't in `consumed`, with non-present values scrubbed.
 * Used to derive the `metadata` pass-through.
 */
private func unmappedKeys(from source: [String: Any], consumed: Set<String>) -> [String: Any] {
    var result: [String: Any] = [:]
    for (key, value) in source where !consumed.contains(key) {
        if isPresent(value) {
            result[key] = value
        }
    }
    return result
}

/// Source keys referenced by a per-product mapping (bare keys — no `properties.` prefix).
private func consumedProductKeys(_ mapping: [EcommerceFieldMapping]) -> Set<String> {
    var consumed = Set<String>()
    for entry in mapping {
        for sourceKey in entry.sourceKeys {
            consumed.insert(sourceKey)
        }
    }
    return consumed
}

/**
 * Message-property keys "consumed" by the event-level mapping (so they don't duplicate into
 * metadata): the `properties.`-prefixed source keys (prefix stripped), `source` (always
 * derived), `products` for product-bearing events, and — for cart_updated without an explicit
 * `products[]` — the per-product field keys folded into `products[0]`.
 */
private func consumedTopLevelKeys(brazeEvent: String, mapping: [EcommerceFieldMapping], hasProducts: Bool, properties: [String: Any]) -> Set<String> {
    var consumed: Set<String> = ["source"]
    let prefix = "properties."

    for entry in mapping {
        for sourceKey in entry.sourceKeys where sourceKey.hasPrefix(prefix) {
            consumed.insert(String(sourceKey.dropFirst(prefix.count)))
        }
    }

    if hasProducts {
        consumed.insert("products")
    }

    // cart_updated folds top-level product fields into products[0] ONLY when no explicit
    // `products[]` is provided; mark those keys consumed so they don't duplicate into metadata.
    if brazeEvent == BrazeEcommerceEvent.cartUpdated && properties["products"] as? [Any] == nil {
        for key in consumedProductKeys(productMapping) {
            consumed.insert(key)
        }
    }

    return consumed
}

// MARK: - products[]

/**
 * Build the `products[]` array.
 * - cart_updated WITHOUT an explicit `products[]`: read top-level product fields directly from
 *   `properties` into a 1-element array. No per-product metadata — the source object is
 *   `properties` itself, so unmapped keys flow through the event-level metadata pass instead.
 * - all other cases: map each `properties.products[i]`, routing unmapped per-product keys to
 *   `products[i].metadata`.
 */
private func buildProductsArray(properties: [String: Any], brazeEvent: String) -> [[String: Any]] {
    let isCartUpdated = brazeEvent == BrazeEcommerceEvent.cartUpdated
    let rawProductsArray = properties["products"] as? [Any]

    if isCartUpdated && rawProductsArray == nil {
        var product = constructPayload(from: properties, mapping: productMapping)
        applyCoercions(to: &product, mapping: productMapping)
        let scrubbed = scrub(product)
        return scrubbed.isEmpty ? [] : [scrubbed]
    }

    let consumed = consumedProductKeys(productMapping)
    let rawProducts = rawProductsArray ?? []
    return rawProducts.compactMap { rawItem in
        let item = rawItem as? [String: Any] ?? [:]
        var product = constructPayload(from: item, mapping: productMapping)
        applyCoercions(to: &product, mapping: productMapping)
        var scrubbed = scrub(product)
        let metadata = unmappedKeys(from: item, consumed: consumed)
        if !metadata.isEmpty {
            scrubbed["metadata"] = metadata
        }
        return scrubbed.isEmpty ? nil : scrubbed
    }
}

// MARK: - Validation collectors

/**
 * Braze-required fields missing from the constructed payload — event-level and per-product.
 * An empty `products[]` on a product-bearing event is reported as a missing `products` field.
 */
private func collectMissingRequiredFields(mapping: [EcommerceFieldMapping], hasProducts: Bool, payload: [String: Any]) -> [String] {
    var missing: [String] = []

    for entry in mapping where entry.brazeRequired && !isPresent(payload[entry.destKey]) {
        missing.append(entry.destKey)
    }

    if hasProducts {
        let products = payload["products"] as? [[String: Any]] ?? []
        if products.isEmpty {
            missing.append("products")
        } else {
            var missingProductFields = Set<String>()
            for product in products {
                for entry in productMapping where entry.brazeRequired && !isPresent(product[entry.destKey]) {
                    missingProductFields.insert("products.\(entry.destKey)")
                }
            }
            missing.append(contentsOf: missingProductFields.sorted())
        }
    }

    return missing
}

/// Whether a present value doesn't match its Braze-expected type. Missing values are the
/// missing-required warning's job and must not double-warn here.
private func isTypeMismatch(_ value: Any?, _ type: BrazeFieldType) -> Bool {
    guard let value = value, isPresent(value) else { return false }
    return !matchesType(value, type)
}

/**
 * Mapped fields whose (already-coerced) value is present but still doesn't match Braze's
 * expected type — event-level and per-product. Labels read `destKey (expected <type>)`.
 */
private func collectTypeMismatchedFields(mapping: [EcommerceFieldMapping], hasProducts: Bool, payload: [String: Any]) -> [String] {
    var mismatched: [String] = []

    for entry in mapping where isTypeMismatch(payload[entry.destKey], entry.type) {
        mismatched.append("\(entry.destKey) (expected \(typeLabel(entry.type)))")
    }

    if hasProducts {
        let products = payload["products"] as? [[String: Any]] ?? []
        var mismatchedProductFields = Set<String>()
        for product in products {
            for entry in productMapping where isTypeMismatch(product[entry.destKey], entry.type) {
                mismatchedProductFields.insert("products.\(entry.destKey) (expected \(typeLabel(entry.type)))")
            }
        }
        mismatched.append(contentsOf: mismatchedProductFields.sorted())
    }

    return mismatched
}

/// Remove non-present values (nil/NSNull/empty String/Array/Dictionary) from the top level.
private func scrub(_ dictionary: [String: Any]) -> [String: Any] {
    return dictionary.filter { isPresent($0.value) }
}

// MARK: - Public surface

/**
 * Resolve the Braze recommended event for an RS event name. Returns nil for unmapped events
 * (caller falls back to the legacy path). Matching is case-insensitive on the trimmed name.
 */
func getEcommerceMapping(_ eventName: String) -> EcommerceEventMapping? {
    return eventNameToBraze[eventName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
}

/**
 * Build the `properties` object for a Braze recommended ecommerce event.
 *
 * Algorithm:
 * 1. Map event-level fields via `constructPayload`, coercing each to its Braze type.
 * 2. For product-bearing events, build `products[]` (single-product wrap for cart_updated
 *    without an explicit `products[]`; iterate `properties.products` otherwise).
 * 3. Set `source` (always `"ios"`) and `action` when present.
 * 4. Route unmapped event-level keys to `metadata` (excluding `source`, the consumed mapping
 *    keys, `products`, and `action` when set).
 * 5. Emit one warning listing any missing Braze-required field.
 * 6. Emit one warning listing any field whose value type doesn't match Braze's schema after
 *    safe coercion (the value is still sent as-is).
 *
 * Never throws on data shape; the warnings + the (still-sent) payload are the contract.
 */
func buildEcommerceEventProperties(properties: [String: Any], brazeEvent: String, action: String?) -> [String: Any] {
    let mapping = perEventMapping[brazeEvent] ?? []
    let hasProducts = brazeEvent != BrazeEcommerceEvent.productViewed

    // Step 1: event-level field mapping, each value coerced to its Braze type.
    var payload = constructPayload(from: ["properties": properties], mapping: mapping)
    applyCoercions(to: &payload, mapping: mapping)

    // Step 2: products[] (skipped for product_viewed — flat, single-product event).
    if hasProducts {
        payload["products"] = buildProductsArray(properties: properties, brazeEvent: brazeEvent)
    }

    // Step 3: source + action.
    payload["source"] = brazeSource
    if let action = action {
        payload["action"] = action
    }

    // Step 4: route unmapped event-level keys to metadata. Exclude `action` when set so a
    // caller-provided `properties.action` can't conflict with the one set in Step 3.
    var consumed = consumedTopLevelKeys(brazeEvent: brazeEvent, mapping: mapping, hasProducts: hasProducts, properties: properties)
    if action != nil {
        consumed.insert("action")
    }
    let metadata = unmappedKeys(from: properties, consumed: consumed)
    if !metadata.isEmpty {
        payload["metadata"] = metadata
    }

    // Step 5: single warning for any missing Braze-required field.
    let missingFields = collectMissingRequiredFields(mapping: mapping, hasProducts: hasProducts, payload: payload)
    if !missingFields.isEmpty {
        LoggerAnalytics.warn("BrazeIntegration: \(brazeEvent): missing recommended Braze-required field(s): \(missingFields.joined(separator: ", ")). Event sent anyway.")
    }

    // Step 6: single warning for any field whose type still doesn't match Braze's schema.
    let mismatchedFields = collectTypeMismatchedFields(mapping: mapping, hasProducts: hasProducts, payload: payload)
    if !mismatchedFields.isEmpty {
        LoggerAnalytics.warn("BrazeIntegration: \(brazeEvent): type-mismatched field(s) (sent as-is): \(mismatchedFields.joined(separator: ", ")).")
    }

    return scrub(payload)
}
