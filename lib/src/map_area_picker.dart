import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_utils/utils/poly_utils.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart' as $;

import 'map_picker_strings.dart';

class AreaPickerResult {
  LatLng selectedLatLng;
  double radiusInMeters;
  List<LatLng> polygonPoints;

  AreaPickerResult(this.selectedLatLng, this.radiusInMeters, this.polygonPoints);

  @override
  String toString() {
    return 'AreaPickerResult{selectedLatLng: $selectedLatLng, radiusInMeters: $radiusInMeters, polygonPoints: $polygonPoints}';
  }
}

class AreaPickerScreen extends StatefulWidget {
  final String markerAsset;
  final Color mainColor;

  final String googlePlacesApiKey;
  final LatLng initialPosition;
  final List<double> distanceSteps;
  final List<double> zoomSteps;
  final int initialStepIndex;
  final List<LatLng> initialPolygon;
  final bool enableFreeDraw;

  final String placeAutoCompleteLanguage; //es || en
  final MapPickerStrings mapStrings;

  AreaPickerScreen(
      {Key key,
      this.markerAsset,
      this.mainColor = Colors.cyan,
      @required this.googlePlacesApiKey,
      @required this.initialPosition,
      this.distanceSteps = const [1000, 5000, 10000, 20000, 40000, 80000, 160000, 320000, 640000],
      this.zoomSteps = const [14, 12, 11, 10, 9, 8, 7, 6, 5],
      this.initialStepIndex = 1,
      this.initialPolygon = const [],
      this.enableFreeDraw = true,
      this.mapStrings,
      this.placeAutoCompleteLanguage})
      : super(key: key);

  @override
  _AreaPickerScreenState createState() => _AreaPickerScreenState(
      markerAsset: markerAsset,
      mainColor: mainColor,
      googlePlacesApiKey: googlePlacesApiKey,
      initialPosition: initialPosition,
      zoomSteps: zoomSteps,
      distanceSteps: distanceSteps,
      initialStepIndex: initialStepIndex,
      initialPolygon: initialPolygon,
      enableFreeDraw: enableFreeDraw,
      mapStrings: mapStrings,
      placeAutoCompleteLanguage: placeAutoCompleteLanguage);
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  final String markerAsset;
  final Color mainColor;

  final String googlePlacesApiKey;
  final LatLng initialPosition;
  final List<double> distanceSteps;
  final List<double> zoomSteps;
  final int initialStepIndex;
  final List<LatLng> initialPolygon;
  final bool enableFreeDraw;

  MapPickerStrings strings;
  String placeAutoCompleteLanguage;

