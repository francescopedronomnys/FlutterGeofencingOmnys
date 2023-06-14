#ifndef GeofencingPlugin_h
#define GeofencingPlugin_h

#import <Flutter/Flutter.h>

#import <CoreLocation/CoreLocation.h>
#import <CoreLocation/CLLocationManagerDelegate.h>

@protocol CustomLocationManagerDelegate <NSObject>

- (void)locationManager:(CLLocationManager *)manager
    didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region;

- (void)locationManager:(CLLocationManager *)manager
    didEnterRegion:(CLRegion *)region;

- (void)locationManager:(CLLocationManager *)manager
    didExitRegion:(CLRegion *)region;
@end

@interface FlutterGeofencingOmnysPlugin : NSObject<FlutterPlugin, CLLocationManagerDelegate>


+ (void) locationCallback:(id<CustomLocationManagerDelegate>) delegate;

@end
#endif
