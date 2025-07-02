import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

/// Real-time stream for lane1 ETA
Stream<int?> lane1EtaStream() {
  final ref = FirebaseDatabase.instance.ref('traffic_data/lane1/estimated_eta');
  return ref.onValue.map((event) {
    final value = event.snapshot.value;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  });
}

class RouteCongestion {
  final double lat;
  final double lng;
  final double congestionLength;

  RouteCongestion({required this.lat, required this.lng, required this.congestionLength});

  factory RouteCongestion.fromMap(Map<dynamic, dynamic> data) {
    return RouteCongestion(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      congestionLength: (data['congestion_length'] as num).toDouble(),
    );
  }
}

// Model for lane 1 ETA
class SignalLaneEta {
  final double lat;
  final double lng;
  final int estimatedEtaSec; // ETA in seconds

  SignalLaneEta({required this.lat, required this.lng, required this.estimatedEtaSec});

  factory SignalLaneEta.fromMap(Map<dynamic, dynamic> data) {
    print('DEBUG: Processing data: $data');
    final trafficData = data['traffic_data'];
    print('DEBUG: traffic_data: $trafficData');
    
    final lane1 = trafficData?['lane1'];
    print('DEBUG: lane1: $lane1');
    
    int etaValue = 0;
    if (lane1 != null && lane1['estimated_eta'] != null) {
      final eta = lane1['estimated_eta'];
      print('DEBUG: estimated_eta: $eta');
      // Handle both int and num cases
      etaValue = eta is int ? eta : (eta as num).toInt();
      print('DEBUG: Using ETA value: $etaValue');
    }
    
    return SignalLaneEta(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      estimatedEtaSec: etaValue,
    );
  }
}

Future<List<SignalLaneEta>> fetchLane1EtaData() async {
  print('DEBUG: fetchLane1EtaData called');
  final ref = FirebaseDatabase.instance.ref('signals');
  final snapshot = await ref.get();
  print('DEBUG: Fetched data: ${snapshot.value}');

  if (!snapshot.exists) {
    print('DEBUG: No data found at root');
    return [];
  }

  final data = snapshot.value as Map<dynamic, dynamic>?;
  print('DEBUG: Data at root: $data');
  if (data != null) {
    print('DEBUG: Data keys: [32m${data.keys}[0m');
  } else {
    print('DEBUG: Data is null after casting');
  }

  if (data == null || !data.containsKey('signals')) {
    print('DEBUG: signals key missing or data is null');
    return [];
  }

  final signals = data['signals'] as Map<dynamic, dynamic>?;
  print('DEBUG: signals: $signals');
  if (signals != null) {
    print('DEBUG: signals keys: [34m${signals.keys}[0m');
  } else {
    print('DEBUG: signals is null');
  }

  return data.values
      .map<SignalLaneEta>((v) => SignalLaneEta.fromMap(v))
      .toList();
}

SignalLaneEta? findClosestLane1Eta(LatLng point, List<SignalLaneEta> etaList) {
  double minDist = double.infinity;
  SignalLaneEta? closest;
  for (final c in etaList) {
    final d = (c.lat - point.latitude).abs() + (c.lng - point.longitude).abs();
    if (d < minDist) {
      minDist = d;
      closest = c;
    }
  }
  return closest;
}

Future<List<RouteCongestion>> fetchCongestionData() async {
  final ref = FirebaseDatabase.instance.ref('signals');
  final snapshot = await ref.get();
  if (snapshot.exists) {
    final data = snapshot.value as Map<dynamic, dynamic>;
    return data.values
        .where((v) => v['congestion_length'] != null)
        .map<RouteCongestion>((v) => RouteCongestion.fromMap(v))
        .toList();
  } else {
    return [];
  }
}

// Helper to find the closest congestion point to a given LatLng
RouteCongestion? findClosestCongestion(LatLng point, List<RouteCongestion> congestionList) {
  double minDist = double.infinity;
  RouteCongestion? closest;
  for (final c in congestionList) {
    final d = (c.lat - point.latitude).abs() + (c.lng - point.longitude).abs();
    if (d < minDist) {
      minDist = d;
      closest = c;
    }
  }
  return closest;
}
