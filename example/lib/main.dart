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
  List<String> registeredGeofences = [];
  double latitude = 37.419851;
  double longitude = -122.078818;
  double radius = 150.0;
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
      });
    });
    initPlatformState();
  }

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
                    Text('Current state: $geofenceState'),
                    Center(
                      child: ElevatedButton(
                        child: const Text('Register'),
                        onPressed: () {
                          if (latitude == null) {
                            setState(() => latitude = 0.0);
                          }
                          if (longitude == null) {
                            setState(() => longitude = 0.0);
                          }
                          if (radius == null) {
                            setState(() => radius = 0.0);
                          }
                          GeofencingManager.registerGeofence(
                            GeofenceRegion(
                              identifier: "BlueUp",
                              proximityUUID:
                                  "ACFD065E-C3C0-11E3-9BBE-1A514932AC01",
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
                        child: const Text('Unregister'),
                        onPressed: () =>
                            GeofencingManager.removeGeofenceById('mtv')
                                .then((_) {
                          GeofencingManager.getRegisteredGeofenceIds()
                              .then((value) {
                            setState(() {
                              registeredGeofences = value;
                            });
                          });
                        }),
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Latitude',
                      ),
                      keyboardType: TextInputType.number,
                      controller:
                          TextEditingController(text: latitude.toString()),
                      onChanged: (String s) {
                        latitude = double.tryParse(s) ?? 0.0;
                      },
                    ),
                    TextField(
                        decoration:
                            const InputDecoration(hintText: 'Longitude'),
                        keyboardType: TextInputType.number,
                        controller:
                            TextEditingController(text: longitude.toString()),
                        onChanged: (String s) {
                          longitude = double.tryParse(s) ?? 0.0;
                        }),
                    TextField(
                        decoration: const InputDecoration(hintText: 'Radius'),
                        keyboardType: TextInputType.number,
                        controller:
                            TextEditingController(text: radius.toString()),
                        onChanged: (String s) {
                          radius = double.tryParse(s) ?? 0.0;
                        }),
                  ]))),
    );
  }
}
