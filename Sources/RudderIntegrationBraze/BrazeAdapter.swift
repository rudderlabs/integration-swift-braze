//
//  BrazeAdapter.swift
//  integration-swift-braze
//
//  Created by Vishal Gupta on 21/11/25.
//

import Foundation
import BrazeKit

/**
 * Protocol to wrap Braze SDK functionality for testability
 */
protocol BrazeAdapter {
    func initialize(configuration: Braze.Configuration) -> Bool
    func changeUser(userId: String)
    func addUserAlias(_ alias: String, label: String) -> Bool
    func setUserAttribute(_ attribute: BrazeUserAttribute)
    func setCustomAttribute(key: String, value: Any)
    func logCustomEvent(name: String, properties: [String: Any]?)
    func logPurchase(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?)
    func requestImmediateDataFlush()
    func setLogLevel(_ level: Braze.Configuration.Logger.Level)
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

// MARK: - Default Implementation
class DefaultBrazeAdapter: BrazeAdapter {
    private var brazeInstance: Braze?

    func initialize(configuration: Braze.Configuration) -> Bool {
        brazeInstance = Braze(configuration: configuration)
        return brazeInstance != nil
    }

    func changeUser(userId: String) {
        brazeInstance?.changeUser(userId: userId)
    }

    func addUserAlias(_ alias: String, label: String) -> Bool {
        brazeInstance?.user.add(alias: alias, label: label)
        return brazeInstance != nil
    }

    func setUserAttribute(_ attribute: BrazeUserAttribute) {
        guard let user = brazeInstance?.user else { return }

        switch attribute {
        case .firstName(let firstName):
            user.set(firstName: firstName)
        case .lastName(let lastName):
            user.set(lastName: lastName)
        case .email(let email):
            user.set(email: email)
        case .dateOfBirth(let dateOfBirth):
            user.set(dateOfBirth: dateOfBirth)
        case .gender(let gender):
            user.set(gender: gender)
        case .phoneNumber(let phoneNumber):
            user.set(phoneNumber: phoneNumber)
        case .homeCity(let homeCity):
            user.set(homeCity: homeCity)
        case .country(let country):
            user.set(country: country)
        case .attributionData(let attributionData):
            user.set(attributionData: attributionData)
        }
    }

    func setCustomAttribute(key: String, value: Any) {
        guard let user = brazeInstance?.user else { return }

        switch value {
        case let stringValue as String:
            user.setCustomAttribute(key: key, value: stringValue)
        case let dateValue as Date:
            user.setCustomAttribute(key: key, value: dateValue)
        case let boolValue as Bool:
            user.setCustomAttribute(key: key, value: boolValue)
        case let intValue as Int:
            user.setCustomAttribute(key: key, value: intValue)
        case let doubleValue as Double:
            user.setCustomAttribute(key: key, value: doubleValue)
        default:
            break
        }
    }

    func logCustomEvent(name: String, properties: [String: Any]?) {
        brazeInstance?.logCustomEvent(name: name, properties: properties ?? [:])
    }

    func logPurchase(productId: String, currency: String, price: Double, quantity: Int, properties: [String: Any]?) {
        brazeInstance?.logPurchase(
            productId: productId,
            currency: currency,
            price: price,
            quantity: quantity,
            properties: properties ?? [:]
        )
    }

    func requestImmediateDataFlush() {
        brazeInstance?.requestImmediateDataFlush()
    }

    func setLogLevel(_ level: Braze.Configuration.Logger.Level) {
        brazeInstance?.configuration.logger.level = level
    }

    func getDestinationInstance() -> Any? {
        return brazeInstance
    }
}
