import Testing
import Foundation
import RudderStackAnalytics
@testable import RudderIntegrationBraze

// MARK: - Warning capture

/// Captures `LoggerAnalytics.warn(...)` messages so the send-anyway warnings can be asserted.
/// Only `warn`/`error` are overridden; the rest use the protocol's default no-op.
private final class WarningCapturingLogger: Logger {
    var warnings: [String] = []
    func warn(log: String) { warnings.append(log) }
    func error(log: String, error: Error?) {}
}

@Suite(.serialized)
class EcommerceUtilTests {

    private let analytics: Analytics

    init() {
        let config = Configuration(writeKey: "test-write-key", dataPlaneUrl: "https://test.rudderstack.com")
        self.analytics = Analytics(configuration: config)
    }

    // MARK: - Helpers

    /// Runs `body` with a fresh capturing logger installed at warn-visible level, returning the
    /// warnings it emitted. Restores the previous log level afterwards.
    private func captureWarnings(_ body: () -> Void) -> [String] {
        let logger = WarningCapturingLogger()
        let previousLevel = LoggerAnalytics.logLevel
        LoggerAnalytics.setLogger(logger)
        LoggerAnalytics.logLevel = .verbose
        defer { LoggerAnalytics.logLevel = previousLevel }
        body()
        return logger.warnings
    }

    /// Fresh integration backed by a mock adapter and the shared analytics instance.
    private func makeIntegration(_ mock: MockBrazeAdapter) -> BrazeIntegration {
        let integration = BrazeIntegration(brazeAdapter: mock)
        integration.analytics = analytics
        return integration
    }

    // MARK: - getEcommerceMapping

    @Test("given supported RS event names, when getEcommerceMapping is called, then the Braze event and action are resolved (case-insensitive, trimmed)")
    func testEventNameMappingResolvesSupportedEvents() {
        #expect(getEcommerceMapping("Product Viewed")?.brazeEvent == BrazeEcommerceEvent.productViewed)
        #expect(getEcommerceMapping("Product Viewed")?.action == nil)

        #expect(getEcommerceMapping("product added")?.brazeEvent == BrazeEcommerceEvent.cartUpdated)
        #expect(getEcommerceMapping("product added")?.action == "add")

        #expect(getEcommerceMapping("  Product Removed  ")?.brazeEvent == BrazeEcommerceEvent.cartUpdated)
        #expect(getEcommerceMapping("  Product Removed  ")?.action == "remove")

        #expect(getEcommerceMapping("CHECKOUT STARTED")?.brazeEvent == BrazeEcommerceEvent.checkoutStarted)
        #expect(getEcommerceMapping("Order Completed")?.brazeEvent == BrazeEcommerceEvent.orderPlaced)
        #expect(getEcommerceMapping("Order Refunded")?.brazeEvent == BrazeEcommerceEvent.orderRefunded)
        #expect(getEcommerceMapping("Order Cancelled")?.brazeEvent == BrazeEcommerceEvent.orderCancelled)
    }

    @Test("given unmapped event names, when getEcommerceMapping is called, then nil is returned")
    func testEventNameMappingReturnsNilForUnmapped() {
        #expect(getEcommerceMapping("Cart Viewed") == nil)
        #expect(getEcommerceMapping("Cart Updated") == nil)
        #expect(getEcommerceMapping("Custom Event") == nil)
        #expect(getEcommerceMapping("") == nil)
    }

    // MARK: - product_viewed

    @Test("given a full Product Viewed payload, when properties are built, then mapped fields, source and metadata are set without a products array")
    func testProductViewedFullMapping() {
        let properties: [String: Any] = [
            "product_id": "prod_1",
            "name": "Cool Shirt",
            "variant": "var_9",
            "price": 29.99,
            "currency": "USD",
            "image_url": "https://example.com/img.png",
            "url": "https://example.com/p/1",
            "type": ["apparel"],
            "extra_key": "extra_val"
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.productViewed, action: nil)

        #expect(result["product_id"] as? String == "prod_1")
        #expect(result["product_name"] as? String == "Cool Shirt")
        #expect(result["variant_id"] as? String == "var_9")
        #expect(result["price"] as? Double == 29.99)
        #expect(result["currency"] as? String == "USD")
        #expect(result["image_url"] as? String == "https://example.com/img.png")
        #expect(result["product_url"] as? String == "https://example.com/p/1")
        #expect(result["type"] as? [String] == ["apparel"])
        #expect(result["source"] as? String == "ios")
        #expect(result["products"] == nil)

        let metadata = result["metadata"] as? [String: Any]
        #expect(metadata?["extra_key"] as? String == "extra_val")
    }

