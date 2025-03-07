import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter/material.dart';

import 'map_picker_strings.dart';

class PlacePickerResult {
  LatLng? latLng;
  String? address;

  PlacePickerResult(this.latLng, this.address);

  @override
  String toString() {
    return 'PlacePickerResult{latLng: $latLng, address: $address}';
  }
}

class PlacePickerScreen extends StatefulWidget {
  final String googlePlacesApiKey;
  final LatLng initialPosition;
  final Color mainColor;

  final MapPickerStrings? mapStrings;
  final String? placeAutoCompleteLanguage;

  const PlacePickerScreen(
      {Key? key,
      required this.googlePlacesApiKey,
      required this.initialPosition,
      required this.mainColor,
      this.mapStrings,
      this.placeAutoCompleteLanguage})
      : super(key: key);

  @override
  State<PlacePickerScreen> createState() => PlacePickerScreenState(
      googlePlacesApiKey: googlePlacesApiKey,
      initialPosition: initialPosition,
      mainColor: mainColor,
      mapStrings: mapStrings,
      placeAutoCompleteLanguage: placeAutoCompleteLanguage);
}

class PlacePickerScreenState extends State<PlacePickerScreen> {
  final String googlePlacesApiKey;
  final LatLng initialPosition;
  final Color mainColor;

  late MapPickerStrings strings;
  String? placeAutoCompleteLanguage;

  PlacePickerScreenState(
      {required this.googlePlacesApiKey,
      required this.initialPosition,
      required this.mainColor,
      required mapStrings,
      required placeAutoCompleteLanguage}) {
    centerCamera = LatLng(initialPosition.latitude, initialPosition.longitude);
    zoomCamera = 16;
    selectedLatLng = LatLng(initialPosition.latitude, initialPosition.longitude);

    _places = GoogleMapsPlaces(apiKey: googlePlacesApiKey);

    this.strings = mapStrings ?? MapPickerStrings.english();
    this.placeAutoCompleteLanguage = 'en';
  }

  late GoogleMapsPlaces _places;
  late GoogleMapController googleMapController;

  //Camera
  late LatLng centerCamera;
  late double zoomCamera;

  //My Location
  LatLng? myLocation;

  //Selected
  LatLng? selectedLatLng;
  String? selectedAddress;

  bool loadingAddress = false;
  bool movingCamera = false;

  bool ignoreGeocoding = false;

  static double _defaultZoom = 16;

  ///BASIC
  _moveCamera(LatLng latLng, double zoom) async {
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  Future<Position?> _getLocation() async {
    Position? locationData;
    try {
      await Geolocator.requestPermission();
      locationData = await Geolocator.getCurrentPosition();
    } catch (e) {
      locationData = null;
    }

    if (locationData != null) myLocation = LatLng(locationData.latitude, locationData.longitude);

    return locationData;
  }

  @override
  Widget build(BuildContext context) {
    _setSelectedAddress(LatLng latLng, String? address) async {
      setState(() {
        selectedAddress = address;
        selectedLatLng = LatLng(latLng.latitude, latLng.longitude);
      });
    }

    ///GO TO
    _searchPlace() async {
      var location;
      if (myLocation != null) {
        location = Location(lat: myLocation!.latitude, lng: myLocation!.longitude);
      } else {
        location = Location(lat: initialPosition.latitude, lng: initialPosition.longitude);
      }
      Prediction? p = await PlacesAutocomplete.show(
        context: context,
        apiKey: googlePlacesApiKey,
        mode: Mode.fullscreen,
        // Mode.fullscreen
        language: placeAutoCompleteLanguage,
        location: location,
      );

      if (p != null) {
        // get detail (lat/lng)
        PlacesDetailsResponse detail = await _places.getDetailsByPlaceId(p.placeId!);
        final lat = detail.result.geometry!.location.lat;
        final lng = detail.result.geometry!.location.lng;

        var latLng = LatLng(lat, lng);
        var address = p.description;

        CameraPosition newPosition = CameraPosition(target: latLng, zoom: _defaultZoom);

        ignoreGeocoding = true;
        googleMapController.animateCamera(CameraUpdate.newCameraPosition(newPosition));

        _setSelectedAddress(latLng, address);
      }
    }

    _goToMyLocation() async {
      await _getLocation();
      if (myLocation != null) {
        _moveCamera(myLocation!, _defaultZoom);
      }
    }

    ///WIDGETS
    Widget _mapButtons() {
      return Padding(
        padding: EdgeInsets.only(top: 40, left: 8, right: 8),
        child: Column(
          children: <Widget>[
            FloatingActionButton(
              heroTag: "FAB_SEARCH_PLACE",
              backgroundColor: Colors.white,
              child: Icon(
                Icons.search,
                color: Colors.black,
              ),
              onPressed: () {
                _searchPlace();
              },
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: FloatingActionButton(
                heroTag: "FAB_LOCATION",
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.my_location,
                  color: Colors.black,
                ),
                onPressed: () {
                  _goToMyLocation();
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              alignment: Alignment.topRight,
              children: <Widget>[
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: centerCamera,
                    zoom: zoomCamera,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (GoogleMapController controller) {
                    googleMapController = controller;
                  },
                  onTap: (latLng) {
                    CameraPosition newPosition = CameraPosition(target: latLng, zoom: _defaultZoom);
                    googleMapController.animateCamera(CameraUpdate.newCameraPosition(newPosition));
                  },
                  onCameraMoveStarted: () {
                    setState(() {
                      movingCamera = true;
                    });
                  },
                  onCameraMove: (position) {
                    centerCamera = position.target;
                    zoomCamera = position.zoom;
                  },
                  onCameraIdle: () async {
                    if (ignoreGeocoding) {
                      ignoreGeocoding = false;
                      setState(() {
                        movingCamera = false;
                      });
                    } else {
                      setState(() {
                        movingCamera = false;
                        loadingAddress = true;
                      });
                    }
                  },
                ),
                _mapButtons(),
                Center(
                  child: Container(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(
                      Icons.location_on,
                      size: 60,
                      color: mainColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            child: Column(
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                  child: ListTile(
                    title: Text(strings.address),
                    subtitle: selectedAddress == null
                        ? Text(strings.firstMessageSelectAddress)
                        : Text(selectedAddress!),
                    trailing: loadingAddress
                        ? CircularProgressIndicator(
                            backgroundColor: mainColor,
                          )
                        : null,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 160,
                        padding: EdgeInsets.only(right: 16),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(strings.cancel),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: !movingCamera && !loadingAddress && selectedAddress != null
                              ? () {
                                  PlacePickerResult result =
                                      PlacePickerResult(selectedLatLng, selectedAddress);
                                  print(result);

                                  Navigator.pop(context, result);
                                }
                              : null,
                          child: Text(
                            strings.selectAddress,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
