//
//  Utils.swift
//  RudderIntegrationBraze
//
//  Utility functions and extensions for Braze Integration
//

import Foundation
import RudderStackAnalytics

/**
 * Parses the dictionary to the specified type T.
 *
 * This function sanitizes the dictionary to handle non-JSON-serializable types (Date, URL, NSURL, NSNull)
 * before serialization to ensure compatibility with JSONSerialization.
 */
internal func parse<T: Decodable>(_ dictionary: [String: Any]) -> T? {
    guard !dictionary.isEmpty else {
        LoggerAnalytics.debug("BrazeIntegration: The configuration is empty.")
        return nil
    }

    do {
        // Sanitize dictionary to convert Date/URL/NSURL to strings before JSON serialization
        let jsonData = try JSONSerialization.data(withJSONObject: dictionary.objCSanitized)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode(T.self, from: jsonData)
    } catch {
        LoggerAnalytics.error("BrazeIntegration: Failed to parse configuration: \(error)")
        return nil
    }
}

/**
 * Extension function to parse a dictionary into StandardProperties.
 *
 * - Returns: StandardProperties object parsed from the dictionary.
 */
internal func getStandardProperties(_ properties: [String: Any]) -> StandardProperties {
    return parse(properties) ?? StandardProperties()
}

/**
 * Extension function to filter the standard properties from the dictionary.
 *
 * **NOTE**: If there are multiple keys with the same name in the `products` array, only the last one will be considered.
 *
 * - Parameters:
 *   - properties: The properties dictionary to filter
 *   - rootKeys: The list of keys to be filtered from the root level.
 *   - productKeys: The list of keys to be filtered from the products array.
 * - Returns: Dictionary with the filtered values.
 */
internal func filter(
    properties: [String: Any],
    rootKeys: [String],
    productKeys: [String] = []
) -> [String: Any] {
    let filteredRootProperties = filterKeys(from: properties, keys: rootKeys)

    var filteredProductProperties: [String: Any] = [:]
    if let products = properties["products"] as? [[String: Any]] {
        filteredProductProperties = filterKeysFromArray(products: products, keys: productKeys)
    }

    return filteredRootProperties.merging(filteredProductProperties) { _, new in new }
}

/**
 * Extension function to filter the keys from the dictionary.
 *
 * - Parameters:
 *   - from: The dictionary to filter
 *   - keys: The list of keys to be filtered.
 * - Returns: Dictionary with the filtered keys.
 */
private func filterKeys(from dictionary: [String: Any], keys: [String]) -> [String: Any] {
    return dictionary.filter { !keys.contains($0.key) }
}

/**
 * Extension function to filter the keys from the array of dictionaries.
 *
 * **NOTE**: If there are multiple keys with the same name in the array, only the last one will be considered.
 *
 * - Parameters:
 *   - products: The array of product dictionaries
 *   - keys: The list of keys to be filtered.
 * - Returns: Dictionary with the filtered keys.
 */
private func filterKeysFromArray(products: [[String: Any]], keys: [String]) -> [String: Any] {
    var result: [String: Any] = [:]
    for product in products {
        for (key, value) in product where !keys.contains(key) {
            result[key] = value
        }
    }
    return result
}

/**
 * Extension function to get the `brazeExternalId` if it exists, otherwise the userId.
 */
internal func getExternalIdOrUserId(from traits: IdentifyTraits) -> String? {
    if let externalId = traits.context.brazeExternalId, !externalId.isEmpty {
        return externalId
    }
    return traits.userId
}

/**
 * Extension to convert IdentifyEvent to IdentifyTraits.
 *
 * - Parameter event: The IdentifyEvent to convert
 * - Returns: The IdentifyTraits object parsed from the IdentifyEvent.
 */
internal func toIdentifyTraits(from event: IdentifyEvent) -> IdentifyTraits {
    var context = Context()
    let contextDict = event.context?.rawDictionary ?? [:]

    // Parse full context from event (not just traits) to capture externalId
    if !contextDict.isEmpty {
        context = parse(contextDict) ?? Context()
    }

    // Get custom traits by filtering out standard trait keys
    var customTraits: [String: Any] = [:]
    if let traitsDict = contextDict["traits"] as? [String: Any] {
        customTraits = filterKeys(from: traitsDict, keys: Traits.getKeysAsList())
    }

    return IdentifyTraits(
        userId: event.userId,
        context: context,
        customTraits: customTraits
    )
}

