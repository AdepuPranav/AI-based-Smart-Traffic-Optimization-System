import 'package:flutter/material.dart';
import 'screens/splashscreen.dart';
import 'screens/login.dart';
import 'screens/home_screen.dart';
import 'screens/mapscreen.dart';
import 'screens/reportscreen.dart';
import 'screens/alerts_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  runApp(SafetyApp());
}

class SafetyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/home': (context) => HomeScreen(),
        '/safe_routes': (context) => SafeRoutesScreen(),
        '/report': (context) => ReportIncidentScreen(),
        '/alerts': (context) => AlertsScreen(),
      },
    );
  }
}