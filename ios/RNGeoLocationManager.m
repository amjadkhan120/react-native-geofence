//
//  RNGeoLocationManager.m
//  RNGeofence
//
//  Created by zigron on 11/08/2017.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "RNGeoLocationManager.h"
#import <UIKit/UIKit.h>
#import <SystemConfiguration/CaptiveNetwork.h>

@interface RNGeoLocationManager () <CLLocationManagerDelegate>


@property (nonatomic, strong) NSMutableDictionary *eventsCallbackBlocks;


@end

@implementation RNGeoLocationManager

@synthesize eventsCallbackBlocks    = _eventsCallbackBlocks;
@synthesize locationManager         = _locationManager;
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
    }
    return self;
}

-(void)setLocationManager:(CLLocationManager *)locationManager{
    if(!_locationManager){
        _locationManager = locationManager;
    }
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
        [[NSUserDefaults standardUserDefaults] synchronize];
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

-(void)getCurrentWifi:(void (^)(NSArray *))success error:(void (^)(NSString *))error{
    
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();
    NSLog(@"Supported interfaces: %@", ifs);
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *ifnam in ifs) {
        NSDictionary *info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        NSLog(@"%@ => %@", ifnam, info);
        if (info && [info count]) { [array addObject:info]; }
    }
    if(array.count > 0){
        success(array);
    }else{
        error(@"No Wifi connection found");
    }
}

-(void)addGeofence:(NSDictionary *)params success:(void (^)(NSString *))success error:(void (^)(NSString *))error{
    if(![CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]){
        error(@"Geofencing is not supported on this device!");
        return;
    }
    if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways){
        [self.locationManager requestAlwaysAuthorization];
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
        CLCircularRegion *oldRegion = [[filteredRegions allObjects] lastObject];
        if(oldRegion.radius != region.radius || oldRegion.center.latitude != region.center.latitude || oldRegion.center.longitude != oldRegion.center.longitude){
            // Region's updated, update to locationmanager aswell.
            [self.locationManager stopMonitoringForRegion:oldRegion];
            [self.locationManager startMonitoringForRegion:region];
        }
        // This will fire geofence Event, if user is allready in the fence.
        [self performSelector:@selector(requestFenceState:) withObject:[[filteredRegions allObjects] firstObject] afterDelay:3.0];
        //[self.locationManager requestStateForRegion:[[filteredRegions allObjects]firstObject]];
        success(@"Already added,Trying to add a geofence with same id");
        return;
    }
    
    [self.locationManager startMonitoringForRegion:region];
    success(@"Geofence Added successfully");
    
    // This will fire geofence Event, if user is allready in the fence.
    [self performSelector:@selector(requestFenceState:) withObject:region afterDelay:3.0];
    
}

