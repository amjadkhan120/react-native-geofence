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
@property (nonatomic, strong) NSMutableDictionary *eventsCallbackBlocks;

@end

@implementation RNGeoLocationManager

@synthesize eventsCallbackBlocks = _eventsCallbackBlocks;

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
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [self.locationManager startMonitoringSignificantLocationChanges];
    }
    return self;
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}

-(NSMutableDictionary*)eventsCallbackBlocks{
    if(!_eventsCallbackBlocks){
        _eventsCallbackBlocks = [NSMutableDictionary dictionary];
    }
    return _eventsCallbackBlocks;
}

-(void)addListener:(NSString *)event callback:(void (^)(NSDictionary *))callback{
    if(callback){
        [self.eventsCallbackBlocks setObject:callback forKey:event];
    }
    
}

-(NSString*)setConfig:(NSDictionary*)config{
    if(config){
        [[NSUserDefaults standardUserDefaults] setObject:config forKey:@"offlineinfo"];
        return @"configured";
    }
    return @"configuration option can't be nil";
    
}


-(NSDictionary*)getLocation{
    [self.locationManager startUpdatingLocation];
    CLLocation *location = [self.locationManager location];
    if(location){
        NSDictionary *map = [self getLocationHash:location];
        return map;
    }
    [self requestLocationUpdate];
    return nil;
}

-(void)requestLocationUpdate{
    [self.locationManager requestLocation];
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
    
    
    NSSet *monitoredRegionSet = [self.locationManager monitoredRegions];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@",region.identifier];
    NSSet *filteredRegions = [monitoredRegionSet filteredSetUsingPredicate:predicate];
    if(filteredRegions.count > 0){
        //already added fence with same id.
        NSLog(@"%@",[filteredRegions allObjects]);
        // This will fire geofence Event, if user is allready in the fence.
        [self.locationManager requestStateForRegion:[[filteredRegions allObjects]firstObject]];
        success(@"Already added,Trying to add a geofence with same id");
        return;
    }
    
    [self.locationManager startMonitoringForRegion:region];
    success(@"Geofence Added successfully");
    
    // This will fire geofence Event, if user is allready in the fence.
    [self.locationManager requestStateForRegion:region];
}

- (void) removeGeofences:(NSArray*)identifiers success:(void (^)(NSString*))success error:(void (^)(NSString*))error{
    NSSet *monitoredRegions = [self.locationManager monitoredRegions];
    [monitoredRegions enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
        [self.locationManager stopMonitoringForRegion:(CLRegion*)obj];
    }];
    
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
        
        CLLocation *location = self.locationManager.location;
        CLCircularRegion *circle = (CLCircularRegion*)region;
        NSMutableDictionary *regionHash = [NSMutableDictionary dictionary];
        
        NSString *identifier = [circle identifier];
        
        [regionHash setObject:identifier forKey:@"id"];
        
        [regionHash setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"lat"];
        [regionHash setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"lng"];
        
        NSString *action = @"out";
        NSString *notifAct = @"EXIT";
        if(didEnter){
            action = @"in";
            notifAct = @"ENTER";
        }
        [regionHash setObject:action forKey:@"rule"];
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
            
            //NSDictionary *responseInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
             NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
            if(httpResponse.statusCode == 200){
                UILocalNotification *notification = [[UILocalNotification alloc]init];
                notification.alertBody = [NSString stringWithFormat:@"%@ Fence %@ ",notifAct,region.identifier];
                notification.soundName = @"Default";
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
            }
            
        }];
        
    }
    
}

#pragma mark - Application Delegate

-(void)applicationDidBecomeActive:(NSNotification*)notification{
    [self.locationManager startMonitoringSignificantLocationChanges];
}
-(void)applicationDidEnterBackground:(NSNotification*)notification{
    [self.locationManager stopMonitoringSignificantLocationChanges];
}

#pragma mark - LocationManager Delegate

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{
    
}

-(void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error{
    NSLog(@"==== Location Manager ====");
    NSLog(@"Monitoring failed for region with identifier: %@",region.identifier);
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    NSLog(@"==== Location Manager ====");
    NSLog(@"failed with the following error: %@",error.localizedDescription);
}

-(void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region{
    if(state == CLRegionStateInside && [[UIApplication sharedApplication]applicationState] == UIApplicationStateActive){
        [self didHitFence:region didEnter:true];
    }
}


-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    NSLog(@"==== Location Manager ====");
    NSLog(@"-location: ");
    void (^locationBlock)() = [self.eventsCallbackBlocks objectForKey:@"location"];
    if(locationBlock){
        CLLocation *location = [locations lastObject];
        NSDictionary *locationHash = [self getLocationHash:location];
        locationBlock(locationHash);
    }
}

@end
