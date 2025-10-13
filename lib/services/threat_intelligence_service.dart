import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ThreatIntelligenceService {
  // Mock API endpoints - in production, use real threat intelligence APIs
  static const _mockApiBase = 'https://api.example.com'; // Replace with real API
  
  // In-memory cache for API responses
  final Map<String, Map<String, dynamic>> _cache = {};
  
  Future<Map<String, dynamic>> checkNumberWithAPI(String number, {String? apiKey}) async {
    // Check cache first
    if (_cache.containsKey(number)) {
      final cached = _cache[number]!;
      final cacheTime = DateTime.parse(cached['cached_at'] as String);
      if (DateTime.now().difference(cacheTime).inHours < 24) {
        return cached;
      }
    }

    try {
      // Mock API call - replace with real threat intelligence API
      final response = await http.get(
        Uri.parse('$_mockApiBase/check-number?number=$number'),
        headers: {
          'Authorization': 'Bearer ${apiKey ?? 'demo-key'}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        data['cached_at'] = DateTime.now().toIso8601String();
        _cache[number] = data;
        return data;
      } else {
        // For demo purposes, return mock data based on number patterns
        return _getMockResponse(number);
      }
    } catch (e) {
      // Fallback to mock response if API fails
      return _getMockResponse(number);
    }
  }

  Future<Map<String, dynamic>> checkURLWithAPI(String url, {String? apiKey}) async {
    try {
      // Mock URL reputation check
      final response = await http.post(
        Uri.parse('$_mockApiBase/check-url'),
        headers: {
          'Authorization': 'Bearer ${apiKey ?? 'demo-key'}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _getMockURLResponse(url);
      }
    } catch (e) {
      return _getMockURLResponse(url);
    }
  }

  Map<String, dynamic> _getMockResponse(String number) {
    // Generate realistic mock responses based on number patterns
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Known spam prefixes for demo
    final spamPrefixes = ['1800', '140', '999', '000'];
    final isSpamPrefix = spamPrefixes.any((prefix) => cleanNumber.startsWith(prefix));
    
    // Repeated digits check
    final hasRepeats = cleanNumber.length > 3 && 
        cleanNumber.split('').toSet().length <= 2;

    int riskScore = 10; // Base score
    final List<String> sources = ['local_analysis'];
    final List<String> categories = [];

    if (isSpamPrefix) {
      riskScore += 40;
      categories.add('telemarketing');
      sources.add('spam_database');
    }

    if (hasRepeats) {
      riskScore += 30;
      categories.add('suspicious_pattern');
    }

    if (cleanNumber.length < 8) {
      riskScore += 20;
      categories.add('invalid_format');
    }

    return {
      'number': number,
      'risk_score': riskScore.clamp(0, 100),
      'categories': categories,
      'sources': sources,
      'last_reported': DateTime.now().subtract(
        Duration(days: riskScore > 50 ? 1 : 30)
      ).toIso8601String(),
      'report_count': riskScore > 50 ? (riskScore / 10).round() : 0,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _getMockURLResponse(String url) {
    final uri = Uri.tryParse(url);
    int riskScore = 0;
    final List<String> categories = [];

    if (uri == null) {
      riskScore = 80;
      categories.add('malformed_url');
    } else {
      // Check for suspicious domains
      final suspiciousDomains = ['bit.ly', 'tinyurl.com', 'goo.gl', 't.co'];
      if (suspiciousDomains.contains(uri.host)) {
        riskScore += 60;
        categories.add('url_shortener');
      }

      // Check for suspicious TLDs
      final suspiciousTlds = ['.tk', '.ml', '.ga', '.cf'];
      if (suspiciousTlds.any((tld) => uri.host.endsWith(tld))) {
        riskScore += 40;
        categories.add('suspicious_tld');
      }

      // Check for HTTPS
      if (uri.scheme != 'https') {
        riskScore += 20;
        categories.add('no_ssl');
      }

      // Check for suspicious paths
      if (uri.path.contains('login') || uri.path.contains('verify')) {
        riskScore += 30;
        categories.add('phishing_indicators');
      }
    }

    return {
      'url': url,
      'risk_score': riskScore.clamp(0, 100),
      'categories': categories,
      'blocked': riskScore >= 70,
      'last_seen': DateTime.now().subtract(
        Duration(hours: riskScore > 50 ? 1 : 24)
      ).toIso8601String(),
    };
  }

  void clearCache() {
    _cache.clear();
  }

  int getCacheSize() {
    return _cache.length;
  }
}