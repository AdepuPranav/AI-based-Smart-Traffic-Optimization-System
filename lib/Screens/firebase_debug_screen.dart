import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseDebugScreen extends StatefulWidget {
  @override
  _FirebaseDebugScreenState createState() => _FirebaseDebugScreenState();
}

class _FirebaseDebugScreenState extends State<FirebaseDebugScreen> {
  String _status = 'Checking Firebase RTDB connection...';
  Color _color = Colors.grey;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _status = 'Testing connection...';
      _color = Colors.orange;
    });
    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp();

      // Try reading a simple value (root)
      final ref = FirebaseDatabase.instance.ref();
      final snapshot = await ref.get();

      if (snapshot.exists) {
        setState(() {
          _status = 'Firebase RTDB connection: SUCCESS';
          _color = Colors.green;
        });
      } else {
        setState(() {
          _status = 'Firebase RTDB connection: Connected, but no data at root.';
          _color = Colors.yellow;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Firebase RTDB connection: ERROR $e';
        _color = Colors.red;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase RTDB Debug')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_done, color: _color, size: 60),
              SizedBox(height: 24),
              Text(_status, style: TextStyle(fontSize: 18, color: _color), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
