import XCTest
import BrazeKit
import RudderStackAnalytics
@testable import RudderIntegrationBraze

final class NativeBrazeTests: XCTestCase {
    @MainActor
    func testImmediateUserSwitchAndEvents() async throws {
        let capture = NativeRequestLog()
        let adapter = DefaultBrazeAdapter { configuration in
            configuration.devicePropertyAllowList = []
            configuration.api.requestPolicy = .manual
            configuration.logger.print = { message, _ in
                capture.append(message)
                return false
            }
            return Braze(configuration: configuration)
        }
        XCTAssertTrue(adapter.initSDK(
            appIdentifierKey: UUID().uuidString,
            endpoint: "sdk-5275.invalid",
            logLevel: .debug
        ))
        let braze = try XCTUnwrap(adapter.getDestinationInstance() as? Braze)
        braze.enabled = true
        defer { braze.wipeData() }
        XCTAssertTrue(adapter.initSDK(appIdentifierKey: "unused", endpoint: "unused.invalid", logLevel: .none))
        XCTAssertTrue(braze === adapter.getDestinationInstance() as? Braze)

        adapter.addUserAlias("sdk-5275-anonymous", label: "rudder_id")
        for user in ["sdk-5275-a", "sdk-5275-b"] {
            adapter.changeUser(userId: user)
            adapter.setUserAttribute(.firstName(user))
            adapter.logCustomEvent(name: user, properties: ["owner": user])
            adapter.logPurchase(productId: user, currency: "USD", price: 2, quantity: 1, properties: nil)
        }
        adapter.requestImmediateDataFlush()

        // Flush can run before all asynchronous user work has settled.
        // Retry the flush, but do not insert waits between user changes and events.
        for _ in 0..<100 {
            if ["sdk-5275-a", "sdk-5275-b"].allSatisfy({ capture.hasPayload(for: $0) }) { break }
            adapter.requestImmediateDataFlush()
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        for user in ["sdk-5275-a", "sdk-5275-b"] {
            XCTAssertTrue(capture.hasPayload(for: user), "Missing or misattributed payload for \(user)")
        }
        XCTAssertTrue(capture.events.contains {
            let data = $0["data"] as? [String: Any]
            return $0["name"] as? String == "uae"
                && data?["a"] as? String == "sdk-5275-anonymous"
                && data?["l"] as? String == "rudder_id"
        })
        XCTAssertEqual(braze.user.id, "sdk-5275-b")
    }
}

private final class NativeRequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    // These assertions inspect the real SDK's serialized requests, not a mock adapter.
    // The reserved endpoint cannot deliver data. Network errors are expected.
    func hasPayload(for user: String) -> Bool {
        let custom = events.contains {
            let data = $0["data"] as? [String: Any]
            return $0["user_id"] as? String == user
                && $0["name"] as? String == "ce"
                && data?["n"] as? String == user
                && (data?["p"] as? [String: Any])?["owner"] as? String == user
        }
        let purchase = events.contains {
            let data = $0["data"] as? [String: Any]
            return $0["user_id"] as? String == user
                && $0["name"] as? String == "p"
                && data?["pid"] as? String == user
                && data?["c"] as? String == "USD"
                && data?["q"] as? Int == 1
                && data?["p"] as? Double == 2
        }
        let attributes = requests.flatMap { $0["attributes"] as? [[String: Any]] ?? [] }
        let traits = attributes.contains {
            $0["user_id"] as? String == user && $0["first_name"] as? String == user
        }
        return custom && purchase && traits
    }

    var requests: [[String: Any]] {
        messages.compactMap { message in
            guard let range = message.range(of: "- Body:\n"),
                  let data = String(message[range.upperBound...]).data(using: .utf8) else { return nil }
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
    }

    var events: [[String: Any]] {
        requests.flatMap { $0["events"] as? [[String: Any]] ?? [] }
    }

    var messages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        if message.contains("[http] request") && message.contains("- Body:") {
            stored.append(message)
        }
    }
}
