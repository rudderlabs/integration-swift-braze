//
//  BrazeIntegration.swift
//  RudderIntegrationBraze
//
//  Swift integration for Braze destination
//

import Foundation
import BrazeKit
import RudderStackAnalytics

/**
 * Braze Integration for RudderStack Swift SDK
 */
public class BrazeIntegration: IntegrationPlugin, StandardIntegration {

    // MARK: - Required Protocol Properties

    /**
     Plugin type for Braze integration - always terminal
     */
    public var pluginType: PluginType = .terminal

    /**
     Reference to the analytics instance
     */
    public var analytics: Analytics?

    /**
     Integration key identifier
     */
    public var key: String = "Braze"

    // MARK: - Private Properties

    private let brazeAdapter: BrazeAdapter
    private var supportDedup: Bool = false
    private var previousIdentifyPayload: IdentifyEvent?
    private var prevExternalId: String?
    private var connectionMode: ConnectionMode = .cloud

    // MARK: - Initialization

    init(brazeAdapter: BrazeAdapter) {
        self.brazeAdapter = brazeAdapter
    }

    public convenience init() {
        self.init(brazeAdapter: DefaultBrazeAdapter())
    }

    // MARK: - Required Protocol Methods

    /**
     * Creates and initializes the Braze integration
     */
    public func create(destinationConfig: [String: Any]) throws {
        // Extract configuration values
        guard let apiToken = destinationConfig["appKey"] as? String, !apiToken.isEmpty else {
            LoggerAnalytics.error("API Token is invalid. Aborting Braze SDK initialization.")
            throw BrazeIntegrationError.invalidAPIToken
        }

        // Set deduplication support
        supportDedup = destinationConfig["supportDedup"] as? Bool ?? false

        // Determine connection mode
        connectionMode = getConnectionMode(config: destinationConfig)

        // Configure Braze endpoint based on data center
        let endpoint = try getBrazeEndpoint(from: destinationConfig)

        // Create Braze configuration with endpoint
        let configuration = Braze.Configuration(apiKey: apiToken, endpoint: endpoint)

        // Set log level based on RudderStack log level - will be set after Braze instance creation

        // Initialize Braze instance using adapter
        guard brazeAdapter.initialize(configuration: configuration) else {
            LoggerAnalytics.error("Failed to initialize Braze SDK")
            throw BrazeIntegrationError.initializationFailed
        }

        // Set log level based on RudderStack log level
        mapRudderLogLevelToBraze(LoggerAnalytics.logLevel)

        // Set user alias using anonymous ID if available
        if let analytics = analytics, let anonymousId = analytics.anonymousId {
            setUserAlias(anonymousId)
        }

        LoggerAnalytics.debug("Braze SDK initialized successfully")
    }

    /**
     * Returns the destination instance
     * Required by IntegrationPlugin protocol
     */
    public func getDestinationInstance() -> Any? {
        return brazeAdapter.getDestinationInstance()
    }

    /**
     * Updates destination configuration dynamically (Swift-specific feature)
     */
    public func update(destinationConfig: [String: Any]) throws {
        // For Braze, we typically don't need to recreate the instance for config updates
        // Update configuration properties that can be changed at runtime
        supportDedup = destinationConfig["supportDedup"] as? Bool ?? false
        connectionMode = getConnectionMode(config: destinationConfig)

        LoggerAnalytics.debug("Braze configuration updated")
    }

    // MARK: - Event Methods

    /**
     * Handles identify events
     * Handle identify events and update user attributes
     */
    public func identify(payload: IdentifyEvent) {
        // Only process events in device mode
        guard connectionMode == .device else { return }

        // Process identify event directly (thread safety handled by Braze SDK)
        processIdentifyEvent(payload: payload)
    }

    /**
     * Handles track events
     * Handle track events and log them to Braze
     */
    public func track(payload: TrackEvent) {
        // Only process events in device mode
        guard connectionMode == .device else { return }

        let eventName = payload.event
        let properties = payload.properties?.dictionary?.rawDictionary ?? [:]

        if eventName == "Install Attributed" {
            handleInstallAttributedEvent(properties: properties)
        } else if eventName == "Order Completed" {
            handleOrderCompletedEvent(properties: properties)
        } else {
            // Regular custom event
            brazeAdapter.logCustomEvent(name: eventName, properties: properties)
            LoggerAnalytics.debug("Braze logCustomEvent: \(eventName) withProperties: \(properties)")
        }
    }

    // MARK: - Lifecycle Methods

    /**
     * Flushes pending events
     * Request immediate data flush to Braze
     */
    public func flush() {
        brazeAdapter.requestImmediateDataFlush()
        LoggerAnalytics.debug("Braze requestImmediateDataFlush")
    }
}

