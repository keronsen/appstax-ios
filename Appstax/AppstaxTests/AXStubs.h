
#import <Foundation/Foundation.h>
#import "OHHTTPStubs.h"
#import "OHHTTPStubsResponse+JSON.h"

@interface AXStubs : NSObject

+ (void)method:(NSString *)method urlPath:(NSString *)urlPath response:(id)responseObject statusCode:(int)statusCode;
+ (void)method:(NSString *)method urlPath:(NSString *)urlPath responding:(OHHTTPStubsResponseBlock)responseBlock;
+ (void)method:(NSString *)method urlPath:(NSString *)urlPath query:(NSString *)query responding:(OHHTTPStubsResponseBlock)responseBlock;
+ (void)method:(NSString *)method urlPath:(NSString *)urlPath query:(NSString *)query response:(id)responseObject statusCode:(int)statusCode;
+ (void)method:(NSString *)method urlString:(NSString *)urlString responding:(OHHTTPStubsResponseBlock)responseBlock;

@end
