//
//  RNGeoLocationManager.m
//  RNGeofence
//
//  Created by zigron on 11/08/2017.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "RNGeoLocationManager.h"
#import <UIKit/UIKit.h>

@interface RNGeoLocationManager () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;

@end

@implementation RNGeoLocationManager

+ (RNGeoLocationManager *)sharedManager{
    static RNGeoLocationManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (id)init {
    if (self = [super init]) {
        self.locationManager = [[CLLocationManager alloc]init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        [self.locationManager requestAlwaysAuthorization];
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

-(NSString*)setConfig:(NSDictionary*)config{
    return @"configured";
}

-(CLCircularRegion*)getRegionFromDict:(NSDictionary*)param{
    NSString *identifier = [param valueForKey:@"identifier"];
    double radius = [[param valueForKey:@"radius"] doubleValue];
    double lat = [[param valueForKey:@"latitude"] doubleValue];
    double lng = [[param valueForKey:@"longitude"] doubleValue];
    
    CLCircularRegion *region = [[CLCircularRegion alloc]initWithCenter:CLLocationCoordinate2DMake(lat, lng) radius:radius identifier:identifier];
    return region;
}

-(void)addGeofence:(NSDictionary *)params success:(void (^)(NSString *))success error:(void (^)(NSString *))error{
    if(![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]){
        error(@"Geofencing is not supported on this device!");
        return;
    }
    if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways){
        error(@"Grant Abode permission to access the device location.");
        return;
    }
    CLCircularRegion *region = [self getRegionFromDict:params];
    [self.locationManager startMonitoringForRegion:region];
    success(@"Geofence Added successfully");
}

-(NSDictionary*)getLocationHash:(CLLocation*)location{
    NSMutableDictionary *locationHash = [NSMutableDictionary dictionary];
    
    NSMutableDictionary *coords = [NSMutableDictionary dictionary];
    [coords setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
    [coords setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];
    [coords setValue:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"accuracy"];
    
    NSTimeInterval interval = [location.timestamp timeIntervalSince1970];
    [coords setValue:[NSNumber numberWithDouble:interval] forKey:@"timestamp"];
    [locationHash setObject:coords forKey:@"coords"];
    return locationHash;
}

-(NSDictionary*)getHashForRegion:(CLRegion*)region didEnter:(BOOL)didEnter{
    CLCircularRegion *circle = (CLCircularRegion*)region;
    NSMutableDictionary *regionHash = [NSMutableDictionary dictionary];
    
    NSString *identifier = [circle identifier];
    double radius = [circle radius];
    
    NSString *action = @"EXIT";
    if(didEnter){
        action = @"ENTER";
    }
    
    CLLocation *location = [self.locationManager location];
    NSDictionary *locationMap = [self getLocationHash:location];
    
    [regionHash setObject:identifier forKey:@"identifier"];
    [regionHash setObject:action forKey:@"action"];
    [regionHash setObject:[NSNumber numberWithDouble:radius] forKey:@"radius"];
    [regionHash setObject:locationMap forKey:@"location"];
    
    return regionHash;
}

-(void)didHitFence:(CLRegion*)region didEnter:(BOOL)didEnter{
    
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
        [self.delegate didHitGeofence:[self getHashForRegion:region didEnter:didEnter]];
    }else{
        NSDictionary *offlineInfo = [[NSUserDefaults standardUserDefaults] valueForKey:@"offlineinfo"];
        NSString *method = [offlineInfo valueForKey:@"method"];
        NSURL *url = [NSURL URLWithString:[offlineInfo valueForKey:@"url"]];
        NSDictionary *headers = [offlineInfo valueForKey:@"headers"];
        
        NSDictionary *location = [self getLocationHash:self.locationManager.location];
        CLCircularRegion *circle = (CLCircularRegion*)region;
        NSMutableDictionary *regionHash = [NSMutableDictionary dictionary];
        
        NSString *identifier = [circle identifier];
        double radius = [circle radius];
        
        [regionHash setObject:identifier forKey:@"identifier"];
        [regionHash setObject:[NSNumber numberWithDouble:radius] forKey:@"radius"];
        [regionHash setObject:location forKey:@"location"];
        
        NSString *action = @"out";
        if(didEnter){
            action = @"in";
        }
        [regionHash setObject:action forKey:@"action"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                               cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
        [request setHTTPMethod:method];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        for(NSString *key in [headers allKeys]){
            [request setValue:[headers valueForKey:key] forHTTPHeaderField:key];
        }
        
        NSData *requestData = [NSJSONSerialization dataWithJSONObject:regionHash options:NSJSONWritingPrettyPrinted error:nil];
        
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
        [request setHTTPBody: requestData];
        
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
            //
            NSLog(@"--------------- Fence Posted ---------------------");
        }];
        
    }
    
}



@end
