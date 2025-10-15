import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';
import 'package:telephony/telephony.dart';
import 'screens/dashboard.dart';
import 'screens/device_data_screen.dart';

import 'screens/health_risk_screen.dart';
import 'screens/package_recommendation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const CivicApp());
}

Future<void> _requestPermissions() async {
  await [
    Permission.contacts,
    Permission.sms,
    Permission.phone,
  ].request();
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
      routes: {
        '/device_data': (context) => const DeviceDataScreen(),
        '/health_risk': (context) => const HealthRiskScreen(),
        '/package_recommendations': (context) => const PackageRecommendationScreen(),
      },
    );
  }
}

// Example: How to access call logs, SMS, and contacts
Future<void> exampleAccessDeviceData() async {
  // Contacts
  List<Contact> contacts = await FlutterContacts.getContacts(withProperties: true);
  // Call logs (Android only)
  Iterable<CallLogEntry> entries = await CallLog.get();
  // SMS (Android only)
  final Telephony telephony = Telephony.instance;
  List<SmsMessage> messages = await telephony.getInboxSms(columns: [SmsColumn.ADDRESS, SmsColumn.BODY]);
  // Use the above data as needed in your app
}
