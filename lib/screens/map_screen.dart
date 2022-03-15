  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:geocoding/geocoding.dart';
  import 'package:geolocator/geolocator.dart';
  import 'package:google_maps_flutter/google_maps_flutter.dart';

  import '../api_service/directions_repository.dart';
  import '../models/directions_model.dart';

  class MapScreen extends StatefulWidget {
    const MapScreen({Key? key}) : super(key: key);

    @override
    State<MapScreen> createState() => _MapScreenState();
  }

  class _MapScreenState extends State<MapScreen> {
    Completer<GoogleMapController> controllerGoogleMap = Completer();
    Position? position;
    static LatLng _initialPosition = const LatLng(11.013486, 75.958434);
    late GoogleMapController _googleMapController;
    Marker? _start;
    Marker? _destination;
    TextEditingController startCt = TextEditingController();
    TextEditingController destinationCt = TextEditingController();
    Directions? _info;
    final formKey = GlobalKey<FormState>();


    @override
    void dispose() {
      _googleMapController.dispose();
      super.dispose();

    }

    @override
    initState() {
      super.initState();
      getCurrentPosition();

    }

    @override
    Widget build(BuildContext context) {


      return Scaffold(
        resizeToAvoidBottomInset: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30),
                spreadRadius: 3,
                blurRadius: 7,
                offset: const Offset(0, -7),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: startCt,
                  onChanged: (text) {
                    checkLocation(text, 'start');
                  },
                  decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      border: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      labelText: 'Start',
                      labelStyle: const TextStyle(color: Colors.grey),
                      suffixIcon: IconButton(
                        onPressed: () async {
                          Position currentPosition = await _determinePosition();
                          _googleMapController.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(currentPosition.latitude,
                                    currentPosition.longitude),
                                zoom: 14.5,
                                tilt: 50.0,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.my_location),
                      )),
                  validator: (text) {
                    if (_start == null) {
                      return 'Enter Correct Address';
                    } else {
                      return null;
                    }
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                TextFormField(

                  controller: destinationCt,
                  onChanged: (text) {
                    checkLocation(text, 'destination');
                  },
                  decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      border: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: Colors.grey, width: 1.0),
                          borderRadius: BorderRadius.circular(10)),
                      labelText: 'Destination',
                      labelStyle: const TextStyle(color: Colors.grey)),
                  validator: (text) {
                    if (_destination == null) {
                      return 'Enter Correct Address';
                    } else {
                      return null;
                    }
                  },
                ),
                const SizedBox(
                  height: 15,
                ),
                _info != null
                    ? Text(
                        'DISTANCE: ${_info!.totalDistance}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      )
                    : const SizedBox(),
                ElevatedButton(
                  child: const Text('SHOW DIRECTION'),
                  onPressed: () {
                    var form = formKey.currentState;
                    if (form!.validate()) {
                      _addMarker();

                    }
                  },
                  style: ButtonStyle(
                      textStyle: MaterialStateProperty.all<TextStyle>(
                          const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                      backgroundColor:
                          MaterialStateProperty.all<Color>(Colors.red),
                      shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: const BorderSide(color: Colors.red)))),
                ),
              ],
            ),
          ),
        ),
        body: GoogleMap(
          onMapCreated: (controller) => _googleMapController = controller,
          initialCameraPosition: CameraPosition(
            target: _initialPosition,
            zoom: 14.4746,
          ),
          markers: {
            if (_start != null) _start!,
            if (_destination != null) _destination!,
          },
          polylines: {
            if (_info != null)
              Polyline(
                polylineId: const PolylineId('overview_polyline'),
                color: Colors.red,
                width: 5,
                points: _info!.polylinePoints
                    .map((e) => LatLng(e.latitude, e.longitude))
                    .toList(),
              ),
          },
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
      );
    }

    Future<Position> _determinePosition() async {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error(
            'Location permissions are permanently denied, we cannot request permissions.');
      }

      return await Geolocator.getCurrentPosition();
    }

    Future<void> getCurrentPosition() async {
      position = await _determinePosition();
      setState(() {
        _initialPosition = LatLng(position!.latitude, position!.longitude);
        _googleMapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_initialPosition.latitude,
                  _initialPosition.longitude),
              zoom:2,
              tilt: 50.0,
            ),
          ),
        );
      });
    }

    void _addMarker() async {
      final directions = await DirectionsRepository().getDirections(
          origin: _start!.position, destination: _destination!.position);
      setState(() => _info = directions);
      FocusManager.instance.primaryFocus?.unfocus();
      _googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _start!.position,
            zoom: 14.5,
            tilt: 50.0,
          ),
        ),
      );

    }

    Future<void> checkLocation(String text, String s) async {
      try {
        List<Location> locations = await locationFromAddress(text);
        if (locations.isNotEmpty) {
          setState(() {
            if (s == 'start') {
              _start = Marker(
                  markerId: const MarkerId('start'),
                  infoWindow: const InfoWindow(title: 'Start'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  position:
                      LatLng(locations[0].latitude, locations[0].longitude));
              _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(locations[0].latitude, locations[0].longitude),
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              );
            } else {
              _destination = Marker(
                  markerId: const MarkerId('destination'),
                  infoWindow: const InfoWindow(title: 'Start'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                  position:
                      LatLng(locations[0].latitude, locations[0].longitude));
              _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(locations[0].latitude, locations[0].longitude),
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              );
            }
          });
        }
      } catch (e) {
        print(e);
      }
    }
  }
