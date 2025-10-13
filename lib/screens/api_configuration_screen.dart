import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen> {
  final _abuseIpDbController = TextEditingController();
  final _safeBrowsingController = TextEditingController();
  final _fraudScoreController = TextEditingController();
  
  bool _obscureKeys = true;
  bool _testingApis = false;
  Map<String, bool> _apiStatus = {};

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
  }

  @override
  void dispose() {
    _abuseIpDbController.dispose();
    _safeBrowsingController.dispose();
    _fraudScoreController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _abuseIpDbController.text = prefs.getString('abuseipdb_api_key') ?? '';
      _safeBrowsingController.text = prefs.getString('safe_browsing_api_key') ?? '';
      _fraudScoreController.text = prefs.getString('fraudscore_api_key') ?? '';
    });
  }

  Future<void> _saveApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('abuseipdb_api_key', _abuseIpDbController.text.trim());
    await prefs.setString('safe_browsing_api_key', _safeBrowsingController.text.trim());
    await prefs.setString('fraudscore_api_key', _fraudScoreController.text.trim());
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API keys saved successfully')),
    );
  }

  Future<void> _testApiConnections() async {
    setState(() {
      _testingApis = true;
      _apiStatus.clear();
    });

    // Test each API with a simple request
    await _testAbuseIpDb();
    await _testSafeBrowsing();
    await _testFraudScore();

    setState(() => _testingApis = false);
    
    _showTestResults();
  }

  Future<void> _testAbuseIpDb() async {
    final apiKey = _abuseIpDbController.text.trim();
    if (apiKey.isEmpty) {
      _apiStatus['abuseipdb'] = false;
      return;
    }

    try {
      // Simple test request to AbuseIPDB
      final response = await http.get(
        Uri.parse('https://api.abuseipdb.com/api/v2/check?ipAddress=127.0.0.1&maxAgeInDays=90'),
        headers: {
          'Key': apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      _apiStatus['abuseipdb'] = response.statusCode == 200;
    } catch (e) {
      _apiStatus['abuseipdb'] = false;
    }
  }

  Future<void> _testSafeBrowsing() async {
    final apiKey = _safeBrowsingController.text.trim();
    if (apiKey.isEmpty) {
      _apiStatus['safe_browsing'] = false;
      return;
    }

    try {
      // Test request to Safe Browsing API
      final response = await http.post(
        Uri.parse('https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client': {'clientId': 'civic-fraud-protection', 'clientVersion': '1.0.0'},
          'threatInfo': {
            'threatTypes': ['MALWARE'],
            'platformTypes': ['ANY_PLATFORM'],
            'threatEntryTypes': ['URL'],
            'threatEntries': [{'url': 'http://malware.testing.google.test/testing/malware/'}]
          }
        }),
      ).timeout(const Duration(seconds: 10));
      
      _apiStatus['safe_browsing'] = response.statusCode == 200;
    } catch (e) {
      _apiStatus['safe_browsing'] = false;
    }
  }

  Future<void> _testFraudScore() async {
    final apiKey = _fraudScoreController.text.trim();
    if (apiKey.isEmpty) {
      _apiStatus['fraudscore'] = false;
      return;
    }

    try {
      // Test request to FraudScore API
      final response = await http.get(
        Uri.parse('https://ipqualityscore.com/api/json/phone/$apiKey/+1234567890'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      _apiStatus['fraudscore'] = response.statusCode == 200;
    } catch (e) {
      _apiStatus['fraudscore'] = false;
    }
  }

  void _showTestResults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Test Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTestResultRow('AbuseIPDB', _apiStatus['abuseipdb']),
            _buildTestResultRow('Safe Browsing', _apiStatus['safe_browsing']),
            _buildTestResultRow('FraudScore', _apiStatus['fraudscore']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(String service, bool? status) {
    IconData icon;
    Color color;
    String text;
    
    if (status == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      text = 'Not tested';
    } else if (status) {
      icon = Icons.check_circle;
      color = Colors.green;
      text = 'Connected';
    } else {
      icon = Icons.error;
      color = Colors.red;
      text = 'Failed';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text('$service: $text'),
        ],
      ),
    );
  }

  void _showApiGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Setup Guide'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildApiGuideSection(
                'AbuseIPDB',
                'Free API for IP reputation checking',
                '1. Visit abuseipdb.com\n2. Create free account\n3. Go to API section\n4. Generate API key',
                'Provides: IP reputation, abuse reports, threat intelligence'
              ),
              const SizedBox(height: 16),
              _buildApiGuideSection(
                'Google Safe Browsing',
                'Google\'s URL safety API',
                '1. Go to Google Cloud Console\n2. Enable Safe Browsing API\n3. Create API credentials\n4. Copy API key',
                'Provides: URL safety, malware detection, phishing protection'
              ),
              const SizedBox(height: 16),
              _buildApiGuideSection(
                'FraudScore (IPQualityScore)',
                'Phone number reputation API',
                '1. Sign up at ipqualityscore.com\n2. Get free API key\n3. Choose phone validation plan',
                'Provides: Phone validation, carrier info, fraud risk scoring'
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildApiGuideSection(String title, String subtitle, String steps, String features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 8),
        Text('Setup Steps:', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(steps, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 4),
        Text('Features:', style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(features, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Configuration'),
        actions: [
          IconButton(
            onPressed: _showApiGuide,
            icon: const Icon(Icons.help_outline),
            tooltip: 'API Setup Guide',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Real-Time Threat Intelligence', 
                               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Configure API keys to enable real-time fraud detection with global threat intelligence. '
                      'Without API keys, the app will use local analysis only.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // API Key Input Fields
            _buildApiKeyField(
              'AbuseIPDB API Key',
              'IP reputation and abuse reports',
              _abuseIpDbController,
              Icons.security,
            ),
            
            const SizedBox(height: 16),
            
            _buildApiKeyField(
              'Google Safe Browsing API Key',
              'URL safety and malware detection',
              _safeBrowsingController,
              Icons.link,
            ),
            
            const SizedBox(height: 16),
            
            _buildApiKeyField(
              'FraudScore API Key',
              'Phone number validation and fraud scoring',
              _fraudScoreController,
              Icons.phone,
            ),
            
            const SizedBox(height: 24),
            
            // Visibility Toggle
            Row(
              children: [
                Checkbox(
                  value: !_obscureKeys,
                  onChanged: (value) => setState(() => _obscureKeys = !value!),
                ),
                const Text('Show API keys'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveApiKeys,
                    child: const Text('Save Keys'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testingApis ? null : _testApiConnections,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _testingApis 
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16, 
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(width: 8),
                            Text('Testing...'),
                          ],
                        )
                      : const Text('Test APIs'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyField(String title, String subtitle, TextEditingController controller, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              obscureText: _obscureKeys,
              decoration: InputDecoration(
                hintText: 'Enter your ${title.toLowerCase()}',
                border: const OutlineInputBorder(),
                suffixIcon: controller.text.isNotEmpty 
                  ? const Icon(Icons.check, color: Colors.green)
                  : const Icon(Icons.key, color: Colors.grey),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}