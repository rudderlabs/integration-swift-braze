@import XCTest;
@import RudderIntegrationBraze;

@interface ObjCInterfaceTests : XCTestCase
@end

@implementation ObjCInterfaceTests
- (void)testNativeInstanceIsNilBeforeInitialization {
    RSSBrazeIntegration *integration = [[RSSBrazeIntegration alloc] init];
    XCTAssertNil([integration getDestinationInstance]);
    XCTAssertEqualObjects(integration.key, @"Braze");
}
@end
