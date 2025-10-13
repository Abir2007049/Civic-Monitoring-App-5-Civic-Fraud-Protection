import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const CivicApp());
}

class CivicApp extends StatelessWidget {
  const CivicApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic App - Fraud Protection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
