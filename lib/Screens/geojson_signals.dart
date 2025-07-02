import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Loads traffic signal locations from a local GeoJSON asset.
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

/// Returns only those signals that are within [thresholdMeters] of any point on [path].
List<LatLng> filterSignalsOnRoute(List<LatLng> signals, List<LatLng> path, {double thresholdMeters = 30}) {
  final Distance distance = Distance();
  List<LatLng> filtered = [];
  for (final signal in signals) {
    for (final point in path) {
      if (distance(signal, point) <= thresholdMeters) {
        filtered.add(signal);
        break;
      }
    }
  }
  return filtered;
}
