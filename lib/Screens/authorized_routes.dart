// NOTE: All API keys and credentials must be loaded from .env using dotenv. Do not hardcode any sensitive information in this file.
// No API key required for public OpenStreetMap tiles. If you use a paid or private tile provider, load the key from .env using dotenv.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:convert';
import '../Services/route_service.dart';
import 'safe_routes.dart';
import '../Widgets/location_search.dart';
import '../Screens/location.dart';

// Fetch all traffic signals in Hyderabad from OpenStreetMap Overpass API
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

Future<List<LatLng>> loadGeoJsonSignals() async {
  final geojsonStr = await rootBundle.loadString('assets/export.geojson');
  final geojson = json.decode(geojsonStr);
  final features = geojson['features'] as List;
  // Extract coordinates from Point features
  final points = features.where((f) => f['geometry']['type'] == 'Point').map<LatLng>((f) {
    final coords = f['geometry']['coordinates'];
    return LatLng(coords[1], coords[0]); // [lon, lat]
  }).toList();
  return points;
}


// Model for signal timing
class SignalTiming {
  final String id;
  final int lane1;
  final int? lane2, lane3, lane4;
  final double lat, lng;

  SignalTiming({
    required this.id,
    required this.lane1,
    this.lane2,
    this.lane3,
    this.lane4,
    required this.lat,
    required this.lng,
  });

  factory SignalTiming.fromMap(String id, Map<dynamic, dynamic> data) {
    return SignalTiming(
      id: id,
      lane1: data['lane1'] ?? 0,
      lane2: data['lane2'],
      lane3: data['lane3'],
      lane4: data['lane4'],
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
    );
  }
}

Future<List<SignalTiming>> fetchSignalTimings() async {
  final ref = FirebaseDatabase.instance.ref('signals');
  final snapshot = await ref.get();
  if (snapshot.exists) {
    final signals = <SignalTiming>[];
    final data = snapshot.value as Map<dynamic, dynamic>;
    data.forEach((id, value) {
      signals.add(SignalTiming.fromMap(id, value));
    });
    return signals;
  } else {
    return [];
  }
}

class AuthorizedRoutesScreen extends StatefulWidget {
  final LatLng startLocation;

  const AuthorizedRoutesScreen({
    Key? key,
    required this.startLocation,
  }) : super(key: key);

  @override
  _AuthorizedRoutesScreenState createState() => _AuthorizedRoutesScreenState();
}

class _AuthorizedRoutesScreenState extends State<AuthorizedRoutesScreen> {
  bool _isLoading = false;
  LatLng? _startLocation;
  LatLng? _destinationLocation;
  final Set<Polyline> _routes = {};
  final Set<Polyline> _userRoutes = {}; // User routes for comparison
  final Set<Polyline> _intersectionRoutes = {}; // Intersection segments
  final Map<String, Marker> _markers = {};
  final Map<String, dynamic> _routeDetails = {};
  String? _bestRouteId;
  final MapController _mapController = MapController();

  // Cache for routes to avoid recalculation
  final Map<String, List<List<LatLng>>> _routeCache = {};

  // Route generation methods available
  final String _activeRoutingEngine = 'osrm';

  // List of common locations (would be replaced with actual API)
  final List<Map<String, dynamic>> _commonLocations = [
    {'name': 'Golconda Fort', 'location': LatLng(17.3833, 78.4011)},
    {'name': 'Hitech City', 'location': LatLng(17.4400, 78.3800)},
    {'name': 'Hussain Sagar', 'location': LatLng(17.4239, 78.4738)},
    {'name': 'Charminar', 'location': LatLng(17.3616, 78.4747)},
    {
      'name': 'Rajiv Gandhi International Airport',
      'location': LatLng(17.2403, 78.4294)
    },
    {'name': 'Tank Bund', 'location': LatLng(17.4256, 78.4737)},
    {
      'name': 'Secunderabad Railway Station',
      'location': LatLng(17.4399, 78.4983)
    },
    {'name': 'Banjara Hills', 'location': LatLng(17.4156, 78.4347)},
    {'name': 'Jubilee Hills', 'location': LatLng(17.4343, 78.4075)},
    {'name': 'KPHB Colony', 'location': LatLng(17.4833, 78.3913)},
  ];