    @Test("given a Product Viewed payload missing product_id and variant, when built, then the sku fallback chain resolves both")
    func testProductViewedFallbackChain() {
        let properties: [String: Any] = [
            "sku": "sku_5",
            "name": "Item",
            "price": 10.0,
            "currency": "USD"
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.productViewed, action: nil)

        #expect(result["product_id"] as? String == "sku_5")
        #expect(result["variant_id"] as? String == "sku_5")
    }

    @Test("given an explicit properties.source, when built, then it is ignored and not echoed into metadata")
    func testSourceIsAlwaysIosAndNeverLeaksToMetadata() {
        let properties: [String: Any] = [
            "product_id": "p", "name": "n", "variant": "v", "price": 1.0, "currency": "USD",
            "source": "web"
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.productViewed, action: nil)

        #expect(result["source"] as? String == "ios")
        let metadata = result["metadata"] as? [String: Any]
        #expect(metadata?["source"] == nil)
    }

    // MARK: - cart_updated

    @Test("given Product Added without an explicit products array, when built, then top-level product fields are wrapped into a single product and action is set")
    func testCartUpdatedWrapsTopLevelProduct() {
        let properties: [String: Any] = [
            "cart_id": "cart_1",
            "currency": "USD",
            "revenue": 120.0,
            "product_id": "prod_1",
            "name": "Shirt",
            "quantity": 2,
            "price": 60.0,
            "coupon": "SAVE10"
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.cartUpdated, action: "add")

        #expect(result["cart_id"] as? String == "cart_1")
        #expect(result["currency"] as? String == "USD")
        #expect(result["total_value"] as? Double == 120.0)
        #expect(result["action"] as? String == "add")
        #expect(result["source"] as? String == "ios")

        let products = result["products"] as? [[String: Any]]
        #expect(products?.count == 1)
        #expect(products?.first?["product_id"] as? String == "prod_1")
        #expect(products?.first?["product_name"] as? String == "Shirt")
        #expect(products?.first?["variant_id"] as? String == "prod_1")
        #expect(products?.first?["quantity"] as? Int == 2)
        #expect(products?.first?["price"] as? Double == 60.0)
        #expect(products?.first?["metadata"] == nil)

        let metadata = result["metadata"] as? [String: Any]
        #expect(metadata?["coupon"] as? String == "SAVE10")
        // Product-mapping keys are consumed by the wrap and must not duplicate into metadata.
        #expect(metadata?["product_id"] == nil)
        #expect(metadata?["name"] == nil)
        #expect(metadata?["quantity"] == nil)
        #expect(metadata?["price"] == nil)
    }

    @Test("given Product Removed with an explicit products array, when built, then products are iterated, per-product metadata is routed, and top-level product keys flow to event metadata")
    func testCartUpdatedWithExplicitProductsArray() {
        let properties: [String: Any] = [
            "cart_id": "cart_2",
            "currency": "EUR",
            "products": [
                ["product_id": "p1", "name": "A", "quantity": 1, "price": 10.0, "color": "red"]
            ],
            "product_id": "top_level_pid"
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.cartUpdated, action: "remove")

        #expect(result["action"] as? String == "remove")

        let products = result["products"] as? [[String: Any]]
        #expect(products?.count == 1)
        #expect(products?.first?["product_id"] as? String == "p1")

        let productMetadata = products?.first?["metadata"] as? [String: Any]
        #expect(productMetadata?["color"] as? String == "red")

        // With an explicit products[], the top-level product_id is NOT consumed → flows to metadata.
        let metadata = result["metadata"] as? [String: Any]
        #expect(metadata?["product_id"] as? String == "top_level_pid")
    }

    // MARK: - checkout_started

    @Test("given Checkout Started without checkout_id, when built, then order_id resolves checkout_id and products are mapped")
    func testCheckoutStartedFallbackAndProducts() {
        let properties: [String: Any] = [
            "order_id": "ord_1",
            "total": 200.0,
            "currency": "USD",
            "products": [["product_id": "p1", "name": "A", "quantity": 1, "price": 50.0]]
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.checkoutStarted, action: nil)

        #expect(result["checkout_id"] as? String == "ord_1")
        #expect(result["total_value"] as? Double == 200.0)
        #expect((result["products"] as? [[String: Any]])?.count == 1)
    }

    // MARK: - order_placed

