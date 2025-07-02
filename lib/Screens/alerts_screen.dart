import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  final List<Map<String, String>> mockAlerts = [
    {
      "title": "Suspicious Activity",
      "location": "Madhapur",
      "time": "2 hours ago",
    },
    {
      "title": "Theft Reported",
      "location": "Kukatpally",
      "time": "5 hours ago",
    },
    {
      "title": "Road Accident",
      "location": "Banjara Hills",
      "time": "Yesterday",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Safety Alerts"),
      ),
      body: ListView.builder(
        itemCount: mockAlerts.length,
        itemBuilder: (context, index) {
          final alert = mockAlerts[index];
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: Colors.red),
              title: Text(alert['title'] ?? ""),
              subtitle: Text("${alert['location']} • ${alert['time']}"),
              trailing: Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                // Optional: show details
              },
            ),
          );
        },
      ),
    );
  }
}
