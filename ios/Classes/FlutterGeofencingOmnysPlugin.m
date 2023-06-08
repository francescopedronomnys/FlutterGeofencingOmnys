
// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

#import "FlutterGeofencingOmnysPlugin.h"

#import <CoreLocation/CoreLocation.h>
#import "FBUtils.h"

@implementation FlutterGeofencingOmnysPlugin {
  CLLocationManager *_locationManager;
  FlutterEngine *_headlessRunner;
  FlutterMethodChannel *_callbackChannel;
  FlutterMethodChannel *_mainChannel;
  NSObject<FlutterPluginRegistrar> *_registrar;
  NSUserDefaults *_persistentState;
  NSMutableArray *_eventQueue;
  int64_t _onLocationUpdateHandle;
}

static const NSString *kRegionKey = @"region";
static const NSString *kEventType = @"event_type";
static const int kEnterEvent = 1;
static const int kExitEvent = 2;
static const NSString *kCallbackMapping = @"geofence_region_callback_mapping";
static FlutterGeofencingOmnysPlugin *instance = nil;
static FlutterPluginRegistrantCallback registerPlugins = nil;
static BOOL initialized = NO;
static BOOL backgroundIsolateRun = NO;
#pragma mark FlutterPlugin Methods

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  @synchronized(self) {
    if (instance == nil) {
      instance = [[FlutterGeofencingOmnysPlugin alloc] init:registrar];
      [registrar addApplicationDelegate:instance];
    }
  }
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
  registerPlugins = callback;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSArray *arguments = call.arguments;
  if ([@"GeofencingPlugin.initializeService" isEqualToString:call.method]) {
    NSAssert(arguments.count == 1,
             @"Invalid argument count for 'GeofencingPlugin.initializeService'");
    [self startGeofencingService:[arguments[0] longValue]];
    result(@(YES));
  } else if ([@"GeofencingService.initialized" isEqualToString:call.method]) {
    @synchronized(self) {
      initialized = YES;
        // Send the geofence events that occurred while the background
        // isolate was initializing.
        while ([_eventQueue count] > 0) {
            NSDictionary* event = _eventQueue[0];
            [_eventQueue removeObjectAtIndex:0];
            CLRegion* region = [event objectForKey:kRegionKey];
            int type = [[event objectForKey:kEventType] intValue];
            [self sendLocationEvent:region eventType: type];
        }
    }
    result(nil);
  } else if ([@"GeofencingPlugin.registerGeofence" isEqualToString:call.method]) {
    [self registerGeofence:arguments];
    result(@(YES));
  } else if ([@"GeofencingPlugin.removeGeofence" isEqualToString:call.method]) {
    result(@([self removeGeofence:arguments]));
  } else if ([@"GeofencingPlugin.getRegisteredGeofenceIds" isEqualToString:call.method]) {
      result([self getMonitoredRegionIds:arguments]);
  }
  else {
    result(FlutterMethodNotImplemented);
  }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Check to see if we're being launched due to a location event.
  if (launchOptions[UIApplicationLaunchOptionsLocationKey] != nil) {
    // Restart the headless service.
    [self startGeofencingService:[self getCallbackDispatcherHandle]];
  }

  // Note: if we return NO, this vetos the launch of the application.
  return YES;
}

#pragma mark LocationManagerDelegate Methods
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
  @synchronized(self) {
    if (initialized) {
      [self sendLocationEvent:region eventType:kEnterEvent];
    } else {
      NSDictionary *dict = @{
        kRegionKey: region,
        kEventType: @(kEnterEvent)
      };
      [_eventQueue addObject:dict];
    }
  }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
  @synchronized(self) {
    if (initialized) {
      [self sendLocationEvent:region eventType:kExitEvent];
    } else {
      NSDictionary *dict = @{
        kRegionKey: region,
        kEventType: @(kExitEvent)
      };
      [_eventQueue addObject:dict];
    }
  }
}

- (void)locationManager:(CLLocationManager *)manager
    monitoringDidFailForRegion:(CLRegion *)region
                     withError:(NSError *)error {
}

- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    int eventType;
    if(state == CLRegionStateInside) {
        eventType = kEnterEvent;
    } else if(state == CLRegionStateOutside) {
        eventType = kExitEvent;
    } else {
        return;
    }
    if (initialized) {
      [self sendLocationEvent:region eventType:eventType];
    } else {
      NSDictionary *dict = @{
        kRegionKey: region,
        kEventType: @(eventType)
      };
      [_eventQueue addObject:dict];
    }
}

#pragma mark GeofencingPlugin Methods

- (void)sendLocationEvent:(CLRegion *)region eventType:(int)event {
  NSAssert([region isKindOfClass:[CLBeaconRegion class]], @"region must be CLBeaconRegion");
  int64_t handle = [self getCallbackHandleForRegionId:region.identifier];
  if (handle != 0 && _callbackChannel != nil) {
      [_callbackChannel
       invokeMethod:@""
        arguments:@[
            @(handle), @[ region.identifier ], @(event)
        ]];
  }
}

