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

@property (nonatomic, weak) id <RNGeoLocationManagerDelegate> delegate;

+ (RNGeoLocationManager *)sharedManager;

-(void)didHitFence:(CLRegion*)region didEnter:(BOOL)didEnter;
@end
