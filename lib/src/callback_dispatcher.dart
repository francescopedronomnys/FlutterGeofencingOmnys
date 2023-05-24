// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_geofencing_omnys/src/geofencing.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  const MethodChannel _backgroundChannel =
      MethodChannel('plugins.flutter.io/geofencing_plugin_background');
  WidgetsFlutterBinding.ensureInitialized();

  _backgroundChannel.setMethodCallHandler((MethodCall call) async {
    final List<dynamic> args = call.arguments;
    final Function? callback = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(args[0]));
    assert(callback != null);
    final List<String> triggeringGeofences = args[1].cast<String>();
    final GeofenceEvent event = intToGeofenceEvent(args[2]);
    callback!(triggeringGeofences, event);
  });
  _backgroundChannel.invokeMethod('GeofencingService.initialized');
}