- (instancetype)init:(NSObject<FlutterPluginRegistrar> *)registrar {
  self = [super init];
  NSAssert(self, @"super init cannot be nil");
  _persistentState = [NSUserDefaults standardUserDefaults];
  _eventQueue = [[NSMutableArray alloc] init];
  _locationManager = [[CLLocationManager alloc] init];
  [_locationManager setDelegate:self];
  [_locationManager requestAlwaysAuthorization];
  _locationManager.allowsBackgroundLocationUpdates = YES;

  _headlessRunner = [[FlutterEngine alloc] initWithName:@"GeofencingIsolate" project:nil allowHeadlessExecution:YES];
  _registrar = registrar;

  _mainChannel = [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/geofencing_plugin"
                                             binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:self channel:_mainChannel];

  _callbackChannel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/geofencing_plugin_background"
                                  binaryMessenger:_headlessRunner.binaryMessenger];
  return self;
}

- (void)startGeofencingService:(int64_t)handle {
  [self setCallbackDispatcherHandle:handle];
  FlutterCallbackInformation *info = [FlutterCallbackCache lookupCallbackInformation:handle];
  NSAssert(info != nil, @"failed to find callback");
  NSString *entrypoint = info.callbackName;
  NSString *uri = info.callbackLibraryPath;
  [_headlessRunner runWithEntrypoint:entrypoint libraryURI:uri];
  NSAssert(registerPlugins != nil, @"failed to set registerPlugins");

  // Once our headless runner has been started, we need to register the application's plugins
  // with the runner in order for them to work on the background isolate. `registerPlugins` is
  // a callback set from AppDelegate.m in the main application. This callback should register
  // all relevant plugins (excluding those which require UI).
  if (!backgroundIsolateRun) {
    registerPlugins(_headlessRunner);
  }
  [_registrar addMethodCallDelegate:self channel:_callbackChannel];
  backgroundIsolateRun = YES;
}

- (void)registerGeofence:(NSArray *)arguments {
  int64_t callbackHandle = [arguments[0] longLongValue];
  NSDictionary *regionDictionary = arguments[1];
  CLBeaconRegion *region = [FBUtils regionFromDictionary:regionDictionary];
    

  [self setCallbackHandleForRegionId:callbackHandle regionId:region.identifier];
  [self->_locationManager startMonitoringForRegion:region];
}

- (BOOL)removeGeofence:(NSArray *)arguments {
  NSString *identifier = arguments[0];
  for (CLRegion *region in [self->_locationManager monitoredRegions]) {
    if ([region.identifier isEqual:identifier]) {
      [self->_locationManager stopMonitoringForRegion:region];
      [self removeCallbackHandleForRegionId:identifier];
      return YES;
    }
  }
  return NO;
}

-(NSArray*)getMonitoredRegionIds:()arguments{
    NSMutableArray *geofenceIds = [[NSMutableArray alloc] init];
    for (CLRegion *region in [self->_locationManager monitoredRegions]) {
        [geofenceIds addObject:region.identifier];
    }
    return [NSArray arrayWithArray:geofenceIds];
}

- (int64_t)getCallbackDispatcherHandle {
  id handle = [_persistentState objectForKey:@"callback_dispatcher_handle"];
  if (handle == nil) {
    return 0;
  }
  return [handle longLongValue];
}

- (void)setCallbackDispatcherHandle:(int64_t)handle {
  [_persistentState setObject:[NSNumber numberWithLongLong:handle]
                       forKey:@"callback_dispatcher_handle"];
}

- (NSMutableDictionary *)getRegionCallbackMapping {
  const NSString *key = kCallbackMapping;
  NSMutableDictionary *callbackDict = [_persistentState dictionaryForKey:key];
  if (callbackDict == nil) {
    callbackDict = @{};
    [_persistentState setObject:callbackDict forKey:key];
  }
  return [callbackDict mutableCopy];
}

- (void)setRegionCallbackMapping:(NSMutableDictionary *)mapping {
  const NSString *key = kCallbackMapping;
  NSAssert(mapping != nil, @"mapping cannot be nil");
  [_persistentState setObject:mapping forKey:key];
}

- (int64_t)getCallbackHandleForRegionId:(NSString *)identifier {
  NSMutableDictionary *mapping = [self getRegionCallbackMapping];
  id handle = [mapping objectForKey:identifier];
  if (handle == nil) {
    return 0;
  }
  return [handle longLongValue];
}

- (void)setCallbackHandleForRegionId:(int64_t)handle regionId:(NSString *)identifier {
  NSMutableDictionary *mapping = [self getRegionCallbackMapping];
  [mapping setObject:[NSNumber numberWithLongLong:handle] forKey:identifier];
  [self setRegionCallbackMapping:mapping];
}

- (void)removeCallbackHandleForRegionId:(NSString *)identifier {
  NSMutableDictionary *mapping = [self getRegionCallbackMapping];
  [mapping removeObjectForKey:identifier];
  [self setRegionCallbackMapping:mapping];
}

@end