  _AreaPickerScreenState(
      {@required this.markerAsset,
      @required this.mainColor,
      @required this.googlePlacesApiKey,
      @required this.initialPosition,
      @required this.initialStepIndex,
      @required this.distanceSteps,
      @required this.zoomSteps,
      @required this.initialPolygon,
      @required this.enableFreeDraw,
      @required mapStrings,
      @required placeAutoCompleteLanguage}) {
    centerCamera = LatLng(initialPosition.latitude, initialPosition.longitude);
    zoomCamera = zoomSteps[initialStepIndex];
    selectedLatLng = LatLng(initialPosition.latitude, initialPosition.longitude);
    radiusInMeters = distanceSteps[initialStepIndex];
    polygonPoints = initialPolygon;

    _places = GoogleMapsPlaces(apiKey: googlePlacesApiKey);

    this.strings = mapStrings ?? MapPickerStrings.english();
    this.placeAutoCompleteLanguage = 'en';
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  GoogleMapsPlaces _places;
  GoogleMapController googleMapController;

  //Camera
  LatLng centerCamera;
  double zoomCamera;

  //My Location
  LatLng myLocation;

  //CIRCLE
  LatLng selectedLatLng;
  double radiusInMeters;

  //POLYGON
  List<LatLng> polygonPoints = [];

  BitmapDescriptor iconSelectedLocation;

  bool drawing = false;

  ///BASIC
  _moveCamera(LatLng latLng, double zoom) async {
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: zoom)));
  }

  Future<$.LocationData> _getLocation() async {
    var location = new $.Location();
    $.LocationData locationData;
    try {
      locationData = await location.getLocation();
    } catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        print('Permission denied');
      }
      locationData = null;
    }

    if (locationData != null) myLocation = LatLng(locationData.latitude, locationData.longitude);

    return locationData;
  }

  @override
  void initState() {
    if (markerAsset != null) {
      BitmapDescriptor.fromAssetImage(ImageConfiguration(size: Size(30, 30)), markerAsset)
          .then((onValue) {
        setState(() {
          iconSelectedLocation = onValue;
        });
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ///MAP ELEMENTS
    _getMarkers() {
      Set<Marker> markers = {};

      if (drawing || polygonPoints.length > 0) return markers;

      markers.add(Marker(
        markerId: MarkerId("selected_position"),
        position: LatLng(selectedLatLng.latitude, selectedLatLng.longitude),
        icon: iconSelectedLocation,
      ));

      return markers;
    }

    _getCircles() {
      Set<Circle> circles = {};
      if (drawing || polygonPoints.length > 0) return circles;

      if (selectedLatLng != null && radiusInMeters != null) {
        circles.add(Circle(
          circleId: CircleId('circle_radius'),
          fillColor: mainColor.withOpacity(0.2),
          strokeWidth: 0,
          center: selectedLatLng,
          radius: radiusInMeters,
        ));
      }
      return circles;
    }

    _getPolygons() {
      Set<Polygon> polygons = {};
      if (polygonPoints != null && polygonPoints.length > 0) {
        polygons.add(Polygon(
          polygonId: PolygonId("polygon_area"),
          visible: true,
          points: polygonPoints,
          fillColor: mainColor.withOpacity(0.1),
          strokeWidth: 3,
        ));
      }
      return polygons;
    }

    ///MAP DRAW
    _removeCustomArea() {
      setState(() {
        polygonPoints = [];
      });
    }

    List<LatLng> _simplify(List<LatLng> coordinates) {
      List<Point> points =
          coordinates.map((latLng) => Point(latLng.latitude, latLng.longitude)).toList();
      List<Point> simplifiedPoints = PolyUtils.simplify(points, 100); //todo
      return simplifiedPoints.map((p) => LatLng(p.x, p.y)).toList();
    }

    _onDrawPolygon(List<DrawingPoints> points) async {
      final devicePixelRatio = Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1.0;

      Future<LatLng> _getLatLngFromScreenCoordinate(double x, double y) async {
        ScreenCoordinate screenCoordinate =
            ScreenCoordinate(x: (x * devicePixelRatio).round(), y: (y * devicePixelRatio).round());
        return await googleMapController.getLatLng(screenCoordinate);
      }

      List<LatLng> latLngPoints = [];
      for (var p in points) {
        var currentLatLng = await _getLatLngFromScreenCoordinate(p.points.dx, p.points.dy);
        latLngPoints.add(currentLatLng);
      }

      setState(() {
        polygonPoints = _simplify(latLngPoints);
        drawing = false;
      });
    }

    _initFreeDraw() {
      _removeCustomArea();
      setState(() {
        drawing = true;
      });
    }

    Widget _circleRadiusWidget() {
      return Container(
        height: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Slider(
              min: 0,
              max: (distanceSteps.length - 1).toDouble(),
              divisions: distanceSteps.length - 1,
              onChanged: (value) {
                setState(() {
                  radiusInMeters = distanceSteps[value.floor()];
                  _moveCamera(selectedLatLng, zoomSteps[value.floor()]);
                });
              },
              value: distanceSteps.indexOf(radiusInMeters).toDouble(),
              activeColor: mainColor,
              inactiveColor: Colors.black,
            ),
            Padding(
              padding: EdgeInsets.only(left: 32, bottom: 16),
              child: Text(strings.distanceInKmFromYou.replaceAll("\$", "${radiusInMeters / 1000}")),
            )
          ],
        ),
      );
    }

    Widget _polygonEditorWidget() {
      if (drawing) {
        return Container(
          height: 90,
          alignment: Alignment.center,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: mainColor, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListTile(
              leading: Icon(Icons.mode_edit),
              title: Text(strings.drawAreaOnMap),
            ),
          ),
        );
      }

      return Container(
        height: 90,
        alignment: Alignment.center,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: mainColor, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ListTile(
            title: Text(strings.customArea),
            trailing: ElevatedButton(
              child: Text(strings.delete),
              onPressed: () {
                _removeCustomArea();
              },
            ),
          ),
        ),
      );
    }

    _selectCenterCircle(LatLng latLng) {
      setState(() {
        selectedLatLng = latLng;
        _moveCamera(latLng, zoomCamera);
      });
    }

    _goToMyLocation() async {
      await _getLocation();
      if (myLocation != null) {
        _moveCamera(myLocation, zoomCamera);
        _selectCenterCircle(myLocation);
      }
    }

    ///WIDGETS
    Widget _mapButtons() {
      return Padding(
        padding: EdgeInsets.only(top: 40, left: 8, right: 8),
        child: Column(
          children: <Widget>[
            FloatingActionButton(
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
            if (enableFreeDraw)
              FloatingActionButton(
                heroTag: "FAB_DRAW",
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.mode_edit,
                  color: Colors.black,
                ),
                onPressed: () {
                  _initFreeDraw();
                },
              ),
          ],
        ),
      );
    }

    Future<bool> _onBackPressed() async {
      if (drawing) {
        drawing = false;
        _removeCustomArea();
        return false;
      }
      return true;
    }

    return WillPopScope(
      child: Scaffold(
        key: _scaffoldKey,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomRight,
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
                        _selectCenterCircle(latLng);
                      },
                      onCameraMove: (position) {
                        centerCamera = position.target;
                        zoomCamera = position.zoom;
                      },
                      circles: _getCircles(),
                      markers: _getMarkers(),
                      polygons: _getPolygons(),
                    ),
                    if (!drawing) _mapButtons(),
                    if (drawing)
                      Draw(
                        onDrawEnd: _onDrawPolygon,
                      ),
                  ],
                ),
              ),
              Container(
                child: Column(
                  children: <Widget>[
                    drawing || polygonPoints.length > 0
                        ? _polygonEditorWidget()
                        : _circleRadiusWidget(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 160,
                            padding: EdgeInsets.only(right: 16),
                            child: ElevatedButton(
                              onPressed: !drawing
                                  ? () {
                                      Navigator.pop(context);
                                    }
                                  : null,
                              child: Text(strings.cancel),
                            ),
                          ),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !drawing
                                  ? () {
                                      AreaPickerResult result = AreaPickerResult(
                                          selectedLatLng, radiusInMeters, polygonPoints);
                                      print(result);
                                      Navigator.pop(context, result);
                                    }
                                  : null,
                              child: Text(
                                strings.saveArea,
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
        ),
      ),
      onWillPop: _onBackPressed,
    );
  }
}

