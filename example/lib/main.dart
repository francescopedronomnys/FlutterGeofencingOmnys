import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_geofencing_omnys/flutter_geofencing_omnys.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String geofenceState = 'N/A';
  DateTime? lastUpdate;
  List<String> registeredGeofences = [];

  ReceivePort port = ReceivePort();

  @override
  void initState() {
    super.initState();
    IsolateNameServer.registerPortWithName(
        port.sendPort, 'geofencing_send_port');
    port.listen((dynamic data) {
      print('Event: $data');
      setState(() {
        geofenceState = data;
        lastUpdate = DateTime.now();
      });
    });
    initPlatformState();
  }

  @pragma('vm:entry-point')
  static void callback(List<String> ids, GeofenceEvent e) async {
    print('Fences: $ids Event: $e');
    final SendPort? send =
        IsolateNameServer.lookupPortByName('geofencing_send_port');
    send?.send(e.toString());
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    print('Initializing...');
    await GeofencingManager.initialize();
    print('Initialization done');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Geofencing Example'),
        ),
        body: Container(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Current state: $geofenceState - ${lastUpdate?.toIso8601String()}',
                textAlign: TextAlign.center,
              ),
              Center(
                child: ElevatedButton(
                  child: const Text('Register'),
                  onPressed: () {
                    GeofencingManager.registerGeofence(
                      GeofenceRegion(
                        identifier: "BlueUp",
                        proximityUUID: "ACFD065E-C3C0-11E3-9BBE-1A514932AC01",
                      ),
                      callback,
                    ).then((_) {
                      GeofencingManager.getRegisteredGeofenceIds()
                          .then((value) {
                        setState(() {
                          registeredGeofences = value;
                        });
                      });
                    });
                  },
                ),
              ),
              Text('Registered Geofences: $registeredGeofences'),
              Center(
                child: ElevatedButton(
                    child: const Text('Update state'),
                    onPressed: () =>
                        GeofencingManager.determineGeofenceStateById("BlueUp")),
              ),
              Center(
                child: ElevatedButton(
                  child: const Text('Unregister'),
                  onPressed: () =>
                      GeofencingManager.removeGeofenceById('BlueUp').then((_) {
                    GeofencingManager.getRegisteredGeofenceIds().then((value) {
                      setState(() {
                        registeredGeofences = value;
                      });
                    });
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