// MARK: - Private Helper Methods

private extension BrazeIntegration {

    /**
     * Sets user alias using anonymous ID
     */
    func setUserAlias(_ anonymousId: String) {
        _ = brazeAdapter.addUserAlias(anonymousId, label: "rudder_id")
        LoggerAnalytics.debug("Braze user alias set with anonymous ID")
    }

    /**
     * Gets external ID from message context
     */
    func getExternalId(from payload: IdentifyEvent) -> String? {
        guard let externalIds = payload.context?["externalIds"] as? [[String: Any]] else {
            return nil
        }

        for externalIdDict in externalIds {
            if let type = externalIdDict["type"] as? String,
               type == "brazeExternalId",
               let id = externalIdDict["id"] as? String {
                return id
            }
        }
        return nil
    }

    /**
     * Processes identify event with user profile updates
     */
    func processIdentifyEvent(payload: IdentifyEvent) {
        // Handle external ID or user ID for changeUser
        let currExternalId = getExternalId(from: payload)
        let currUserId = payload.userId

        if let externalId = currExternalId {
            if prevExternalId == nil || externalId != prevExternalId {
                brazeAdapter.changeUser(userId: externalId)
                LoggerAnalytics.debug("Identify: Braze changeUser with externalId")
            }
        } else if let userId = currUserId {
            let prevUserId = previousIdentifyPayload?.userId
            if prevUserId == nil || userId != prevUserId {
                brazeAdapter.changeUser(userId: userId)
                LoggerAnalytics.debug("Identify: Braze changeUser with userId")
            }
        }

        // Store current external ID for comparison
        prevExternalId = currExternalId

        // Process user traits
        if let traits = payload.context?["traits"] as? [String: Any] {
            processTraits(traits: traits)
        }

        // Store current payload for deduplication
        previousIdentifyPayload = payload
    }

    /**
     * Processes user traits and maps them to Braze user properties
     */
    func processTraits(traits: [String: Any]) {
        for (key, value) in traits {
            let updatedValue = needUpdate(key: key, currentValue: value)
            guard let validValue = updatedValue else { continue }

            switch key {
            case "lastname":
                if let lastName = validValue as? String {
                    brazeAdapter.setUserAttribute(.lastName(lastName))
                    LoggerAnalytics.debug("Identify: Braze user lastname")
                }
            case "email":
                if let email = validValue as? String {
                    brazeAdapter.setUserAttribute(.email(email))
                    LoggerAnalytics.debug("Identify: Braze email")
                }
            case "firstname":
                if let firstName = validValue as? String {
                    brazeAdapter.setUserAttribute(.firstName(firstName))
                    LoggerAnalytics.debug("Identify: Braze firstname")
                }
            case "birthday":
                if let birthday = validValue as? Date {
                    brazeAdapter.setUserAttribute(.dateOfBirth(birthday))
                    LoggerAnalytics.debug("Identify: Braze date of birth")
                }
            case "gender":
                if let gender = validValue as? String {
                    let lowercaseGender = gender.lowercased()
                    if lowercaseGender == "m" || lowercaseGender == "male" {
                        brazeAdapter.setUserAttribute(.gender(Braze.User.Gender.male))
                        LoggerAnalytics.debug("Identify: Braze gender")
                    } else if lowercaseGender == "f" || lowercaseGender == "female" {
                        brazeAdapter.setUserAttribute(.gender(Braze.User.Gender.female))
                        LoggerAnalytics.debug("Identify: Braze gender")
                    }
                }
            case "phone":
                if let phone = validValue as? String {
                    brazeAdapter.setUserAttribute(.phoneNumber(phone))
                    LoggerAnalytics.debug("Identify: Braze phone")
                }
            case "address":
                if let address = validValue as? [String: Any] {
                    if let city = address["city"] as? String {
                        brazeAdapter.setUserAttribute(.homeCity(city))
                        LoggerAnalytics.debug("Identify: Braze homecity")
                    }
                    if let country = address["country"] as? String {
                        brazeAdapter.setUserAttribute(.country(country))
                        LoggerAnalytics.debug("Identify: Braze country")
                    }
                }
            default:
                // Handle custom attributes (ignore standard traits)
                let standardTraits = ["birthday", "anonymousId", "gender", "phone", "address", "firstname", "lastname", "email"]
                if !standardTraits.contains(key) {
                    setCustomAttribute(key: key, value: validValue)
                }
            }
        }
    }