  // Simulated user routes for demonstration
  final List<List<LatLng>> _simulatedUserRoutes = [
    // Route 1: Hitech City to Charminar
    [
      LatLng(17.4400, 78.3800), // Hitech City
      LatLng(17.4300, 78.4000),
      LatLng(17.4200, 78.4200),
      LatLng(17.4100, 78.4400),
      LatLng(17.3900, 78.4600),
      LatLng(17.3616, 78.4747), // Charminar
    ],
    // Route 2: Banjara Hills to Secunderabad
    [
      LatLng(17.4156, 78.4347), // Banjara Hills
      LatLng(17.4200, 78.4400),
      LatLng(17.4250, 78.4500),
      LatLng(17.4300, 78.4700),
      LatLng(17.4399, 78.4983), // Secunderabad
    ],
  ];

  @override
  void initState() {
    super.initState();
    _startLocation = widget.startLocation;

    // Add marker for starting location
    _markers['start'] = Marker(
      point: widget.startLocation,
      child: const Icon(
        Icons.my_location,
        color: Colors.blue,
        size: 24,
      ),
    );

    // Load simulated user routes
    _loadUserRoutes();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Load simulated user routes for demonstration
  void _loadUserRoutes() {
    for (int i = 0; i < _simulatedUserRoutes.length; i++) {
      final routeId = 'user_route_${i + 1}';
      _userRoutes.add(
        Polyline(
          points: _simulatedUserRoutes[i],
          strokeWidth: 4.0,
          color: Colors.blue.withOpacity(0.7),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _calculateRoutes() async {
    if (_startLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select both start and destination locations")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _routes.clear();
      _intersectionRoutes.clear();
      _bestRouteId = null;
    });

    try {
      // We already have _startLocation and _destinationLocation from the LocationSearchWidget
      // No need to geocode them again

      if (_startLocation == null || _destinationLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not find one of the locations")),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Update markers
      _markers['start'] = Marker(
        point: _startLocation!,
        child: const Icon(
          Icons.my_location,
          color: Colors.blue,
          size: 24,
        ),
      );

      _markers['destination'] = Marker(
        point: _destinationLocation!,
        child: const Icon(
          Icons.place,
          color: Colors.red,
          size: 24,
        ),
      );

      await _generateRoutes();
      _fitMapToBounds();

      // Find intersections with user routes
      _findIntersections();

      if (_bestRouteId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Route calculated with ${(_routeDetails[_bestRouteId]['congestion'] *
                    100).toInt()}% congestion"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error calculating routes: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<LatLng?> _geocodeLocation(String locationText) async {
    // For this demo, we'll use our predefined locations instead of real geocoding
    final match = _commonLocations.firstWhere(
          (loc) =>
      (loc['name'] as String).toLowerCase() == locationText.toLowerCase(),
      orElse: () => {'location': null},
    );

    return match['location'] as LatLng?;
  }

  void _fitMapToBounds() {
    if (_startLocation == null || _destinationLocation == null) return;

    // Calculate bounds including all routes and markers
    LatLng southwest = _startLocation!;
    LatLng northeast = _destinationLocation!;
    
    // Initialize with start and destination
    double minLat = math.min(southwest.latitude, northeast.latitude);
    double maxLat = math.max(southwest.latitude, northeast.latitude);
    double minLng = math.min(southwest.longitude, northeast.longitude);
    double maxLng = math.max(southwest.longitude, northeast.longitude);
    
    // Include all route points in bounds
    for (final route in _routes) {
      for (final point in route.points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
    }
    
    // Include user routes in bounds
    for (final route in _userRoutes) {
      for (final point in route.points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
    }
    
    // Create bounds from min/max values
    final bounds = LatLngBounds(
      LatLng(minLat, minLng), // southwest corner
      LatLng(maxLat, maxLng)  // northeast corner
    );

    // Add some padding
    final centerZoom = _mapController.centerZoomFitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(50.0)),
    );

    _mapController.move(centerZoom.center, centerZoom.zoom);
  }

  Future<void> _generateRoutes() async {
    if (_startLocation == null || _destinationLocation == null) return;

    final start = _startLocation!;
    final end = _destinationLocation!;

    // Get routes from OSRM
    final List<List<LatLng>> routePaths = await _getOsrmRoutes(start, end);

    // Get congestion data for routes
    final congestionData = _simulateCongestionData(routePaths);

    // Generate route polylines and details
    for (int i = 0; i < routePaths.length; i++) {
      final String routeId = "route${i + 1}";
      final double congestion = congestionData[i]['congestion'];
      final int incidents = congestionData[i]['incidents'];
      final double distance = congestionData[i]['distance'];
      final int duration = congestionData[i]['duration'];

      // Store route details
      _routeDetails[routeId] = {
        'congestion': congestion,
        'incidents': incidents,
        'distance': distance,
        'duration': duration,
        'color': _getRouteColor(congestion),
      };

      // Create polyline for route
      _routes.add(
        Polyline(
          points: routePaths[i],
          strokeWidth: 5.0,
          color: _getRouteColor(congestion),
        ),
      );

      // Determine best route (lowest congestion)
      if (_bestRouteId == null ||
          congestionData[i]['congestion'] <
              _routeDetails[_bestRouteId]['congestion']) {
        _bestRouteId = routeId;
      }
    }
  }

  Future<List<List<LatLng>>> _getOsrmRoutes(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/${start
        .longitude},${start.latitude};${end.longitude},${end
        .latitude}?overview=full&alternatives=true&geometries=polyline';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List routes = data['routes'];
        List<List<LatLng>> result = [];
        for (var route in routes) {
          result.add(_decodePolyline(route['geometry']));
        }
        return result;
      } else {
        throw Exception('Failed to fetch route from OSRM');
      }
    } catch (e) {
      print('Error fetching OSRM route: $e');
      // Fallback to direct route if OSRM fails
      return [[start, end]];
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0,
        len = encoded.length;
    int lat = 0,
        lng = 0;

    while (index < len) {
      int b,
          shift = 0,
          result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  List<Map<String, dynamic>> _simulateCongestionData(
      List<List<LatLng>> routes) {
    final List<Map<String, dynamic>> congestionData = [];
    final random = math.Random();

    for (final route in routes) {
      final distance = _calculateRouteDistance(route);
      final baseSpeed = 40.0; // km/h
      final duration = ((distance / baseSpeed) * 60).round(); // minutes

      // Random congestion factor between 0.2 and 0.8
      final congestionFactor = 0.2 + (random.nextDouble() * 0.6);

      // Random number of incidents between 0 and 3
      final incidents = random.nextInt(4);

      congestionData.add({
        'congestion': congestionFactor,
        'incidents': incidents,
        'distance': distance,
        'duration': duration,
      });
    }

    return congestionData;
  }

  double _calculateRouteDistance(List<LatLng> route) {
    double totalDistance = 0.0;
    for (int i = 0; i < route.length - 1; i++) {
      totalDistance += _haversineDistance(route[i], route[i + 1]);
    }
    return totalDistance;
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const int earthRadius = 6371; // km
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double lon1 = start.longitude * math.pi / 180;
    final double lon2 = end.longitude * math.pi / 180;
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Color _getRouteColor(double congestionScore) {
    if (congestionScore < 0.3) {
      return Colors.green;
    } else if (congestionScore < 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  void _findIntersections() {
    if (_routes.isEmpty || _userRoutes.isEmpty || _bestRouteId == null) return;

    // Get the best route points
    final bestRouteIndex = int.parse(_bestRouteId!.replaceAll('route', '')) - 1;
    if (bestRouteIndex < 0 || bestRouteIndex >= _routes.length) return;

    final bestRoute = _routes
        .elementAt(bestRouteIndex)
        .points;

    // Clear previous intersection routes
    _intersectionRoutes.clear();

    // Check each user route for intersections with our best route
    for (final userRoute in _userRoutes) {
      final List<LatLng> intersectionPoints = [];
      final List<LatLng> userPoints = userRoute.points;

      // Find segments that are close to each other (simplified approach)
      for (int i = 0; i < bestRoute.length - 1; i++) {
        final LatLng start = bestRoute[i];
        final LatLng end = bestRoute[i + 1];

        for (int j = 0; j < userPoints.length - 1; j++) {
          final LatLng userStart = userPoints[j];
          final LatLng userEnd = userPoints[j + 1];

          // Check if segments are close (within 100 meters)
          if (_areSegmentsClose(start, end, userStart, userEnd, 0.1)) {
            // Add this segment to intersections
            if (intersectionPoints.isEmpty ||
                intersectionPoints.last != start) {
              intersectionPoints.add(start);
            }
            intersectionPoints.add(end);
          }
        }
      }

      // If we found intersection points, create a red polyline for them
      if (intersectionPoints.length >= 2) {
        _intersectionRoutes.add(
          Polyline(
            points: intersectionPoints,
            strokeWidth: 6.0,
            color: Colors.red.shade700,
          ),
        );
      }
    }

    setState(() {});
  }

  bool _areSegmentsClose(LatLng a1, LatLng a2, LatLng b1, LatLng b2,
      double threshold) {
    // Simple check: if any endpoint of segment A is close to any endpoint of segment B
    if (_haversineDistance(a1, b1) < threshold ||
        _haversineDistance(a1, b2) < threshold ||
        _haversineDistance(a2, b1) < threshold ||
        _haversineDistance(a2, b2) < threshold) {
      return true;
    }

    // Check if midpoints are close
    final LatLng midA = LatLng(
        (a1.latitude + a2.latitude) / 2,
        (a1.longitude + a2.longitude) / 2
    );

    final LatLng midB = LatLng(
        (b1.latitude + b2.latitude) / 2,
        (b1.longitude + b2.longitude) / 2
    );

    return _haversineDistance(midA, midB) < threshold;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorized Personnel Routes'),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(17.4, 78.45), // Center on Hyderabad
              zoom: 13.0,
              interactiveFlags: InteractiveFlag.all,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // User routes (blue)
              PolylineLayer(polylines: _userRoutes.toList()),
              // Our routes
              PolylineLayer(polylines: _routes.toList()),
              // Intersection routes (red)
              PolylineLayer(polylines: _intersectionRoutes.toList()),
              // Next traffic signal marker with ETA
              FutureBuilder<List<LatLng>>(
                future: loadGeoJsonSignals(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error fetching signals: \\${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No traffic signals found'));
                  }
                  final points = snapshot.data!;
                  print('Loaded \\${points.length} traffic signals from GeoJSON');
                  return MarkerLayer(
                    markers: points.map((point) => Marker(
                      width: 60,
                      height: 60,
                      point: point,
                      child: Icon(Icons.traffic, color: Colors.red, size: 48),
                    )).toList(),
                  );
                },
              ),
              // Markers
              MarkerLayer(markers: _markers.values.toList()),
            ],
          ),

          // Input panel
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start location search
                  LocationSearchWidget(
                    hintText: 'Enter starting location',
                    autofocus: false,
                    nearLocation: widget.startLocation, // Use initial location as reference
                    onLocationSelected: (LocationResult result) {
                      setState(() {
                        _startLocation = result.location;
                        
                        // Update marker
                        _markers['start'] = Marker(
                          point: result.location,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 24,
                          ),
                        );
                        
                        // If we have both locations, fit map to show both
                        if (_destinationLocation != null) {
                          _fitMapToBounds();
                        } else {
                          // Otherwise just center on this location
                          _mapController.move(result.location, 13.0);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 16.0),

                  // Destination location search
                  LocationSearchWidget(
                    hintText: 'Enter destination',
                    autofocus: false,
                    nearLocation: _startLocation, // Use selected start location as reference
                    onLocationSelected: (LocationResult result) {
                      setState(() {
                        _destinationLocation = result.location;
                        
                        // Update marker
                        _markers['destination'] = Marker(
                          point: result.location,
                          child: const Icon(
                            Icons.place,
                            color: Colors.red,
                            size: 24,
                          ),
                        );
                        
                        // If we have both locations, fit map to show both
                        if (_startLocation != null) {
                          _fitMapToBounds();
                        } else {
                          // Otherwise just center on this location
                          _mapController.move(result.location, 13.0);
                        }
                      });
                    },
                  ),

                  const SizedBox(height: 16.0),

                  // Calculate button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _calculateRoutes,
                      icon: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                        ),
                      )
                          : const Icon(Icons.directions),
                      label: Text(
                          _isLoading ? 'Calculating...' : 'Calculate Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  
                  // Share route button (only visible when routes are available)
                  if (_routes.isNotEmpty && _bestRouteId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _shareRouteWithService,
                          icon: const Icon(Icons.share),
                          label: const Text('Share Route with System'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                  // Switch to Guest Mode button
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SafeRoutesScreen(
                                startLocation: widget.startLocation,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Switch to Guest Mode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Route details panel (when routes are available)
          if (_routes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Route Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_intersectionRoutes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Warning: Route intersects with ${_intersectionRoutes
                              .length} user route(s)',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        children: _routeDetails.entries.map((entry) {
                          final routeId = entry.key;
                          final details = entry.value;
                          final isBest = routeId == _bestRouteId;

                          return GestureDetector(
                            onTap: () => _selectRoute(routeId),
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                color: isBest
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: isBest ? Colors.green : Colors.grey
                                      .shade300,
                                  width: isBest ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isBest ? "Best" : routeId.toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isBest ? Colors.green : Colors
                                          .black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.traffic,
                                          color: details['color'], size: 18),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${(details['congestion'] * 100)
                                            .toInt()}%",
                                        style: TextStyle(
                                          color: details['color'],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions, size: 16,
                                          color: Colors.blueGrey),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${details['distance'].toStringAsFixed(
                                            2)} km",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectRoute(String routeId) {
    setState(() {
      _bestRouteId = routeId;
      _findIntersections();
    });
  }
  
  // Share the selected route with the RouteService
  void _shareRouteWithService() {
    if (_bestRouteId == null || _startLocation == null || _destinationLocation == null) return;
    
    // Get the best route index
    final bestRouteIndex = int.parse(_bestRouteId!.replaceAll('route', '')) - 1;
    if (bestRouteIndex < 0 || bestRouteIndex >= _routes.length) return;
    
    // Get the best route points
    final bestRoute = _routes.elementAt(bestRouteIndex).points;
    final congestion = _routeDetails[_bestRouteId]['congestion'] as double;
    
    // Create a unique ID for this route
    final routeId = 'auth_route_${DateTime.now().millisecondsSinceEpoch}';
    
    // Use generic location names since we don't have text controllers anymore
    final startName = "Starting Location";
    final endName = "Destination";
    
    // Create an AuthorizedRoute object
    final authorizedRoute = AuthorizedRoute(
      id: routeId,
      points: bestRoute,
      congestion: congestion,
      startLocationName: startName,
      endLocationName: endName,
    );
    
    // Add it to the RouteService
    RouteService().addAuthorizedRoute(authorizedRoute);
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Route shared with system. Users will be notified of potential congestion.'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}