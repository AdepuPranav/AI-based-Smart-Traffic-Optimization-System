import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'safe_routes_congestion_db.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'geojson_signals.dart';
import 'package:firebase_database/firebase_database.dart';
import 'traffic_eta.dart';
import '../Services/route_service.dart';
import '../Widgets/location_search.dart';
import '../Screens/location.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Required .env keys:
// ORS_API_KEY=<your_openrouteservice_api_key>
// FIREBASE_API_KEY_WEB=...
// FIREBASE_APP_ID_WEB=...
// FIREBASE_MESSAGING_SENDER_ID_WEB=...
// FIREBASE_PROJECT_ID=...
// FIREBASE_AUTH_DOMAIN_WEB=...
// FIREBASE_STORAGE_BUCKET=...
// FIREBASE_MEASUREMENT_ID_WEB=...
// FIREBASE_DATABASE_URL=...
// FIREBASE_API_KEY_ANDROID=...
// FIREBASE_APP_ID_ANDROID=...
// FIREBASE_MESSAGING_SENDER_ID_ANDROID=...
// FIREBASE_API_KEY_IOS=...
// FIREBASE_APP_ID_IOS=...
// FIREBASE_MESSAGING_SENDER_ID_IOS=...
// FIREBASE_IOS_BUNDLE_ID=...
// FIREBASE_API_KEY_MACOS=...
// FIREBASE_APP_ID_MACOS=...
// FIREBASE_MESSAGING_SENDER_ID_MACOS=...
// FIREBASE_API_KEY_WINDOWS=...
// FIREBASE_APP_ID_WINDOWS=...
// FIREBASE_MESSAGING_SENDER_ID_WINDOWS=...
// FIREBASE_AUTH_DOMAIN_WINDOWS=...
// FIREBASE_MEASUREMENT_ID_WINDOWS=...
// Add your actual values in a .env file at the project root.

class SafeRoutesScreen extends StatefulWidget {
  final LatLng startLocation;

  const SafeRoutesScreen({
    Key? key,
    required this.startLocation,
  }) : super(key: key);

  @override
  _SafeRoutesScreenState createState() => _SafeRoutesScreenState();
}

