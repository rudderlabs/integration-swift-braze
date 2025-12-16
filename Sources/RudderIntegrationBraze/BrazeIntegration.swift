//
//  BrazeIntegration.swift
//  RudderIntegrationBraze
//
//  Swift integration for Braze destination
//

import Foundation
import BrazeKit
import RudderStackAnalytics

private let aliasLabel = "rudder_id"

private let installAttributed = "Install Attributed"
private let orderCompleted = "Order Completed"

/**
 * Rudder Braze Integration for RudderStack Swift SDK
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
    private var previousIdentifyTraits: IdentifyTraits?
    private var brazeConfig: RudderBrazeConfig?

    // MARK: - Initialization

    public init() {
        self.brazeAdapter = DefaultBrazeAdapter()
    }

    /**
     * Internal initializer for unit testing.
     * Allows dependency injection of a mock BrazeAdapter.
     */
    internal init(brazeAdapter: BrazeAdapter) {
        self.brazeAdapter = brazeAdapter
    }

    // MARK: - Required Protocol Methods

    /**
     * Creates and initializes the Braze integration
     */
    public func create(destinationConfig: [String: Any]) throws {
        if let config: RudderBrazeConfig = parse(destinationConfig) {
            self.brazeConfig = config
            let success = brazeAdapter.initSDK(
                apiKey: config.resolvedApiKey,
                endpoint: config.customEndpoint,
                logLevel: LoggerAnalytics.logLevel
            )

            if success {
                setUserAlias()
            }
        }
    }

    /**
     * Sets the alias Id.
     * This is mainly needed for the hybrid mode in order to link the anonymous user activity.
     */
    private func setUserAlias() {
        if let anonymousId = analytics?.anonymousId {
            brazeAdapter.addUserAlias(anonymousId, label: aliasLabel)
        }
    }

    /**
     * Updates destination configuration dynamically
     */
    public func update(destinationConfig: [String: Any]) throws {
        if let updatedConfig: RudderBrazeConfig = parse(destinationConfig) {
            self.brazeConfig = updatedConfig
            LoggerAnalytics.debug("Braze configuration updated")
        }
    }

    /**
     * Returns the destination instance
     * Required by IntegrationPlugin protocol
     */
    public func getDestinationInstance() -> Any? {
        return brazeAdapter.getDestinationInstance()
    }

    /**
     * Handles track events
     */
    public func track(payload: TrackEvent) {
        if brazeConfig?.isHybridMode() == true { return }

        switch payload.event {
        case installAttributed:
            handleInstallAttributedEvent(payload: payload)

        case orderCompleted:
            handleOrderCompletedEvent(payload: payload)

        default:
            handleCustomEvent(payload: payload)
        }
    }

    /**
     * Handles Install Attributed event with attribution data
     */
    private func handleInstallAttributedEvent(payload: TrackEvent) {
        let properties = payload.properties?.dictionary?.rawDictionary ?? [:]

        if let installAttributed: InstallAttributed = parse(properties),
           let campaign = installAttributed.campaign {
            brazeAdapter.setUserAttribute(.attributionData(Braze.User.AttributionData(
                network: campaign.source,
                campaign: campaign.name,
                adGroup: campaign.adGroup,
                creative: campaign.adCreative
            )))
        } else {
            handleCustomEvent(payload: payload)
        }
    }

    /**
     * Handles Order Completed event with purchase tracking
     */
    private func handleOrderCompletedEvent(payload: TrackEvent) {
        let properties = payload.properties?.dictionary?.rawDictionary ?? [:]

        // Get custom (or non-standard) properties present at the root and product level
        let customProperties = filter(
            properties: properties,
            rootKeys: StandardProperties.getKeysAsList(),
            productKeys: Product.getKeysAsList()
        )

        let standardProperties = getStandardProperties(properties)
        let currency = standardProperties.currency

        for product in standardProperties.products where product.isNotEmpty() {
            brazeAdapter.logPurchase(
                productId: product.productId ?? "",
                currency: currency,
                price: product.price,
                quantity: product.quantity,
                properties: customProperties
            )
        }
    }

    /**
     * Handles custom event
     */
    private func handleCustomEvent(payload: TrackEvent) {
        let properties = payload.properties?.dictionary?.rawDictionary
        brazeAdapter.logCustomEvent(name: payload.event, properties: properties)
    }

    /**
     * Handles identify events
     */
    public func identify(payload: IdentifyEvent) {
        if brazeConfig?.isHybridMode() == true { return }

        let currentIdentifyTraits = toIdentifyTraits(from: payload)

        let deDupedTraits: IdentifyTraits
        if brazeConfig?.supportDedup == true {
            deDupedTraits = deDupe(currentTraits: currentIdentifyTraits, previousTraits: previousIdentifyTraits)
        } else {
            deDupedTraits = currentIdentifyTraits
        }

        if let userId = getExternalIdOrUserId(from: deDupedTraits) {
            brazeAdapter.changeUser(userId: userId)
        }

        brazeAdapter.setTraits(deDupedTraits: deDupedTraits)

        previousIdentifyTraits = currentIdentifyTraits
    }

    /**
     * Flushes pending events
     */
    public func flush() {
        brazeAdapter.requestImmediateDataFlush()
    }
}
