import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'location.dart'; // import your service

class SafeRoutesScreen extends StatefulWidget {
  @override
  _SafeRoutesScreenState createState() => _SafeRoutesScreenState();
}

class _SafeRoutesScreenState extends State<SafeRoutesScreen> {
  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    fetchLocation();
  }

  void fetchLocation() async {
    try {
      final location = await LocationService().getCurrentLocation();
      setState(() {
        currentLocation = LatLng(location.latitude, location.longitude);
      });
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Safe Routes")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: currentLocation == null
                ? Center(child: CircularProgressIndicator())
                : FlutterMap(
              options: MapOptions(
                center: currentLocation,
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 80,
                      height: 80,
                      child: Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Route Safety Info",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text("• Area Risk Score: Low"),
                  Text("• Well-lit route"),
                  Text("• Last incident: 3 weeks ago"),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Back"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      minimumSize: Size(double.infinity, 48),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