    /**
     * Sets custom attribute based on value type
     */
    func setCustomAttribute(key: String, value: Any) {
        switch value {
        case let stringValue as String:
            brazeAdapter.setCustomAttribute(key: key, value: stringValue)
            LoggerAnalytics.debug("Braze setCustomAttribute: \(key) stringValue")
        case let dateValue as Date:
            brazeAdapter.setCustomAttribute(key: key, value: dateValue)
            LoggerAnalytics.debug("Braze setCustomAttribute: \(key) dateValue")
        case let boolValue as Bool:
            brazeAdapter.setCustomAttribute(key: key, value: boolValue)
            LoggerAnalytics.debug("Braze setCustomAttribute: \(key) boolValue")
        case let intValue as Int:
            brazeAdapter.setCustomAttribute(key: key, value: intValue)
            LoggerAnalytics.debug("Braze setCustomAttribute: \(key) intValue")
        case let doubleValue as Double:
            brazeAdapter.setCustomAttribute(key: key, value: doubleValue)
            LoggerAnalytics.debug("Braze setCustomAttribute: \(key) doubleValue")
        case let arrayValue as [Any]:
            // Braze doesn't support array custom attributes, convert to JSON string
            if let jsonData = try? JSONSerialization.data(withJSONObject: arrayValue),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                brazeAdapter.setCustomAttribute(key: key, value: jsonString)
                LoggerAnalytics.debug("Braze setCustomAttribute: \(key) arrayValue (as JSON string)")
            } else {
                LoggerAnalytics.debug("Failed to convert array to JSON for key: \(key)")
            }
        default:
            LoggerAnalytics.debug("Unsupported custom attribute type for key: \(key)")
        }
    }

    /**
     * Handles Install Attributed event with attribution data
     */
    func handleInstallAttributedEvent(properties: [String: Any]) {
        if let campaign = properties["campaign"] as? [String: Any] {
            let attributionData = Braze.User.AttributionData(
                network: campaign["source"] as? String,
                campaign: campaign["name"] as? String,
                adGroup: campaign["ad_group"] as? String,
                creative: campaign["ad_creative"] as? String
            )
            brazeAdapter.setUserAttribute(.attributionData(attributionData))
            LoggerAnalytics.debug("Braze setAttributionData")
        } else {
            // Fallback to regular custom event
            brazeAdapter.logCustomEvent(name: "Install Attributed", properties: properties)
            LoggerAnalytics.debug("Braze logCustomEvent: Install Attributed withProperties")
        }
    }

    /**
     * Handles Order Completed event with purchase tracking
     */
    func handleOrderCompletedEvent(properties: [String: Any]) {
        guard let purchaseList = getPurchaseList(from: properties), !purchaseList.isEmpty else {
            return
        }

        for purchase in purchaseList {
            guard let price = purchase.price else { continue }
            brazeAdapter.logPurchase(
                productId: purchase.productId,
                currency: purchase.currency,
                price: NSDecimalNumber(decimal: price).doubleValue,
                quantity: purchase.quantity,
                properties: purchase.properties
            )
            LoggerAnalytics.debug("Braze logPurchase: \(purchase.productId) currency: \(purchase.currency) price: \(price) quantity: \(purchase.quantity)")
        }
    }

    /**
     * Extracts purchase list from Order Completed properties
     */
    func getPurchaseList(from properties: [String: Any]) -> [BrazePurchase]? {
        guard let productList = properties["products"] as? [[String: Any]], !productList.isEmpty else {
            return nil
        }

        let currency = (properties["currency"] as? String)?.count == 3 ? properties["currency"] as! String : "USD"

        let ignoredKeys = ["product_id", "quantity", "price", "products", "time", "event_name", "currency"]
        var otherProperties: [String: Any] = [:]
        for (key, value) in properties {
            if !ignoredKeys.contains(key) {
                otherProperties[key] = value
            }
        }

        var purchaseList: [BrazePurchase] = []
        for product in productList {
            var purchase = BrazePurchase()
            var productProperties = otherProperties

            for (key, value) in product {
                switch key {
                case "product_id":
                    purchase.productId = "\(value)"
                case "quantity":
                    if let quantity = value as? Int {
                        purchase.quantity = quantity
                    } else if let quantityString = value as? String, let quantity = Int(quantityString) {
                        purchase.quantity = quantity
                    }
                case "price":
                    purchase.price = revenueDecimal(from: value)
                default:
                    productProperties[key] = value
                }
            }

            purchase.currency = currency
            purchase.properties = productProperties

            // Only add if we have required fields
            if !purchase.productId.isEmpty && purchase.price != nil {
                purchaseList.append(purchase)
            }
        }

        return purchaseList.isEmpty ? nil : purchaseList
    }

    /**
     * Converts revenue value to Decimal
     */
    func revenueDecimal(from value: Any?) -> Decimal? {
        guard let value = value else { return nil }

        if let stringValue = value as? String {
            return Decimal(string: stringValue)
        } else if let decimalValue = value as? Decimal {
            return decimalValue
        } else if let numberValue = value as? NSNumber {
            return numberValue.decimalValue
        }
        return nil
    }

    /**
     * Determines if a trait value needs updating (for deduplication)
     */
    func needUpdate(key: String, currentValue: Any) -> Any? {
        guard supportDedup, let previousPayload = previousIdentifyPayload,
              let prevTraits = previousPayload.context?["traits"] as? [String: Any],
              let prevValue = prevTraits[key] else {
            return currentValue
        }

        // Special handling for address comparison
        if key == "address",
           let currAddress = currentValue as? [String: Any],
           let prevAddress = prevValue as? [String: Any] {
            return compareAddress(current: currAddress, previous: prevAddress) ? nil : currentValue
        }

        // Special handling for date comparison
        if key == "birthday",
           let currDate = currentValue as? Date,
           let prevDate = prevValue as? Date {
            return currDate == prevDate ? nil : currentValue
        }

        // General equality check
        if let currValue = currentValue as? NSObject,
           let prevValueObj = prevValue as? NSObject,
           currValue.isEqual(prevValueObj) {
            return nil
        }

        return currentValue
    }

    /**
     * Compares address objects for equality
     */
    func compareAddress(current: [String: Any], previous: [String: Any]) -> Bool {
        let currCity = current["city"] as? String
        let prevCity = previous["city"] as? String
        let currCountry = current["country"] as? String
        let prevCountry = previous["country"] as? String

        return currCity == prevCity && currCountry == prevCountry
    }

    /**
     * Determines connection mode from configuration
     */
    func getConnectionMode(config: [String: Any]) -> ConnectionMode {
        guard let connectionModeString = config["connectionMode"] as? String else {
            return .cloud
        }

        switch connectionModeString.lowercased() {
        case "hybrid":
            return .hybrid
        case "device":
            return .device
        default:
            return .cloud
        }
    }

    /**
     * Maps RudderStack log level to Braze log level
     */
    func mapRudderLogLevelToBraze(_ rudderLogLevel: LogLevel) {
        let brazeLogLevel: Braze.Configuration.Logger.Level
        switch rudderLogLevel {
        case .none:
            brazeLogLevel = .disabled
        case .error:
            brazeLogLevel = .error
        case .warn:
            brazeLogLevel = .error  // Braze doesn't have warn, use error
        case .info:
            brazeLogLevel = .info
        case .debug:
            brazeLogLevel = .debug
        case .verbose:
            brazeLogLevel = .debug  // Braze doesn't have verbose, use debug
        }
        brazeAdapter.setLogLevel(brazeLogLevel)
    }

    /**
     * Gets Braze endpoint based on data center configuration
     */
    func getBrazeEndpoint(from config: [String: Any]) throws -> String {
        guard let dataCenter = config["dataCenter"] as? String,
              !dataCenter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BrazeIntegrationError.invalidDataCenter
        }

        let trimmedDataCenter = dataCenter.trimmingCharacters(in: .whitespacesAndNewlines)

        switch trimmedDataCenter {
        case "US-01": return "sdk.iad-01.braze.com"
        case "US-02": return "sdk.iad-02.braze.com"
        case "US-03": return "sdk.iad-03.braze.com"
        case "US-04": return "sdk.iad-04.braze.com"
        case "US-05": return "sdk.iad-05.braze.com"
        case "US-06": return "sdk.iad-06.braze.com"
        case "US-07": return "sdk.iad-07.braze.com"
        case "US-08": return "sdk.iad-08.braze.com"
        case "EU-01": return "sdk.fra-01.braze.eu"
        case "EU-02": return "sdk.fra-02.braze.eu"
        case "AU-01": return "sdk.au-01.braze.com"
        default: throw BrazeIntegrationError.invalidDataCenter
        }
    }
}

// MARK: - Supporting Types

/**
 Connection mode enum for integration configuration
 */
private enum ConnectionMode {
    case hybrid
    case cloud
    case device
}

/**
 Purchase model for Braze purchase events
 */
private struct BrazePurchase {
    var productId: String = ""
    var quantity: Int = 1
    var price: Decimal?
    var properties: [String: Any] = [:]
    var currency: String = "USD"
}

/**
 Integration-specific errors
 */
public enum BrazeIntegrationError: Error {
    case invalidAPIToken
    case invalidDataCenter
    case initializationFailed

    var localizedDescription: String {
        switch self {
        case .invalidAPIToken:
            return "API Token is invalid or missing"
        case .invalidDataCenter:
            return "Invalid data center configuration"
        case .initializationFailed:
            return "Failed to initialize Braze SDK"
        }
    }
}
