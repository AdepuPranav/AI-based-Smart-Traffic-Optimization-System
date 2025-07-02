import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

// A singleton service to manage routes and intersections across the app
class RouteService {
  // Singleton instance
  static final RouteService _instance = RouteService._internal();
  factory RouteService() => _instance;
  RouteService._internal();

  // Store authorized personnel routes
  final List<AuthorizedRoute> _authorizedRoutes = [];
  
  // Listeners for route updates
  final List<Function()> _listeners = [];

  // Add a new authorized route
  void addAuthorizedRoute(AuthorizedRoute route) {
    _authorizedRoutes.add(route);
    _notifyListeners();
  }

  // Get all authorized routes
  List<AuthorizedRoute> get authorizedRoutes => _authorizedRoutes;

  // Add a listener for route updates
  void addListener(Function() listener) {
    _listeners.add(listener);
  }

  // Remove a listener
  void removeListener(Function() listener) {
    _listeners.remove(listener);
  }

  // Notify all listeners of updates
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  // Find intersections between a user route and all authorized routes
  List<RouteIntersection> findIntersections(List<LatLng> userRoute) {
    final List<RouteIntersection> intersections = [];
    
    for (final authorizedRoute in _authorizedRoutes) {
      final intersection = _checkRouteIntersection(userRoute, authorizedRoute);
      if (intersection != null) {
        intersections.add(intersection);
      }
    }
    
    return intersections;
  }

  // Check if a user route intersects with an authorized route
  RouteIntersection? _checkRouteIntersection(List<LatLng> userRoute, AuthorizedRoute authorizedRoute) {
    final List<LatLng> intersectionPoints = [];
    final List<LatLng> authorizedPoints = authorizedRoute.points;
    
    // Find segments that are close to each other
    for (int i = 0; i < userRoute.length - 1; i++) {
      final LatLng start = userRoute[i];
      final LatLng end = userRoute[i + 1];
      
      for (int j = 0; j < authorizedPoints.length - 1; j++) {
        final LatLng authStart = authorizedPoints[j];
        final LatLng authEnd = authorizedPoints[j + 1];
        
        // Check if segments are close (within 100 meters)
        if (_areSegmentsClose(start, end, authStart, authEnd, 0.1)) {
          // Add this segment to intersections
          if (intersectionPoints.isEmpty || intersectionPoints.last != start) {
            intersectionPoints.add(start);
          }
          intersectionPoints.add(end);
        }
      }
    }
    
    if (intersectionPoints.length >= 2) {
      return RouteIntersection(
        userRouteSegment: intersectionPoints,
        authorizedRoute: authorizedRoute,
        congestionFactor: authorizedRoute.congestion,
      );
    }
    
    return null;
  }

  // Check if two segments are close to each other
  bool _areSegmentsClose(LatLng a1, LatLng a2, LatLng b1, LatLng b2, double threshold) {
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

  // Calculate distance between two points using Haversine formula
  double _haversineDistance(LatLng start, LatLng end) {
    const int earthRadius = 6371; // km
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double lon1 = start.longitude * math.pi / 180;
    final double lon2 = end.longitude * math.pi / 180;
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  // Clear all routes (for testing)
  void clearRoutes() {
    _authorizedRoutes.clear();
    _notifyListeners();
  }
}

// Represents a route created by authorized personnel
class AuthorizedRoute {
  final String id;
  final List<LatLng> points;
  final double congestion;
  final String startLocationName;
  final String endLocationName;
  final DateTime createdAt;

  AuthorizedRoute({
    required this.id,
    required this.points,
    required this.congestion,
    required this.startLocationName,
    required this.endLocationName,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();
}

// Represents an intersection between user route and authorized route
class RouteIntersection {
  final List<LatLng> userRouteSegment;
  final AuthorizedRoute authorizedRoute;
  final double congestionFactor;

  RouteIntersection({
    required this.userRouteSegment,
    required this.authorizedRoute,
    required this.congestionFactor,
  });
}
