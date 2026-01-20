//
//  ObjCBrazeIntegration.swift
//  RudderIntegrationBraze
//
//  Created by Satheesh Kannan on 11/01/26.
//

import Foundation
import RudderStackAnalytics

// MARK: - ObjCBrazeIntegration
/**
 An Objective-C compatible wrapper for the Braze Integration.

 This class provides an Objective-C interface to the Braze integration,
 allowing Objective-C apps to use the Braze device mode integration with RudderStack.

 ## Usage in Objective-C:
 ```objc
 RSSConfigurationBuilder *builder = [[RSSConfigurationBuilder alloc] initWithWriteKey:@"<WriteKey>"
                                                          dataPlaneUrl:@"<DataPlaneUrl>"];
 RSSAnalytics *analytics = [[RSSAnalytics alloc] initWithConfiguration:[builder build]];

 RSSBrazeIntegration *brazeIntegration = [[RSSBrazeIntegration alloc] init];
 [analytics addPlugin:brazeIntegration];
 ```
 */
@objc(RSSBrazeIntegration)
public class ObjCBrazeIntegration: NSObject, ObjCIntegrationPlugin, ObjCStandardIntegration {

    // MARK: - ObjCPlugin Properties

    public var pluginType: PluginType {
        get { brazeIntegration.pluginType }
        set { brazeIntegration.pluginType = newValue }
    }

    // MARK: - ObjCIntegrationPlugin Properties

    public var key: String {
        get { brazeIntegration.key }
        set { brazeIntegration.key = newValue }
    }

    // MARK: - Private Properties

    private let brazeIntegration: BrazeIntegration

    // MARK: - Initializers

    /**
     Initializes a new Braze integration instance.

     Use this initializer to create a Braze integration that can be added to the analytics client.
     */
    @objc
    public override init() {
        self.brazeIntegration = BrazeIntegration()
        super.init()
    }

    // MARK: - ObjCIntegrationPlugin Methods

    /**
     Returns the Braze SDK instance.

     - Returns: The Braze SDK instance, or nil if not initialized.
     */
    @objc
    public func getDestinationInstance() -> Any? {
        return brazeIntegration.getDestinationInstance()
    }

    /**
     Creates and configures the Braze SDK with the provided destination configuration.

     - Parameters:
        - destinationConfig: Configuration dictionary from RudderStack dashboard.
        - errorPointer: A pointer to an NSError that will be set if initialization fails.
     - Returns: `true` if initialization succeeded, `false` otherwise.
     */
    @objc
    public func createWithDestinationConfig(_ destinationConfig: [String: Any], error errorPointer: NSErrorPointer) -> Bool {
        do {
            try brazeIntegration.create(destinationConfig: destinationConfig)
            return true
        } catch let err as NSError {
            errorPointer?.pointee = err
            return false
        } catch {
            errorPointer?.pointee = NSError(
                domain: "com.rudderstack.BrazeIntegration",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
            return false
        }
    }

    /**
     Updates the Braze SDK configuration dynamically.

     - Parameters:
        - destinationConfig: Updated configuration dictionary from RudderStack dashboard.
        - errorPointer: A pointer to an NSError that will be set if update fails.
     - Returns: `true` if update succeeded, `false` otherwise.
     */
    @objc
    public func updateWithDestinationConfig(_ destinationConfig: [String: Any], error errorPointer: NSErrorPointer) -> Bool {
        do {
            try brazeIntegration.update(destinationConfig: destinationConfig)
            return true
        } catch let err as NSError {
            errorPointer?.pointee = err
            return false
        } catch {
            errorPointer?.pointee = NSError(
                domain: "com.rudderstack.BrazeIntegration",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
            return false
        }
    }

    // MARK: - ObjCEventPlugin Methods

    /**
     Processes a track event and forwards it to the underlying Braze integration.

     - Parameter payload: The ObjC track event payload.
     */
    @objc
    public func track(_ payload: ObjCTrackEvent) {
        var trackEvent = TrackEvent(
            event: payload.eventName,
            properties: payload.properties,
            options: payload.options
        )
        trackEvent.anonymousId = payload.anonymousId
        trackEvent.userId = payload.userId

        brazeIntegration.track(payload: trackEvent)
    }

    /**
     Processes an identify event and forwards it to the underlying Braze integration.

     - Parameter payload: The ObjC identify event payload.
     */
    @objc
    public func identify(_ payload: ObjCIdentifyEvent) {
        var identifyEvent = IdentifyEvent(options: payload.options)
        identifyEvent.anonymousId = payload.anonymousId
        identifyEvent.userId = payload.userId
        identifyEvent.context = payload.context?.codableWrapped
        
        brazeIntegration.identify(payload: identifyEvent)
    }
    
    /**
     Flushes any pending events to Braze.

     This triggers an immediate data flush to the Braze servers.
     */
    @objc
    public func flush() {
        brazeIntegration.flush()
    }
}
