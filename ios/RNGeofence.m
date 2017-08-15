
#import "RNGeofence.h"
#import "RNGeoLocationManager.h"


static NSString *const EVENT_GEOFENCE = @"geofence";

@interface RNGeofence () <RNGeoLocationManagerDelegate>

@end

@implementation RNGeofence

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}


-(instancetype)init
{
    self = [super init];
    if (self) {
        [[RNGeoLocationManager sharedManager] setDelegate:self];
    }
    return self;
}

RCT_EXPORT_MODULE()


- (NSArray<NSString *> *)supportedEvents {
    return @[
             EVENT_GEOFENCE,
             ];
}

RCT_EXPORT_METHOD(configure:(NSDictionary*)config success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *state = [[RNGeoLocationManager sharedManager] setConfig:config];
        if (state != nil) {
            success(@[state]);
        } else {
            failure(@[]);
        }
    });
}

RCT_EXPORT_METHOD(setConfig:(NSDictionary*)config success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    NSString *state = [[RNGeoLocationManager sharedManager] setConfig:config];
    success(@[state]);
}

RCT_EXPORT_METHOD(addGeofence:(NSDictionary*) config success:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    [[RNGeoLocationManager sharedManager] addGeofence:config success:^(NSString* response) {
        success(@[response]);
    } error:^(NSString* error) {
        failure(@[error]);
    }];
}

-(void)didHitGeofence:(NSDictionary *)fence{
    [self sendEventWithName:EVENT_GEOFENCE body:fence];
}

@end
  