    @Test("given Order Completed, when built, then revenue resolves total_value, discount resolves total_discounts, and products are mapped")
    func testOrderPlacedFallbacksAndProducts() {
        let properties: [String: Any] = [
            "order_id": "ord_9",
            "revenue": 99.99,
            "currency": "USD",
            "discount": 5.0,
            "products": [["product_id": "p1", "name": "A", "quantity": 2, "price": 40.0, "sku": "s1"]]
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.orderPlaced, action: nil)

        #expect(result["order_id"] as? String == "ord_9")
        #expect(result["total_value"] as? Double == 99.99)
        #expect(result["currency"] as? String == "USD")
        #expect(result["total_discounts"] as? Double == 5.0)
        #expect((result["products"] as? [[String: Any]])?.first?["quantity"] as? Int == 2)
    }

    // MARK: - order_refunded

    @Test("given a sparse Order Refunded payload, when built, then one missing-required warning lists the unresolved fields and the event is still produced")
    func testOrderRefundedMissingRequiredWarning() {
        var result: [String: Any] = [:]
        let warnings = captureWarnings {
            result = buildEcommerceEventProperties(
                properties: ["order_id": "r1"],
                brazeEvent: BrazeEcommerceEvent.orderRefunded,
                action: nil
            )
        }

        let missingWarning = warnings
            .filter { $0.contains(BrazeEcommerceEvent.orderRefunded) }
            .first { $0.contains("missing") }

        #expect(missingWarning != nil)
        #expect(missingWarning?.contains("total_value") == true)
        #expect(missingWarning?.contains("currency") == true)
        #expect(missingWarning?.contains("products") == true)

        // Send-anyway: the event is still built with what resolved.
        #expect(result["order_id"] as? String == "r1")
        #expect(result["source"] as? String == "ios")
    }

    @Test("given Order Refunded with a discounts array, when built, then the array passes through verbatim")
    func testOrderRefundedDiscountsArrayPassesThrough() {
        let properties: [String: Any] = [
            "order_id": "r2",
            "total": 80.0,
            "currency": "USD",
            "discounts": [["code": "X", "amount": 5]],
            "products": [["product_id": "p1", "name": "A", "quantity": 1, "price": 80.0]]
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.orderRefunded, action: nil)

        #expect((result["discounts"] as? [[String: Any]])?.count == 1)
    }

    // MARK: - order_cancelled

    @Test("given Order Cancelled with reason instead of cancel_reason, when built, then the fallback resolves cancel_reason")
    func testOrderCancelledCancelReasonFallback() {
        let properties: [String: Any] = [
            "order_id": "c1",
            "total": 50.0,
            "currency": "USD",
            "reason": "changed mind",
            "products": [["product_id": "p1", "name": "A", "quantity": 1, "price": 50.0]]
        ]

        let result = buildEcommerceEventProperties(properties: properties, brazeEvent: BrazeEcommerceEvent.orderCancelled, action: nil)

        #expect(result["cancel_reason"] as? String == "changed mind")
    }

    // MARK: - Coercion

    @Test("given numeric strings for Float/Integer fields, when built, then they are losslessly coerced")
    func testNumericStringCoercion() {
        let productViewed = buildEcommerceEventProperties(
            properties: ["product_id": "p", "name": "n", "variant": "v", "price": "29.99", "currency": "USD"],
            brazeEvent: BrazeEcommerceEvent.productViewed,
            action: nil
        )
        #expect(productViewed["price"] as? Double == 29.99)

        let orderPlaced = buildEcommerceEventProperties(
            properties: [
                "order_id": "o", "total": 10.0, "currency": "USD",
                "products": [["product_id": "p1", "name": "A", "quantity": "2", "price": "10.50"]]
            ],
            brazeEvent: BrazeEcommerceEvent.orderPlaced,
            action: nil
        )
        let product = (orderPlaced["products"] as? [[String: Any]])?.first
        #expect(product?["quantity"] as? Int == 2)
        #expect(product?["price"] as? Double == 10.50)
    }

    @Test("given a number for a String field, when built, then it is coerced to a String")
    func testNumberToStringCoercion() {
        let result = buildEcommerceEventProperties(
            properties: ["product_id": 123, "name": "n", "variant": "v", "price": 1.0, "currency": "USD"],
            brazeEvent: BrazeEcommerceEvent.productViewed,
            action: nil
        )

        #expect(result["product_id"] as? String == "123")
    }

    // MARK: - Type mismatch

    @Test("given a Bool for a Float field, when built, then it is sent as-is and a type-mismatch warning is emitted (Bool is not stringified)")
    func testBoolOnFloatFieldWarnsAndIsSentAsIs() {
        var result: [String: Any] = [:]
        let warnings = captureWarnings {
            result = buildEcommerceEventProperties(
                properties: ["product_id": "p", "name": "n", "variant": "v", "price": true, "currency": "USD"],
                brazeEvent: BrazeEcommerceEvent.productViewed,
                action: nil
            )
        }

        let mismatch = warnings
            .filter { $0.contains(BrazeEcommerceEvent.productViewed) }
            .first { $0.contains("type-mismatched") }

        #expect(mismatch?.contains("price (expected float)") == true)
        #expect(result["price"] as? Bool == true)
    }