class Draw extends StatefulWidget {
  Draw({@required this.onDrawEnd});

  final Function(List<DrawingPoints>) onDrawEnd;

  @override
  _DrawState createState() => _DrawState(onDrawEnd: onDrawEnd);
}

class _DrawState extends State<Draw> {
  Color selectedColor = Colors.black;
  double strokeWidth = 3.0;
  List<DrawingPoints> points = List();
  double opacity = 1.0;
  StrokeCap strokeCap = (Platform.isAndroid) ? StrokeCap.butt : StrokeCap.round;

  Function(List<DrawingPoints>) onDrawEnd;

  _DrawState({@required this.onDrawEnd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          RenderBox renderBox = context.findRenderObject();
          points.add(DrawingPoints(
              points: renderBox.globalToLocal(details.globalPosition),
              paint: Paint()
                ..strokeCap = strokeCap
                ..isAntiAlias = true
                ..color = selectedColor.withOpacity(opacity)
                ..strokeWidth = strokeWidth));
        });
      },
      onPanStart: (details) {
        setState(() {
          RenderBox renderBox = context.findRenderObject();
          points.add(DrawingPoints(
              points: renderBox.globalToLocal(details.globalPosition),
              paint: Paint()
                ..strokeCap = strokeCap
                ..isAntiAlias = true
                ..color = selectedColor.withOpacity(opacity)
                ..strokeWidth = strokeWidth));
        });
      },
      onPanEnd: (details) {
        if (onDrawEnd != null) onDrawEnd(points);
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: DrawingPainter(
          pointsList: points,
        ),
      ),
    );
  }
}

///DRAW
class DrawingPainter extends CustomPainter {
  DrawingPainter({this.pointsList});

  List<DrawingPoints> pointsList;
  List<Offset> offsetPoints = List();

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < pointsList.length - 1; i++) {
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        canvas.drawLine(pointsList[i].points, pointsList[i + 1].points, pointsList[i].paint);
      } else if (pointsList[i] != null && pointsList[i + 1] == null) {
        offsetPoints.clear();
        offsetPoints.add(pointsList[i].points);
        offsetPoints.add(Offset(pointsList[i].points.dx + 0.1, pointsList[i].points.dy + 0.1));
        canvas.drawPoints(PointMode.points, offsetPoints, pointsList[i].paint);
      }
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) => true;
}

class DrawingPoints {
  Paint paint;
  Offset points;

  DrawingPoints({this.points, this.paint});
}

enum SelectedMode { StrokeWidth, Opacity, Color }