-(void)requestFenceState:(id)object{
    if([object isKindOfClass:[CLCircularRegion class]]){
        CLCircularRegion *region = (CLCircularRegion*)object;
        BOOL didEnter = [region containsCoordinate:self.locationManager.location.coordinate];
        if(didEnter){
            [self didHitFence:region didEnter:didEnter];
        }
    }
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
        [self addLog:[NSString stringWithFormat:@"Fence %@ didEnter: %d",region.identifier,didEnter]];
        [self addLog:[NSString stringWithFormat:@"Fence %@ Call Send to JS",region.identifier]];
        //[[NSUserDefaults standardUserDefaults]setValue:[NSNumber numberWithBool:didEnter] forKey:region.identifier];
        //[[NSUserDefaults standardUserDefaults] synchronize];
        [self.delegate didHitGeofence:[self getHashForRegion:region didEnter:didEnter]];
    }else{
        UIApplication*    app = [UIApplication sharedApplication];
        __block UIBackgroundTaskIdentifier task = [app beginBackgroundTaskWithExpirationHandler:^{
            [app endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }];
        [self addLog:[NSString stringWithFormat:@"Fence %@ didEnter: %d",region.identifier,didEnter]];
        UILocalNotification *notification = [[UILocalNotification alloc]init];
        notification.alertTitle = [NSString stringWithFormat:@"Fence Update"];
        notification.alertBody = [NSString stringWithFormat:@"Fence %@ didEnter: %d",region.identifier,didEnter];
        notification.soundName = @"Default";
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        /*BOOL previousState = [[[NSUserDefaults standardUserDefaults]valueForKey:region.identifier] boolValue];
        if(previousState != didEnter){
            //fire only when current & previous state differe,
            // this logic is to avoid triggering same event multiple time
            [[NSUserDefaults standardUserDefaults]setValue:[NSNumber numberWithBool:didEnter] forKey:region.identifier];
            [[NSUserDefaults standardUserDefaults] synchronize]; */
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
            
            
            [self addLog:[NSString stringWithFormat:@"Region  %@ Hit With Data \n %@",region.identifier,regionHash]];
            
            NSData *requestData = [NSJSONSerialization dataWithJSONObject:regionHash options:NSJSONWritingPrettyPrinted error:nil];
            
            [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[requestData length]] forHTTPHeaderField:@"Content-Length"];
            [request setHTTPBody: requestData];
        
        
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *serverResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSHTTPURLResponse *responseURL = ( NSHTTPURLResponse*)response;
        if(responseURL.statusCode == 200){
            //fence triggerred
        }else{
            //fence triggerred
        }
        if(serverResponseData != nil){
            NSDictionary *responseInfo = [NSJSONSerialization JSONObjectWithData:serverResponseData options:NSJSONReadingAllowFragments error:nil];
            [self addLog:[NSString stringWithFormat:@"Region Hit %@ Response \n %@",region.identifier,responseInfo]];
        }else if(error){
            [self addLog:[NSString stringWithFormat:@"Fence Error Response : %@", [error localizedDescription]]];
        }
        /*
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse * _Nullable response, NSData * _Nullable data, NSError * _Nullable connectionError) {
                    
                    NSDictionary *responseInfo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
                    [self addLog:[NSString stringWithFormat:@"Region Hit %@ Response \n %@",region.identifier,responseInfo]];
                    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                    if(httpResponse.statusCode == 200){
                        UILocalNotification *notification = [[UILocalNotification alloc]init];
                        notification.alertBody = [NSString stringWithFormat:@"%@ Fence %@",notifAct,region.identifier];
                        notification.soundName = @"Default";
                        //[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                    }else{
                        
                        UILocalNotification *notification = [[UILocalNotification alloc]init];
                        notification.alertTitle = [NSString stringWithFormat:@"Error posting fence"];
                        notification.alertBody = [NSString stringWithFormat:@"%@ Fence %@ Error: %@",notifAct,region.identifier,connectionError];
                        notification.soundName = @"Default";
                        //[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                        
                    }
                    
                    [app endBackgroundTask:task];
                    task = UIBackgroundTaskInvalid;
                    
                }];
                
            });
            */
        /*}else{
            [self addLog:[NSString stringWithFormat:@"Fence %@ Call Ignored didEnter: %d",region.identifier,didEnter]];
        }*/
        if(didEnter && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
            NSData *regiondata = [NSKeyedArchiver archivedDataWithRootObject:region];
            CLCircularRegion *cirlRegion = (CLCircularRegion*)region;
            CLLocation *regionLocation = [[CLLocation alloc]initWithCoordinate:cirlRegion.center altitude:self.locationManager.location.altitude horizontalAccuracy:self.locationManager.location.horizontalAccuracy verticalAccuracy:self.locationManager.location.verticalAccuracy timestamp:self.locationManager.location.timestamp];
            CLLocation *p1Location = [[CLLocation alloc]initWithCoordinate:self.locationManager.location.coordinate altitude:self.locationManager.location.altitude horizontalAccuracy:self.locationManager.location.horizontalAccuracy verticalAccuracy:self.locationManager.location.verticalAccuracy timestamp:self.locationManager.location.timestamp];
            NSData *locationData = [NSKeyedArchiver archivedDataWithRootObject:regionLocation];
            NSData *p1locData = [NSKeyedArchiver archivedDataWithRootObject:p1Location];
            [[NSUserDefaults standardUserDefaults] setObject:regiondata forKey:@"currentRegion"];
            [[NSUserDefaults standardUserDefaults] setObject:locationData forKey:@"regionLocation"];
            [[NSUserDefaults standardUserDefaults] setObject:p1locData forKey:@"p1location"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.locationManager startUpdatingLocation];
        }
        if(task != UIBackgroundTaskInvalid){
            [app endBackgroundTask:task];
            task = UIBackgroundTaskInvalid;
        }
        
    }
    

}
-(void)updatedLocations:(NSArray<CLLocation *> *)locations{
    CLLocation *location = [locations lastObject];
    //if([[UIApplication sharedApplication]applicationState] == UIApplicationStateBackground){
    NSData *regionData = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentRegion"];
    
    if(regionData && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive){
        //[[self.locationManager monitoredRegions] enumerateObjectsUsingBlock:^(__kindof CLRegion * _Nonnull obj, BOOL * _Nonnull stop) {
        
            NSData *locationdata = [[NSUserDefaults standardUserDefaults] objectForKey:@"regionLocation"];
        NSData *p1Data = [[NSUserDefaults standardUserDefaults] valueForKey:@"p1location"];
            NSData *p2Data = [[NSUserDefaults standardUserDefaults] valueForKey:@"p2location"];
        if(!p2Data){
            [[NSUserDefaults standardUserDefaults] setObject:p1Data forKey:@"p2location"];
            NSData *locData = [NSKeyedArchiver archivedDataWithRootObject:location];
            [[NSUserDefaults standardUserDefaults] setObject:locData forKey:@"p1location"];
            return;
        }
        
        CLLocation *p1Location = [NSKeyedUnarchiver unarchiveObjectWithData:p1Data];
        CLLocation *p2Location = [NSKeyedUnarchiver unarchiveObjectWithData:p2Data];
        
            CLLocation *regionLocation = [NSKeyedUnarchiver unarchiveObjectWithData:locationdata];
            CLCircularRegion *cirlRegion = (CLCircularRegion*)[NSKeyedUnarchiver unarchiveObjectWithData:regionData];
            double distance = [location distanceFromLocation:regionLocation];
        
        double curp2dist = [p2Location distanceFromLocation:location];
        double p1p2dist = [p1Location distanceFromLocation:p2Location];
        BOOL movingAway = false;
        if(curp2dist > p1p2dist){
            // moving away from fence
            movingAway = true;
            UILocalNotification *notification = [[UILocalNotification alloc]init];
            notification.alertBody = [NSString stringWithFormat:@"Moving Away"];
            notification.soundName = @"Default";
            //[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        }else{
            // moving into fence
            UILocalNotification *notification = [[UILocalNotification alloc]init];
            notification.alertBody = [NSString stringWithFormat:@"Moving In"];
            notification.soundName = @"Default";
            //[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        }
            double diffDst = distance - cirlRegion.radius;
        
        
        
        
        
        
            if(diffDst > 10 && diffDst < 50.0 && movingAway){
                [self.locationManager stopUpdatingLocation];
                [self didHitFence:cirlRegion didEnter:false];
                [self addLog:[NSString stringWithFormat:@"Manual Fence Trigger %@",cirlRegion.identifier]];
                //[self.locationManager requestStateForRegion:(CLRegion*)cirlRegion];
                /*
                UILocalNotification *notification = [[UILocalNotification alloc]init];
                notification.alertTitle = [NSString stringWithFormat:@"Jugar Fit"];
                notification.alertBody = [NSString stringWithFormat:@"Fence %@ ,%f",cirlRegion.identifier,diffDst];
                notification.soundName = @"Default";
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                */
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"currentRegion"];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"regionLocation"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                return;
            }else{/*
                UILocalNotification *notification = [[UILocalNotification alloc]init];
                notification.alertTitle = [NSString stringWithFormat:@"Too Far"];
                notification.alertBody = [NSString stringWithFormat:@"Fence %@ ,%f",cirlRegion.identifier,diffDst];
                notification.soundName = @"Default";
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];*/
                
            }
        /*if(location.speed <=0){
            // device is still, not moving.
            [self.locationManager stopUpdatingLocation];
            [self.locationManager startMonitoringSignificantLocationChanges];
            [[NSUserDefaults standardUserDefaults] setObject:@YES forKey:@"locationUpdateStop"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        else{
            BOOL isStop = [[[NSUserDefaults standardUserDefaults]valueForKey:@"locationUpdateStop"] boolValue];
            if(isStop && location.speed > 0){
                // device is moving & user is in a region.
                [[NSUserDefaults standardUserDefaults] setObject:@NO forKey:@"locationUpdateStop"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [self.locationManager startUpdatingLocation];
                
            }
        }*/
        //}];
    }
     /*
      // Only process when app is in Foreground.
      else if([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive){
        //background location fetched.
        // process for possible fence hits.
        __block CLLocation *currentLocation = location;
        [[self.locationManager monitoredRegions] enumerateObjectsUsingBlock:^(__kindof CLRegion * _Nonnull obj, BOOL * _Nonnull stop) {
            CLCircularRegion *cirlRegion = (CLCircularRegion*)obj;
            CLLocation *regionLocation = [[CLLocation alloc] initWithLatitude:cirlRegion.center.latitude longitude:cirlRegion.center.longitude];
            BOOL didEnter = [cirlRegion containsCoordinate:currentLocation.coordinate];
            double distance = [currentLocation distanceFromLocation:regionLocation];
            double diffDst = distance - cirlRegion.radius;
            if(diffDst <=0 || didEnter){
                //In the Fence.
                [self didHitFence:cirlRegion didEnter:true];
                [self addLog:[NSString stringWithFormat:@"Manual Fence Trigger %@ InBackground",cirlRegion.identifier]];
            }
            else if(diffDst > 10 && diffDst < 50.0){
                //outside Fence
                [self didHitFence:cirlRegion didEnter:false];
                [self addLog:[NSString stringWithFormat:@"Manual Fence Trigger %@ InBackground",cirlRegion.identifier]];
            }
        }];
        
    } */
    void (^locationBlock)() = [self.eventsCallbackBlocks objectForKey:@"location"];
    if(locationBlock){
        NSDictionary *locationHash = [self getLocationHash:location];
        locationBlock(locationHash);
    }
    
}