    @Test("given a non-string array for the stringArray type field, when built, then a type-mismatch warning is emitted")
    func testNonStringArrayOnStringArrayFieldWarns() {
        let warnings = captureWarnings {
            _ = buildEcommerceEventProperties(
                properties: ["product_id": "p", "name": "n", "variant": "v", "price": 1.0, "currency": "USD", "type": [1, 2]],
                brazeEvent: BrazeEcommerceEvent.productViewed,
                action: nil
            )
        }

        let mismatch = warnings
            .filter { $0.contains(BrazeEcommerceEvent.productViewed) }
            .first { $0.contains("type-mismatched") }

        #expect(mismatch?.contains("type (expected stringArray)") == true)
    }

    // MARK: - Integration wiring (BrazeIntegration.track)

    @Test("given the flag is on, when a mapped ecommerce event is tracked, then it is logged under the Braze recommended event name")
    func testTrackEmitsRecommendedEventWhenFlagOn() throws {
        let mock = MockBrazeAdapter()
        let integration = makeIntegration(mock)
        try integration.create(destinationConfig: BrazeTestData.configWithRecommendedEvents)

        let event = BrazeTestData.createTrackEvent(
            name: "Product Viewed",
            properties: ["product_id": "p", "name": "n", "variant": "v", "price": 1.0, "currency": "USD"]
        )
        integration.track(payload: event)

        #expect(mock.logCustomEventCalls.count == 1)
        #expect(mock.logCustomEventCalls[0].name == BrazeEcommerceEvent.productViewed)
        #expect(mock.logCustomEventCalls[0].properties?["product_id"] as? String == "p")
        #expect(mock.logPurchaseCalls.count == 0)
    }

    @Test("given the flag is on, when Order Completed is tracked, then it emits ecommerce.order_placed and skips the legacy purchase path")
    func testTrackOrderCompletedUsesRecommendedPathWhenFlagOn() throws {
        let mock = MockBrazeAdapter()
        let integration = makeIntegration(mock)
        try integration.create(destinationConfig: BrazeTestData.configWithRecommendedEvents)

        let event = BrazeTestData.createTrackEvent(name: "Order Completed", properties: BrazeTestData.orderCompletedProperties)
        integration.track(payload: event)

        #expect(mock.logCustomEventCalls.count == 1)
        #expect(mock.logCustomEventCalls[0].name == BrazeEcommerceEvent.orderPlaced)
        #expect(mock.logPurchaseCalls.count == 0)
    }

    @Test("given the flag is off, when Order Completed is tracked, then the legacy purchase path runs unchanged")
    func testTrackOrderCompletedUsesLegacyPathWhenFlagOff() throws {
        let mock = MockBrazeAdapter()
        let integration = makeIntegration(mock)
        try integration.create(destinationConfig: BrazeTestData.validConfig)

        let event = BrazeTestData.createTrackEvent(name: "Order Completed", properties: BrazeTestData.orderCompletedProperties)
        integration.track(payload: event)

        #expect(mock.logPurchaseCalls.count == 2)
        #expect(mock.logCustomEventCalls.count == 0)
    }

    @Test("given the flag is on, when an unmapped ecommerce event (Cart Updated) is tracked, then it falls through to the legacy custom-event path")
    func testTrackUnmappedEventFallsThroughWhenFlagOn() throws {
        let mock = MockBrazeAdapter()
        let integration = makeIntegration(mock)
        try integration.create(destinationConfig: BrazeTestData.configWithRecommendedEvents)

        let event = BrazeTestData.createTrackEvent(name: "Cart Updated", properties: ["cart_id": "c1"])
        integration.track(payload: event)

        #expect(mock.logCustomEventCalls.count == 1)
        #expect(mock.logCustomEventCalls[0].name == "Cart Updated")
    }

    @Test("given hybrid mode with the flag on, when a mapped ecommerce event is tracked, then nothing is sent")
    func testTrackRecommendedEventNoOpInHybridMode() throws {
        let mock = MockBrazeAdapter()
        let integration = makeIntegration(mock)
        try integration.create(destinationConfig: BrazeTestData.hybridConfigWithRecommendedEvents)

        let event = BrazeTestData.createTrackEvent(
            name: "Product Viewed",
            properties: ["product_id": "p", "name": "n", "variant": "v", "price": 1.0, "currency": "USD"]
        )
        integration.track(payload: event)

        #expect(mock.logCustomEventCalls.count == 0)
        #expect(mock.logPurchaseCalls.count == 0)
    }
}
