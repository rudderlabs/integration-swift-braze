//
//  BrazeAdapter.swift
//  integration-swift-braze
//
//  Created by Vishal Gupta on 21/11/25.
//

import Foundation
import BrazeKit

import RudderStackAnalytics

protocol BrazeAdapter {
    func initSDK(apiKey: String, endpoint: String, logLevel: LogLevel) -> Bool
    func addUserAlias(_ alias: String, label: String)
    func changeUser(userId: String)
    func setTraits(deDupedTraits: IdentifyTraits)
    func setUserAttribute(_ attribute: BrazeUserAttribute)
    func logPurchase(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?)
    func logCustomEvent(name: String, properties: [String: Any]?)
    func requestImmediateDataFlush()
    func getDestinationInstance() -> Any?
}

/**
 * Enum to represent different Braze user attributes
 */
enum BrazeUserAttribute {
    case firstName(String)
    case lastName(String)
    case email(String)
    case dateOfBirth(Date)
    case gender(Braze.User.Gender)
    case phoneNumber(String)
    case homeCity(String)
    case country(String)
    case attributionData(Braze.User.AttributionData)
}

class DefaultBrazeAdapter: BrazeAdapter {

    private var braze: Braze?

    init() {}

    func initSDK(apiKey: String, endpoint: String, logLevel: LogLevel) -> Bool {
        guard braze == nil else { return true }

        let configuration = Braze.Configuration(apiKey: apiKey, endpoint: endpoint)
        setLogLevel(rudderLogLevel: logLevel, brazeConfiguration: configuration)

        let braze = Braze(configuration: configuration)
        self.braze = braze
        LoggerAnalytics.verbose("BrazeAdapter: Braze SDK initialized")
        return true
    }

    private func setLogLevel(rudderLogLevel: LogLevel, brazeConfiguration: Braze.Configuration) {
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
        brazeConfiguration.logger.level = brazeLogLevel
    }

    func addUserAlias(_ alias: String, label: String) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot add user alias.")
            return
        }
        braze.user.add(alias: alias, label: label)
        LoggerAnalytics.verbose("BrazeAdapter: Added user alias '\(alias)' with label '\(label)'")
    }

    func changeUser(userId: String) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot change user.")
            return
        }
        braze.changeUser(userId: userId)
    }

    func setTraits(deDupedTraits: IdentifyTraits) {
        let traits = deDupedTraits.context.traits

        if let birthday = traits.birthday {
            setUserAttribute(.dateOfBirth(birthday))
        }
        if let email = traits.email {
            setUserAttribute(.email(email))
        }
        if let firstName = traits.firstName {
            setUserAttribute(.firstName(firstName))
        }
        if let lastName = traits.lastName {
            setUserAttribute(.lastName(lastName))
        }
        if let gender = traits.gender {
            setGender(gender: gender)
        }
        if let phone = traits.phone {
            setUserAttribute(.phoneNumber(phone))
        }
        if let address = traits.address {
            setAddress(address: address)
        }

        setCustomTraits(customTraits: deDupedTraits.customTraits)
        LoggerAnalytics.verbose("BrazeAdapter: Set user traits")
    }

    private func setGender(gender: String) {
        switch gender.uppercased() {
        case "M", "MALE":
            setUserAttribute(.gender(.male))
        case "F", "FEMALE":
            setUserAttribute(.gender(.female))
        default:
            LoggerAnalytics.error("BrazeAdapter: Unsupported gender: \(gender)")
        }
    }

    private func setAddress(address: Address) {
        if let city = address.city {
            setUserAttribute(.homeCity(city))
        }
        if let country = address.country {
            setUserAttribute(.country(country))
        }
    }

    private func setCustomTraits(customTraits: [String: Any]) {
        for (key, value) in customTraits {
            setCustomAttribute(key: key, value: value)
        }
    }

    private func setCustomAttribute(key: String, value: Any) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot set custom attribute.")
            return
        }

        switch value {
            case let boolValue as Bool:
                braze.user.setCustomAttribute(key: key, value: boolValue)
            case let intValue as Int:
                braze.user.setCustomAttribute(key: key, value: intValue)
            case let doubleValue as Double:
                braze.user.setCustomAttribute(key: key, value: doubleValue)
            case let stringValue as String:
                handleStringValue(braze: braze, key: key, value: stringValue)
            case let dateValue as Date:
                braze.user.setCustomAttribute(key: key, value: dateValue)
            default:
                logUnsupportedType(key: key, value: value)
        }
    }

    private func handleStringValue(braze: Braze, key: String, value: String) {
        // Only try ISO8601 format for custom attributes (matching Kotlin's tryDateConversion)
        if let date = DateFormatters.iso8601WithFractionalSeconds.date(from: value) {
            braze.user.setCustomAttribute(key: key, value: date)
        } else {
            braze.user.setCustomAttribute(key: key, value: value)
        }
    }

    private func logUnsupportedType(key: String, value: Any) {
        LoggerAnalytics.debug("BrazeAdapter: Unsupported type for key '\(key)': \(type(of: value))")
    }

    func setUserAttribute(_ attribute: BrazeUserAttribute) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot set user attribute.")
            return
        }
        
        switch attribute {
            case .firstName(let firstName):
                braze.user.set(firstName: firstName)
            case .lastName(let lastName):
                braze.user.set(lastName: lastName)
            case .email(let email):
                braze.user.set(email: email)
            case .dateOfBirth(let dateOfBirth):
                braze.user.set(dateOfBirth: dateOfBirth)
            case .gender(let gender):
                braze.user.set(gender: gender)
            case .phoneNumber(let phoneNumber):
                braze.user.set(phoneNumber: phoneNumber)
            case .homeCity(let homeCity):
                braze.user.set(homeCity: homeCity)
            case .country(let country):
                braze.user.set(country: country)
            case .attributionData(let attributionData):
                braze.user.set(attributionData: attributionData)
        }
    }

    func logPurchase(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot log purchase.")
            return
        }
        braze.logPurchase(
            productId: productId,
            currency: currency,
            price: price,
            quantity: quantity,
            properties: properties
        )
        LoggerAnalytics.verbose("BrazeAdapter: Logged purchase for product '\(productId)', currency: \(currency), price: \(price), quantity: \(quantity)")
    }

    func logCustomEvent(name: String, properties: [String: Any]?) {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot log custom event.")
            return
        }

        if let properties = properties, !properties.isEmpty {
            braze.logCustomEvent(name: name, properties: properties)
            LoggerAnalytics.verbose("BrazeAdapter: Logged custom event '\(name)' with properties \(properties)")
        } else {
            braze.logCustomEvent(name: name)
            LoggerAnalytics.verbose("BrazeAdapter: Logged custom event '\(name)'")
        }
    }

    func requestImmediateDataFlush() {
        guard let braze else {
            LoggerAnalytics.error("BrazeAdapter: Braze SDK not initialized. Cannot flush data.")
            return
        }
        braze.requestImmediateDataFlush()
        LoggerAnalytics.verbose("BrazeAdapter: Data flush completed")
    }

    func getDestinationInstance() -> Any? {
        return braze
    }
}
