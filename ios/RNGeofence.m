
#import "RNGeofence.h"
#import "RNGeoLocationManager.h"
#import <MessageUI/MessageUI.h>


static NSString *const EVENT_GEOFENCE = @"geofence";
static NSString *const EVENT_LOCATIONCHANGE = @"location";

@interface RNGeofence () <RNGeoLocationManagerDelegate, MFMailComposeViewControllerDelegate>

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

RCT_EXPORT_METHOD(mailLogs:(RCTResponseSenderBlock)success failure:(RCTResponseSenderBlock)failure)
{
    
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) lastObject];
    NSString *storagefile = [docDir stringByAppendingPathComponent:@"nativelog.json"];
    
    NSString *jsonStr = [NSString stringWithContentsOfFile:storagefile encoding:NSUTF8StringEncoding error:nil];
    NSData* jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    
    
    
    UIViewController *topController = [[[[UIApplication sharedApplication]delegate] window] rootViewController];
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *composeViewController = [[MFMailComposeViewController alloc] initWithNibName:nil bundle:nil];
        [composeViewController setMailComposeDelegate:self];
        [composeViewController setToRecipients:@[@"amjad.kh@zigron.com"]];
        [composeViewController setSubject:@"Native  Logs"];
        [composeViewController addAttachmentData:jsonData mimeType:@"text/plain" fileName:@"log.json"];
        [topController presentViewController:composeViewController animated:YES completion:nil];
    }
}

-(void)didHitGeofence:(NSDictionary *)fence{
    [self sendEventWithName:EVENT_GEOFENCE body:fence];
}

#pragma mark - Mail Delegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    //Add an alert in case of failure
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end
  
