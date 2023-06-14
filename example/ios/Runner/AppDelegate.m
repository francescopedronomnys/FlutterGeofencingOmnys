#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"

#import <flutter_geofencing_omnys/FlutterGeofencingOmnysPlugin.h>

void registerPlugins(NSObject<FlutterPluginRegistry>* registry) {
  [GeneratedPluginRegistrant registerWithRegistry:registry];
}

@implementation AppDelegate 

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [FlutterGeofencingOmnysPlugin setPluginRegistrantCallback:registerPlugins];
  [FlutterGeofencingOmnysPlugin locationCallback:self];
    
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region { 
    NSLog(@"didDetermineState %s for region: %@", state == CLRegionStateInside ? "INSIDE" : "OUTSIDE", [region identifier]);
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region { 
    NSLog(@"didEnterRegion: %@", [region identifier]);
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region { 
    NSLog(@"didExitRegion: %@", [region identifier]);
}
@end