-(void)addLog:(NSString*)logMessage{
    
    NSString *docDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) lastObject];
    NSString *storagefile = [docDir stringByAppendingPathComponent:@"nativelog.json"];
    
    BOOL isDir = false;
    if(![[NSFileManager defaultManager] fileExistsAtPath:storagefile isDirectory:&isDir]){
        [[NSFileManager defaultManager] createFileAtPath:storagefile contents:nil attributes:nil];
    }
    
    
    NSString *jsonStr = [NSString stringWithContentsOfFile:storagefile encoding:NSUTF8StringEncoding error:nil];
    NSData* jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    
    NSDictionary *jsonLog = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    NSArray *rows = [jsonLog valueForKey:@"rows"];
    
    NSString  *idStr = [[NSUUID UUID] UUIDString];
    NSString *level = @"log";
    NSString *color = @"#FFF";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
    NSString *timeStamp = [formatter stringFromDate:[NSDate date]];
    NSString *message = logMessage;
    
    NSMutableDictionary *newLogRow = [NSMutableDictionary dictionary];
    [newLogRow setValue:level forKey:@"level"];
    [newLogRow setValue:color forKey:@"color"];
    [newLogRow setValue:idStr forKey:@"id"];
    [newLogRow setValue:timeStamp forKey:@"timeStamp"];
    [newLogRow setValue:message forKey:@"message"];
    [newLogRow setValue:[NSNumber numberWithInteger:rows.count] forKey:@"lengthAtInsertion"];
    
    NSMutableArray *newRows = [NSMutableArray array];
    if(rows){
        [newRows addObjectsFromArray:rows];
    }
    [newRows addObject:newLogRow];
    
    NSMutableDictionary *newObject = [NSMutableDictionary dictionary];
    [newObject setValue:newRows forKey:@"rows"];
    NSData *newJsonData = [NSJSONSerialization dataWithJSONObject:newObject options:0 error:nil];
    [newJsonData writeToFile:storagefile atomically:true];
}

@end
