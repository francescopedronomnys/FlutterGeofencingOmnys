// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_geofencing_omnys/src/callback_dispatcher.dart';

const int _kEnterEvent = 1;
const int _kExitEvent = 2;
const int _kDwellEvent = 4;

/// Valid geofencing events.
///
/// Note: `GeofenceEvent.dwell` is not supported on iOS.
enum GeofenceEvent { enter, exit, dwell }

// Internal.
int geofenceEventToInt(GeofenceEvent e) {
  switch (e) {
    case GeofenceEvent.enter:
      return _kEnterEvent;
    case GeofenceEvent.exit:
      return _kExitEvent;
    case GeofenceEvent.dwell:
      return _kDwellEvent;
    default:
      throw UnimplementedError();
  }
}

// TODO(bkonyi): handle event masks
// Internal.
GeofenceEvent intToGeofenceEvent(int e) {
  switch (e) {
    case _kEnterEvent:
      return GeofenceEvent.enter;
    case _kExitEvent:
      return GeofenceEvent.exit;
    case _kDwellEvent:
      return GeofenceEvent.dwell;
    default:
      throw UnimplementedError();
  }
}

/// A circular region which represents a geofence.
class GeofenceRegion {
  /// The unique identifier of region.
  final String identifier;

  /// The proximity UUID of region.
  ///
  /// For iOS, this value can not be null.
  final String? proximityUUID;

  /// The major number of region.
  ///
  /// For both Android and iOS, this value can be null.
  final int? major;

  /// The minor number of region.
  ///
  /// For both Android and iOS, this value can be null.
  final int? minor;

  /// Constructor for creating [Region] object.
  ///
  /// The [proximityUUID] must not be null when [Platform.isIOS]
  GeofenceRegion({
    required this.identifier,
    this.proximityUUID,
    this.major,
    this.minor,
  }) {
    if (Platform.isIOS) {
      assert(
        proximityUUID != null,
        'Scanning beacon for iOS must provided proximityUUID',
      );
    }
  }

  /// Constructor for deserialize json [Map] into [Region] object.
  GeofenceRegion.fromJson(dynamic json)
      : this(
          identifier: json['identifier'],
          proximityUUID: json['proximityUUID'],
          major: _parseMajorMinor(json['major']),
          minor: _parseMajorMinor(json['minor']),
        );

  /// Return the serializable of this object into [Map].
  dynamic get toJson {
    final map = <String, dynamic>{
      'identifier': identifier,
    };

    if (proximityUUID != null) {
      map['proximityUUID'] = proximityUUID;
    }

    if (major != null) {
      map['major'] = major;
    }

    if (minor != null) {
      map['minor'] = minor;
    }

    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeofenceRegion &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;

  static int? _parseMajorMinor(dynamic number) {
    if (number is num) {
      return number.toInt();
    }

    if (number is String) {
      return int.tryParse(number);
    }

    return null;
  }

  @override
  String toString() {
    return json.encode(toJson);
  }
}

class GeofencingManager {
  static const MethodChannel _channel =
      MethodChannel('plugins.flutter.io/geofencing_plugin');

  /// Initialize the plugin and request relevant permissions from the user.
  static Future<void> initialize() async {
    final CallbackHandle? callback =
        PluginUtilities.getCallbackHandle(callbackDispatcher);
    assert(callback != null);
    await _channel.invokeMethod('GeofencingPlugin.initializeService',
        <dynamic>[callback!.toRawHandle()]);
  }

  /// Register for geofence events for a [GeofenceRegion].
  ///
  /// `region` is the geofence region to register with the system.
  /// `callback` is the method to be called when a geofence event associated
  /// with `region` occurs.
  ///
  /// Note: `GeofenceEvent.dwell` is not supported on iOS. If the
  /// `GeofenceRegion` provided only requests notifications for a
  /// `GeofenceEvent.dwell` trigger on iOS, `UnsupportedError` is thrown.
  static Future<void> registerGeofence(GeofenceRegion region,
      void Function(List<String> id, GeofenceEvent event) callback) async {
    final List<dynamic> args = <dynamic>[
      PluginUtilities.getCallbackHandle(callback)!.toRawHandle()
    ];
    args.add(region.toJson);
    await _channel.invokeMethod('GeofencingPlugin.registerGeofence', args);
  }

  static Future<void> determineGeofenceState(GeofenceRegion region) async {
    return determineGeofenceStateById(region.identifier);
  }

  static Future<void> determineGeofenceStateById(String id) async {
    await _channel
        .invokeMethod('GeofencingPlugin.determineGeofenceState', <dynamic>[id]);
  }

  /// get all geofence identifiers
  static Future<List<String>> getRegisteredGeofenceIds() async =>
      List<String>.from(await _channel
          .invokeMethod('GeofencingPlugin.getRegisteredGeofenceIds'));

  /// Stop receiving geofence events for a given [GeofenceRegion].
  static Future<bool> removeGeofence(GeofenceRegion region) async =>
      await removeGeofenceById(region.identifier);

  /// Stop receiving geofence events for an identifier associated with a
  /// geofence region.
  static Future<bool> removeGeofenceById(String id) async => await _channel
      .invokeMethod('GeofencingPlugin.removeGeofence', <dynamic>[id]);
}
