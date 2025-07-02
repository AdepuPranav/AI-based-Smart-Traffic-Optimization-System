import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';

class TrafficSignalETA {
  final LatLng location;
  final int? lane1;
  final int? lane2;
  final int? lane3;
  final int? lane4;
  final int laneCount;
  final int? eta;

  TrafficSignalETA({
    required this.location,
    this.lane1,
    this.lane2,
    this.lane3,
    this.lane4,
    required this.laneCount,
    this.eta,
  });
}

/// Fetches ETA for the upcoming signal on the route using Firebase lane data.
Future<TrafficSignalETA?> getUpcomingSignalETA({
  required List<LatLng> filteredSignals,
  required List<LatLng> path,
  double matchToleranceDegrees = 0.0002, // ~20m
}) async {
  if (filteredSignals.isEmpty) return null;

  // Find the next signal ahead on the path
  LatLng? nextSignal;
  double minDist = double.infinity;
  for (final signal in filteredSignals) {
    for (final point in path) {
      final d = Distance()(signal, point);
      if (d < minDist) {
        minDist = d;
        nextSignal = signal;
      }
    }
  }
  if (nextSignal == null) return null;

  // Fetch signal timings from Firebase and match by lat/lng
  final snapshot = await FirebaseDatabase.instance.ref('signals').get();
  if (!snapshot.exists) return null;
  final data = snapshot.value as Map<dynamic, dynamic>;
  MapEntry? matchedEntry;
  double minDbDist = matchToleranceDegrees;
  for (var entry in data.entries) {
    final v = entry.value;
    if (v['lat'] != null && v['lng'] != null) {
      final d = (v['lat'] - nextSignal.latitude).abs() + (v['lng'] - nextSignal.longitude).abs();
      if (d < minDbDist) {
        minDbDist = d;
        matchedEntry = entry;
      }
    }
  }
  if (matchedEntry == null) {
    return TrafficSignalETA(location: nextSignal, laneCount: 0);
  }
  final v = matchedEntry.value;
  // Count non-null lanes
  final lanes = [v['lane1'], v['lane2'], v['lane3'], v['lane4']];
  final laneCount = lanes.where((l) => l != null).length;
  // Simple ETA prediction: average of available lanes
  // Always use ETA from database key; ignore timestamp and other keys
  int? eta = v['eta'];
  return TrafficSignalETA(
    location: nextSignal,
    lane1: v['lane1'],
    lane2: v['lane2'],
    lane3: v['lane3'],
    lane4: v['lane4'],
    laneCount: laneCount,
    eta: eta,
  );
}
