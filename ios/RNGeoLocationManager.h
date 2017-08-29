//
//  RNGeoLocationManager.h
//  RNGeofence
//
//  Created by zigron on 11/08/2017.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol RNGeoLocationManagerDelegate <NSObject>

-(void)didHitGeofence:(NSDictionary*)fence;
@end

@interface RNGeoLocationManager : NSObject

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, weak) id <RNGeoLocationManagerDelegate> delegate;

+ (RNGeoLocationManager *)sharedManager;

-(NSString*)setConfig:(NSDictionary*)config;
-(NSDictionary*)getLocation;
-(void)requestLocationUpdate;
- (void) addListener:(NSString*)event callback:(void (^)(NSDictionary*))callback;

-(void)getCurrentWifi:(void (^)(NSArray *))success error:(void (^)(NSString *))error;

- (void) addGeofence:(NSDictionary*)params success:(void (^)(NSString*))success error:(void (^)(NSString*))error;
- (void) removeGeofences:(NSArray*)identifiers success:(void (^)(NSString*))success error:(void (^)(NSString*))error;
- (void)didHitFence:(CLRegion*)region didEnter:(BOOL)didEnter;
- (void)updatedLocations:(NSArray<CLLocation *> *)locations;
@end