class _SafeRoutesScreenState extends State<SafeRoutesScreen> with WidgetsBindingObserver {
  int? lane1Eta;
  StreamSubscription<int?>? _etaSubscription;
  String _getSimulatedTrafficDensity(double congestion) {
    if (congestion > 0.7) return 'high';
    if (congestion > 0.4) return 'medium';
    return 'low';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _getTrafficDensityLabel(dynamic density) {
    if (density == null) return 'Unknown';
    if (density == 'high') return 'High';
    if (density == 'medium') return 'Medium';
    if (density == 'low') return 'Low';
    return _capitalize(density.toString());
  }

  bool _isLoading = false;
  LatLng? _destinationLocation;
  final Set<Polyline> _routes = {};
  final Set<Polyline> _intersectionRoutes = {}; // For showing intersection segments
  final Map<String, Marker> _markers = {};
  final Map<String, dynamic> _routeDetails = {};
  String? _bestRouteId;
  final MapController _mapController = MapController();
  
  // For tracking intersections with authorized routes
  List<RouteIntersection> _routeIntersections = [];
  bool _hasIntersectionWarning = false;

  // Cache for routes to avoid recalculation
  final Map<String, List<List<LatLng>>> _routeCache = {};

  // Route generation methods available
  final List<String> _routingEngines = ['osrm'];
  String _activeRoutingEngine = 'osrm';

  // Cache key generator
  String _getCacheKey(LatLng start, LatLng end, String engine) {
    return '${start.latitude},${start.longitude}_${end.latitude},${end.longitude}_$engine';
  }

  // For destination suggestions
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  Timer? _debounceTimer;

  // List of common destinations (would be replaced with actual API)
  final List<Map<String, dynamic>> _commonDestinations = [
    {'name': 'Golconda Fort', 'location': LatLng(17.3833, 78.4011)},
    {'name': 'Hitech City', 'location': LatLng(17.4400, 78.3800)},
    {'name': 'Hussain Sagar', 'location': LatLng(17.4239, 78.4738)},
    {'name': 'Charminar', 'location': LatLng(17.3616, 78.4747)},
    {'name': 'Rajiv Gandhi International Airport', 'location': LatLng(17.2403, 78.4294)},
    {'name': 'Tank Bund', 'location': LatLng(17.4256, 78.4737)},
    {'name': 'Secunderabad Railway Station', 'location': LatLng(17.4399, 78.4983)},
    {'name': 'Banjara Hills', 'location': LatLng(17.4156, 78.4347)},
    {'name': 'Jubilee Hills', 'location': LatLng(17.4343, 78.4075)},
    {'name': 'KPHB Colony', 'location': LatLng(17.4833, 78.3913)},
  ];

  @override
  void initState() {
    super.initState();
    // Load environment variables
    dotenv.isInitialized ? null : dotenv.load();
    // Listen to lane1 ETA changes in real time
    _etaSubscription = lane1EtaStream().listen((value) {
      setState(() {
        lane1Eta = value;
      });
    });

    // Add marker for starting location
    _markers['start'] = Marker(
      point: widget.startLocation,
      child: const Icon(
        Icons.my_location,
        color: Colors.blue,
        size: 24,
      ),
    );

    // Check if we have API keys and update routing engine accordingly
    _checkRoutingCapabilities();
    
    // Add listener for route service updates
    RouteService().addListener(_checkForRouteUpdates);
    
    // Register as an observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  // Check if real routing APIs can be used
  void _checkRoutingCapabilities() async {
    _activeRoutingEngine = 'osrm';
  }

  @override
  void dispose() {
    _etaSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app resumes, check for new route updates
    if (state == AppLifecycleState.resumed) {
      _checkForRouteUpdates();
    }
  }

  // which provides direct LatLng coordinates

  Future<void> _calculateRoutes() async {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a destination")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _routes.clear();
      _bestRouteId = null;
    });

    try {

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

      if (_bestRouteId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Best route found with ${(_routeDetails[_bestRouteId]['congestion'] * 100).toInt()}% congestion"),
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

  void _fitMapToBounds() {
    if (_markers.length < 2) return;
    final points = <LatLng>[];
    points.addAll(_markers.values.map((marker) => marker.point));
    for (final routeId in _routeDetails.keys) {
      final path = _routeDetails[routeId]['path'] as List<LatLng>;
      if (path.length > 10) {
        final step = (path.length / 5).floor();
        for (int i = 0; i < path.length; i += step) {
          points.add(path[i]);
        }
      } else {
        points.addAll(path);
      }
    }
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }
    final latPadding = (maxLat - minLat) * 0.2;
    final lngPadding = (maxLng - minLng) * 0.2;
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final latZoom = math.log(360 / (maxLat - minLat)) / math.log(2);
    final lngZoom = math.log(360 / (maxLng - minLng)) / math.log(2);
    final zoom = [latZoom, lngZoom].reduce((a, b) => a < b ? a : b);
    _mapController.move(LatLng(centerLat, centerLng), zoom);
  }

  Future<void> _generateRoutes() async {
    // Fetch lane 1 ETA data from Firebase
    final List<SignalLaneEta> etaDb = await fetchLane1EtaData();
    print('DEBUG: Fetched ${etaDb.length} ETA points from Firebase');
    for (var eta in etaDb) {
      print('DEBUG: ETA point at (${eta.lat}, ${eta.lng}) with ETA: ${eta.estimatedEtaSec} seconds');
    }
    if (_destinationLocation == null) return;

    final start = widget.startLocation;
    final end = _destinationLocation!;

    // Get routes from cache or API
    final cacheKey = _getCacheKey(start, end, _activeRoutingEngine);
    List<List<LatLng>> routePaths;

    if (_routeCache.containsKey(cacheKey)) {
      routePaths = _routeCache[cacheKey]!;
    } else {
      // Get routes based on active routing engine
      if (_activeRoutingEngine == 'osrm') {
        routePaths = await _getOsrmRoutes(start, end);
      } else {
        // Fallback to direct route if no routing engine available
        routePaths = [[start, end]];
      }

      // Cache the routes
      _routeCache[cacheKey] = routePaths;
    }

    // For each route, estimate congestion using closest congestion_length from DB
    for (int i = 0; i < routePaths.length; i++) {
      final String routeId = "route${i + 1}";
      final List<LatLng> path = routePaths[i];
      // Find the ETA point closest to the midpoint of the route
      final LatLng mid = path[(path.length / 2).floor()];
      print('DEBUG: Route $routeId midpoint: (${mid.latitude}, ${mid.longitude})');
      final SignalLaneEta? etaPoint = findClosestLane1Eta(mid, etaDb);
      print('DEBUG: Fetching ETA points for midpoint: $mid');
      if (etaPoint == null) {
        print('DEBUG: ETA for midpoint $mid is null, setting to N/A');
      } else {
        print('DEBUG: ETA for midpoint $mid is $etaPoint');
      }
      if (etaPoint != null) {
        print('DEBUG: Found ETA point for route $routeId with ETA: ${etaPoint.estimatedEtaSec} seconds');
      } else {
        print('DEBUG: No ETA point found for route $routeId');
      }
      int etaMin = 0;
      if (etaPoint != null && etaPoint.estimatedEtaSec > 0) {
        etaMin = (etaPoint.estimatedEtaSec / 60).ceil();
        print('DEBUG: Setting etaMin to $etaMin minutes for route $routeId');
      }
      // Simulate congestion (optional: you can still use congestion for color, etc.)
      double congestion = 0.2 + math.Random().nextDouble() * 0.4;
      final double distance = _calculateRouteDistance(path);
      final int duration = (distance / (30 * (1.0 - congestion))).round();
      final int incidents = math.Random().nextInt(3);
      _routeDetails[routeId] = {
        'congestion': congestion,
        'incidents': incidents,
        'distance': distance,
        'duration': duration,
        'color': _getRouteColor(congestion),
        'path': path, // Store the path for intersection checking
        'traffic_density': _getSimulatedTrafficDensity(congestion),
        'lane1_eta_min': etaMin,
      };
      print('DEBUG: Route details for $routeId: ${_routeDetails[routeId]}');
      _routes.add(
        Polyline(
          points: path,
          strokeWidth: 5.0,
          color: _getRouteColor(congestion),
        ),
      );
      if (_bestRouteId == null ||
          congestion < _routeDetails[_bestRouteId]['congestion']) {
        _bestRouteId = routeId;
      }
    }
    _checkForIntersections();
  }

  Future<List<List<LatLng>>> _getOsrmRoutes(LatLng start, LatLng end) async {
    final url = 'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&alternatives=true&geometries=polyline';

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
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
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

  List<Map<String, dynamic>> _simulateCongestionData(List<List<LatLng>> routes) {
    final now = DateTime.now();
    final hour = now.hour;
    final List<double> congestionFactors = [0.3, 0.2, 0.2, 0.2, 0.3, 0.4, 0.5, 0.7, 0.9, 0.8, 0.7, 0.6, 0.7, 0.8, 0.7, 0.6, 0.7, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3];
    final timeMultiplier = congestionFactors[hour];
    List<Map<String, dynamic>> data = [];
    for (var route in routes) {
      final distance = _calculateRouteDistance(route);
      final congestion = (math.Random().nextDouble() * 0.5 + timeMultiplier).clamp(0.1, 0.95);
      final duration = (distance / (30 * (1.0 - congestion))).round();
      final incidents = math.Random().nextInt(3);
      data.add({
        'congestion': congestion,
        'incidents': incidents,
        'distance': distance,
        'duration': duration,
      });
    }
    return data;
  }

  double _calculateRouteDistance(List<LatLng> route) {
    double distance = 0;
    for (int i = 0; i < route.length - 1; i++) {
      distance += _haversineDistance(route[i], route[i + 1]);
    }
    return distance;
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // km
    final double dLat = (end.latitude - start.latitude) * math.pi / 180;
    final double dLng = (end.longitude - start.longitude) * math.pi / 180;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(start.latitude * math.pi / 180) *
            math.cos(end.latitude * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Color _getRouteColor(double congestionScore) {
    if (congestionScore > 0.7) {
      return Colors.red;
    } else if (congestionScore > 0.4) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  void _selectRoute(String routeId) {
    setState(() {
      _bestRouteId = routeId;
      // Check for intersections with the newly selected route
      _checkForIntersections();
    });
  }
  
  // Check for updates from the RouteService
  void _checkForRouteUpdates() {
    if (_bestRouteId != null && _routeDetails.isNotEmpty) {
      // Re-check for intersections if we have active routes
      _checkForIntersections();
    }
  }
  
  // Check for intersections with authorized routes
  void _checkForIntersections() {
    if (_bestRouteId == null || !_routeDetails.containsKey(_bestRouteId)) return;
    
    // Clear previous intersection routes
    _intersectionRoutes.clear();
    _routeIntersections.clear();
    _hasIntersectionWarning = false;
    
    // Get the current route path
    final currentRoutePath = _routeDetails[_bestRouteId]['path'] as List<LatLng>;
    
    // Find intersections with authorized routes
    _routeIntersections = RouteService().findIntersections(currentRoutePath);
    
    if (_routeIntersections.isNotEmpty) {
      _hasIntersectionWarning = true;
      
      // Create polylines for intersections
      for (final intersection in _routeIntersections) {
        _intersectionRoutes.add(
          Polyline(
            points: intersection.userRouteSegment,
            strokeWidth: 6.0,
            color: Colors.red.shade700,
          ),
        );
      }
      
      // Show warning to user
      _showIntersectionWarning();
    }
    
    setState(() {});
  }
  
  // Show warning about route intersections
  void _showIntersectionWarning() {
    if (!_hasIntersectionWarning || _routeIntersections.isEmpty) return;
    
    // Build warning message
    final routeNames = _routeIntersections.map((i) => 
      "${i.authorizedRoute.startLocationName} to ${i.authorizedRoute.endLocationName}"
    ).toSet().join(', ');
    
    // Show warning dialog
    Future.delayed(Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Route Congestion Warning'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your route intersects with ${_routeIntersections.length} authorized personnel route(s):\n\n$routeNames\n\nThese segments may experience increased congestion.',
              ),
              SizedBox(height: 16),
              Text(
                'Consider selecting an alternative route to avoid delays.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'Estimated ETA: ${lane1Eta != null ? '$lane1Eta seconds' : 'N/A'}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Find alternative route with fewer intersections
                _suggestAlternativeRoute();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('Find Alternative Route'),
            ),
          ],
        ),
      );
    });
  }
  
  // Suggest an alternative route with fewer intersections
  void _suggestAlternativeRoute() {
    if (_routeDetails.length <= 1) return; // No alternatives available
    
    String? bestAlternative;
    int fewestIntersections = 999;
    
    // Check each route for intersections
    for (final entry in _routeDetails.entries) {
      final routeId = entry.key;
      if (routeId == _bestRouteId) continue; // Skip current route
      
      final routePath = entry.value['path'] as List<LatLng>;
      final intersections = RouteService().findIntersections(routePath);
      
      // If this route has fewer intersections, select it
      if (intersections.length < fewestIntersections) {
        fewestIntersections = intersections.length;
        bestAlternative = routeId;
      }
    }
    
    if (bestAlternative != null) {
      _selectRoute(bestAlternative);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fewestIntersections > 0
                ? 'Alternative route selected with ${fewestIntersections} intersection(s)'
                : 'Alternative route selected with no intersections',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Routes'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: widget.startLocation,
              zoom: 13.0,
              interactiveFlags: InteractiveFlag.all,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // Regular routes
              PolylineLayer(polylines: _routes.toList()),
              // Intersection routes (red)
              PolylineLayer(polylines: _intersectionRoutes.toList()),
              MarkerLayer(markers: _markers.values.toList()),
              // Traffic signal markers from GeoJSON
              FutureBuilder<List<LatLng>>(
                future: loadGeoJsonSignals(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasError) {
                    return const SizedBox.shrink();
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  if (_bestRouteId == null || !_routeDetails.containsKey(_bestRouteId)) {
                    return const SizedBox.shrink();
                  }
                  final allSignals = snapshot.data!;
                  final List<LatLng> path = List<LatLng>.from(_routeDetails[_bestRouteId]['path'] ?? []);
                  final filteredSignals = filterSignalsOnRoute(allSignals, path, thresholdMeters: 30);
                  if (filteredSignals.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return MarkerLayer(
                    markers: filteredSignals.map((point) => Marker(
                      width: 60,
                      height: 60,
                      point: point,
                      child: Icon(Icons.traffic, color: Colors.red, size: 48),
                    )).toList(),
                  );
                },
              ),
            ],
          ),
          
          Positioned(
            top: 24,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LocationSearchWidget(
                      hintText: 'Enter your destination',
                      autofocus: false,
                      nearLocation: widget.startLocation, // Use starting location as reference
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
                          
                          // Clear previous routes
                          _routes.clear();
                          _routeDetails.clear();
                          _bestRouteId = null;
                          
                          // Calculate routes
                          _calculateRoutes();
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_routeDetails.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Card(
                margin: EdgeInsets.zero,
                elevation: 8,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _routeDetails.entries.map((entry) {
                          final routeId = entry.key;
                          final details = entry.value;
                          final bool isBest = routeId == _bestRouteId;
                          return GestureDetector(
                            onTap: () => _selectRoute(routeId),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isBest ? Colors.green.withOpacity(0.13) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isBest ? Colors.green : Colors.grey.shade300,
                                  width: isBest ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isBest ? "Best" : routeId.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isBest ? Colors.green : Colors.black87,
                                        ),
                                      ),
                                      if (_hasIntersectionWarning && isBest)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4.0),
                                          child: Icon(Icons.warning_amber_rounded, 
                                            color: Colors.red, 
                                            size: 16,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.traffic, color: details['color'], size: 18),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${(details['congestion'] * 100).toInt()}%",
                                        style: TextStyle(
                                          color: details['color'],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.info_outline, color: Colors.blueGrey, size: 16),
                                      const SizedBox(width: 2),
                                      Text(
                                        details['lane1_eta_min'] != null && details['lane1_eta_min'] > 0
                                            ? 'ETA (Lane 1): ${details['lane1_eta_min']} min'
                                            : 'ETA (Lane 1): N/A',
                                        style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions, size: 16, color: Colors.blueGrey),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${details['distance'].toStringAsFixed(2)} km",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer, size: 16, color: Colors.deepPurple),
                                      const SizedBox(width: 2),
                                      Text(
                                        (() {
                                          // Calculate time using distance and 30 kmph
                                          final double distance = details['distance'] ?? 0.0;
                                          if (distance == 0.0) return 'N/A';
                                          final double avgSpeed = 30.0; // kmph
                                          final double timeHr = distance / avgSpeed;
                                          final int timeMin = (timeHr * 60).round();
                                          return '$timeMin min';
                                        })(),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.warning, size: 16, color: Colors.redAccent),
                                      const SizedBox(width: 2),
                                      Text(
                                        "${details['incidents']}",
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
                    ],
                  ),
                ),
              ),
            ),
          
        ],
      ),
    );
  }
}