/**
 * Returns a new IdentifyTraits object with updated traits or nil if they are the same.
 *
 * - Parameters:
 *   - currentTraits: The current traits
 *   - previousTraits: The previous traits to compare against
 * - Returns: The new traits object with de-duped values
 */
internal func deDupe(currentTraits: IdentifyTraits, previousTraits: IdentifyTraits?) -> IdentifyTraits {
    guard let previousTraits = previousTraits else {
        return currentTraits
    }

    let currentContextTraits = currentTraits.context.traits
    let previousContextTraits = previousTraits.context.traits

    return IdentifyTraits(
        userId: takeIfDifferent(currentTraits.userId, previousTraits.userId),
        context: Context(
            traits: Traits(
                email: takeIfDifferent(currentContextTraits.email, previousContextTraits.email),
                firstName: takeIfDifferent(currentContextTraits.firstName, previousContextTraits.firstName),
                lastName: takeIfDifferent(currentContextTraits.lastName, previousContextTraits.lastName),
                gender: takeIfDifferent(currentContextTraits.gender, previousContextTraits.gender),
                phone: takeIfDifferent(currentContextTraits.phone, previousContextTraits.phone),
                address: takeIfDifferent(currentContextTraits.address, previousContextTraits.address),
                birthday: takeIfDifferent(currentContextTraits.birthday, previousContextTraits.birthday)
            ),
            externalId: takeIfDifferent(currentTraits.context.externalId, previousTraits.context.externalId)
        ),
        customTraits: getDeDupedCustomTraits(
            deDupeEnabled: true,
            newCustomTraits: currentTraits.customTraits,
            oldCustomTraits: previousTraits.customTraits
        )
    )
}

/**
 * Returns the new value if it is different from the old value, otherwise nil.
 */
private func takeIfDifferent<T: Equatable>(_ new: T?, _ old: T?) -> T? {
    guard let new = new else { return nil }
    return new != old ? new : nil
}

/**
 * Returns deduplicated custom traits by comparing new and old traits.
 */
internal func getDeDupedCustomTraits(
    deDupeEnabled: Bool,
    newCustomTraits: [String: Any],
    oldCustomTraits: [String: Any]
) -> [String: Any] {
    guard !newCustomTraits.isEmpty else { return [:] }
    guard !oldCustomTraits.isEmpty else { return newCustomTraits }
    guard deDupeEnabled else { return newCustomTraits }

    var result: [String: Any] = [:]
    for (key, newValue) in newCustomTraits {
        if let oldValue = oldCustomTraits[key] {
            // Compare values - this is a simplified comparison
            if !areValuesEqual(newValue, oldValue) {
                result[key] = newValue
            }
        } else {
            result[key] = newValue
        }
    }
    return result
}

/**
 * Compares two values for equality.
 */
private func areValuesEqual(_ value1: Any, _ value2: Any) -> Bool {
    // Handle common types
    if let v1 = value1 as? String, let v2 = value2 as? String {
        return v1 == v2
    }
    if let v1 = value1 as? NSNumber, let v2 = value2 as? NSNumber {
        return v1 == v2
    }
    if let v1 = value1 as? Bool, let v2 = value2 as? Bool {
        return v1 == v2
    }
    if let v1 = value1 as? Date, let v2 = value2 as? Date {
        return v1 == v2
    }

    // Fallback to NSObject comparison
    if let obj1 = value1 as? NSObject, let obj2 = value2 as? NSObject {
        return obj1.isEqual(obj2)
    }

    return false
}

/// Centralized date formatters for consistent date handling across the integration.
internal enum DateFormatters {

    /// ISO8601 formatter with fractional seconds for custom attribute date parsing.
    /// Format: yyyy-MM-dd'T'HH:mm:ss.SSS'Z' (e.g., 2024-01-15T10:30:45.123Z)
    /// Uses nonisolated(unsafe) for Swift 6 concurrency compatibility.
    nonisolated(unsafe) static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
