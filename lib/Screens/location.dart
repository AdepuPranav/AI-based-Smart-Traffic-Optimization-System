import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

class LocationResult {
  final String displayName;
  final LatLng location;
  final String placeId;
  final Map<String, dynamic> properties;

  LocationResult({
    required this.displayName,
    required this.location,
    required this.placeId,
    required this.properties,
  });

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      displayName: json['display_name'] ?? 'Unknown location',
      location: LatLng(
        double.parse(json['lat']),
        double.parse(json['lon']),
      ),
      placeId: json['place_id'].toString(),
      properties: json,
    );
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  
  factory LocationService() {
    return _instance;
  }
  
  LocationService._internal();
  
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permission permanently denied.");
    }
    
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
  
  Future<List<LocationResult>> searchLocations(String query, {LatLng? nearLocation}) async {
    if (query.isEmpty) {
      return [];
    }
    
    // Build base URL
    String urlString = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=10';
    
    // Add viewbox parameter if nearLocation is provided to prioritize nearby results
    if (nearLocation != null) {
      // Create a bounding box around the nearLocation (roughly 100km radius)
      final double lat = nearLocation.latitude;
      final double lng = nearLocation.longitude;
      final double boxSize = 1.0; // Roughly 100km at equator
      
      // Add viewbox parameter to prioritize results in this area
      urlString += '&viewbox=${lng-boxSize},${lat-boxSize},${lng+boxSize},${lat+boxSize}&bounded=0';
    }
    
    final url = Uri.parse(urlString);
    
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'SafeRoutesApp/1.0', // Required by Nominatim API
        'Accept-Language': 'en-US,en', // Prefer English results
      },
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      List<LocationResult> results = data.map((json) => LocationResult.fromJson(json)).toList();
      
      // If nearLocation is provided, sort results by distance
      if (nearLocation != null) {
        results.sort((a, b) {
          final distA = _calculateDistance(nearLocation, a.location);
          final distB = _calculateDistance(nearLocation, b.location);
          return distA.compareTo(distB);
        });
      }
      
      return results;
    } else {
      throw Exception('Failed to search locations: ${response.statusCode}');
    }
  }
  
  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double lat1 = point1.latitude * (math.pi / 180);
    final double lat2 = point2.latitude * (math.pi / 180);
    final double lon1 = point1.longitude * (math.pi / 180);
    final double lon2 = point2.longitude * (math.pi / 180);
    
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    
    final double a = math.sin(dLat/2) * math.sin(dLat/2) +
                    math.cos(lat1) * math.cos(lat2) *
                    math.sin(dLon/2) * math.sin(dLon/2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return earthRadius * c;
  }
}

// No API key required for public Nominatim usage. For production, consider using a private instance or API key and load it from .env using dotenv.
