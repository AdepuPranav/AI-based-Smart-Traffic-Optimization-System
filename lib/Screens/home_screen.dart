import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'safe_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _showTraffic = true;
  bool _locationPermissionGranted = false;

  // Default to Hyderabad as fallback
  LatLng _currentLocation = const LatLng(17.3616, 78.4747);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationPermissionGranted) {
      // Re-check permissions when app is resumed
      _checkPermissionOnResume();
    }
  }

  Future<void> _checkPermissionOnResume() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // User granted permission in settings
      _requestLocationPermission();
    }
  }

  // Request actual location permission using Geolocator
  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, show dialog to open settings
      setState(() {
        _isLoading = false;
        _locationPermissionGranted = false;
      });

      // Show dialog to prompt user to enable location services
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Disabled'),
              content: const Text('Please enable location services to use this feature.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Load map with default location since user declined
                    _loadMapData();
                  },
                ),
                TextButton(
                  child: const Text('OPEN SETTINGS'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openLocationSettings();
                    // We'll need to handle reloading when they return from settings
                  },
                ),
              ],
            );
          },
        );
      }
      return;
    }

    // Check for permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // This will show the native Android permission popup
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle accordingly
        setState(() {
          _isLoading = false;
          _locationPermissionGranted = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to show your location on the map.'),
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Load map with default location
        _loadMapData();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle accordingly
      setState(() {
        _isLoading = false;
        _locationPermissionGranted = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                  'Location permission is permanently denied. Please enable it in app settings.'),
              actions: <Widget>[
                TextButton(
                  child: const Text('CANCEL'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Load map with default location since user declined
                    _loadMapData();
                  },
                ),
                TextButton(
                  child: const Text('OPEN SETTINGS'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Geolocator.openAppSettings();
                  },
                ),
              ],
            );
          },
        );
      }

      // Load map with default location
      _loadMapData();
      return;
    }

    // Permissions are granted, get location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _locationPermissionGranted = true;
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      _loadMapData();
    } catch (e) {
      // Error getting location, use default
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e. Using default location.'),
          ),
        );
      }

      _loadMapData();
    }
  }

  // Loading map data
  Future<void> _loadMapData() async {
    setState(() {
      // Add marker for current location
      _markers.add(
        Marker(
          point: _currentLocation,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
            ),
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      );

      // For now we'll show sample routes - these will be replaced by dynamic OSRM routes
      if (_showTraffic) {
        _generateSampleRoutes();
      }

      _isLoading = false;
    });
  }

  // Generate sample routes around user's location
  // This will be replaced with actual OSRM routes later
  void _generateSampleRoutes() {
    // Create points around the current location for sample routes
    final List<List<LatLng>> sampleRoutes = [
      [
        _currentLocation,
        LatLng(_currentLocation.latitude + 0.01, _currentLocation.longitude + 0.01),
        LatLng(_currentLocation.latitude + 0.02, _currentLocation.longitude + 0.015),
      ],
      [
        _currentLocation,
        LatLng(_currentLocation.latitude - 0.005, _currentLocation.longitude + 0.02),
        LatLng(_currentLocation.latitude - 0.01, _currentLocation.longitude + 0.03),
      ],
      [
        _currentLocation,
        LatLng(_currentLocation.latitude + 0.01, _currentLocation.longitude - 0.01),
        LatLng(_currentLocation.latitude + 0.02, _currentLocation.longitude - 0.02),
      ],
    ];

    // Sample congestion scores - will be replaced with ML model
    final List<double> congestionScores = [0.2, 0.85, 0.55];

    // Add polylines with different congestion levels
    for (int i = 0; i < sampleRoutes.length; i++) {
      _polylines.add(
        Polyline(
          points: sampleRoutes[i],
          color: _getRouteColor(congestionScores[i]),
          strokeWidth: 5,
        ),
      );
    }
  }

  // Function to determine route color based on congestion value
  Color _getRouteColor(double congestionScore) {
    if (congestionScore > 0.7) {
      return Colors.red;  // High congestion
    } else if (congestionScore > 0.4) {
      return Colors.orange;  // Medium congestion
    } else {
      return Colors.green;  // Low congestion
    }
  }

  void _goToSafeRoutes(BuildContext context) {
    // Navigate to the SafeRoutesScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SafeRoutesScreen(
          startLocation: _currentLocation,
        ),
      ),
    );
  }

  void _goToAlerts(BuildContext context) {
    Navigator.pushNamed(context, '/alerts');
  }

  void _toggleTraffic() {
    setState(() {
      _showTraffic = !_showTraffic;
      _polylines.clear();

      if (_showTraffic) {
        _generateSampleRoutes();
      }
    });
  }

  // Refresh with actual location data
  void _refreshLocation() async {
    setState(() {
      _isLoading = true;
      _markers.clear();
      _polylines.clear();
    });

    // Check if we have permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // Need to request permissions again
      _requestLocationPermission();
      return;
    }

    // Get actual location
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _locationPermissionGranted = true;
      });

      // If we have a MapController, animate to the new position
      _mapController.move(_currentLocation, _mapController.zoom);

      _loadMapData();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing location: $e'),
          ),
        );
      }

      _loadMapData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Safety Map"),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_showTraffic ? Icons.traffic : Icons.traffic_outlined),
            tooltip: 'Toggle Traffic',
            onPressed: _toggleTraffic,
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            tooltip: 'Alerts',
            onPressed: () => _goToAlerts(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Show location permission request or map
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation,
              zoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: _polylines.toList(),
              ),
              MarkerLayer(
                markers: _markers.toList(),
              ),
            ],
          ),

          // UI Controls overlay
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              heroTag: "location",
              onPressed: _refreshLocation,
              child: const Icon(Icons.my_location),
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[800],
            ),
          ),

          // Legend for congestion levels
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Congestion Levels:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      Container(width: 16, height: 4, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text("Low (0-40%)"),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 16, height: 4, color: Colors.orange),
                      const SizedBox(width: 4),
                      const Text("Medium (40-70%)"),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 16, height: 4, color: Colors.red),
                      const SizedBox(width: 4),
                      const Text("High (70-100%)"),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Card with Route Options
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Card(
              margin: const EdgeInsets.all(12),
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Route Suggestions",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.directions),
                            label: const Text("Safe Routes"),
                            onPressed: () => _goToSafeRoutes(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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