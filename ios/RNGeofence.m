
#import "RNGeofence.h"
#import "RNGeoLocationManager.h"


static NSString *const EVENT_GEOFENCE = @"geofence";
static NSString *const EVENT_LOCATIONCHANGE = @"location";

@interface RNGeofence () <RNGeoLocationManagerDelegate>

@end

@implementation RNGeofence

@synthesize bridge = _bridge;

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}


-(instancetype)init
{
    self = [super init];
    if (self) {
        [[RNGeoLocationManager sharedManager] setDelegate:self];
        __typeof(self) __weak me = self;
        [[RNGeoLocationManager sharedManager] addListener:EVENT_LOCATIONCHANGE callback:^(NSDictionary *event) {
            if ([NSThread isMainThread]) {
                [me sendEventWithName:EVENT_LOCATIONCHANGE body:event];
            }
            else {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    [me sendEventWithName:EVENT_LOCATIONCHANGE body:event];
                });
                
            }
        }];
        //[self performSelector:@selector(fireLocation:) withObject:nil afterDelay:2.0];
    }
    return self;
}

RCT_EXPORT_MODULE()


- (NSArray<NSString *> *)supportedEvents {
    return @[
             EVENT_GEOFENCE,
             EVENT_LOCATIONCHANGE
             ];
}

-(void)fireLocation:(id)event{
    
    NSDictionary*location = [[RNGeoLocationManager sharedManager]getLocation];
    if(location){
        [self sendEventWithName:EVENT_LOCATIONCHANGE body:location];
    }
    
}

RCT_EXPORT_METHOD(getCurrentWifi:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure){
    [[RNGeoLocationManager sharedManager] getCurrentWifi:^(NSArray *response) {
        success(@[response]);
    } error:^(NSString *error) {
        failure(@[error]);
    }];
}

RCT_EXPORT_METHOD(requestLocation){
    [[RNGeoLocationManager sharedManager]requestLocationUpdate];
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

RCT_EXPORT_METHOD(removeGeofences:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    NSArray *geofences = @[];
    [[RNGeoLocationManager sharedManager] removeGeofences:geofences success:^(NSString* response) {
        success(@[response]);
    } error:^(NSString* error) {
        failure(@[error]);
    }];
    
}

-(void)didHitGeofence:(NSDictionary *)fence{
    [self sendEventWithName:EVENT_GEOFENCE body:fence];
}

@end
  
