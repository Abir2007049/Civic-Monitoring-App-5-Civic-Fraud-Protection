import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ThreatIntelligenceService {
  // Real API endpoints for threat intelligence
  static const _abuseIpDbBase = 'https://api.abuseipdb.com/api/v2';
  static const _safeBrowsingBase = 'https://safebrowsing.googleapis.com/v4/threatMatches:find';
  static const _fraudScoreBase = 'https://ipqualityscore.com/api/json/phone';
  
  // In-memory cache for API responses
  final Map<String, Map<String, dynamic>> _cache = {};

  /// Get saved API keys from shared preferences
  Future<Map<String, String>> _getApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'abuseipdb': prefs.getString('abuseipdb_api_key') ?? '',
      'safe_browsing': prefs.getString('safe_browsing_api_key') ?? '',
      'fraudscore': prefs.getString('fraudscore_api_key') ?? '',
    };
  }
  
  Future<Map<String, dynamic>> checkNumberWithAPI(String number, {String? apiKey}) async {
    // Check cache first
    if (_cache.containsKey(number)) {
      final cached = _cache[number]!;
      final cacheTime = DateTime.parse(cached['cached_at'] as String);
      if (DateTime.now().difference(cacheTime).inHours < 24) {
        return cached;
      }
    }

    // Get API keys if not provided
    final keys = await _getApiKeys();
    final useApiKey = apiKey ?? keys['abuseipdb'] ?? '';
    
    // Debug: Show what key is being used
    print('🔍 AbuseIPDB API Key check: ${useApiKey.isNotEmpty ? "${useApiKey.substring(0, 8)}..." : "EMPTY"}');
    
    // If no API key available, use enhanced mock response
    if (useApiKey.isEmpty) {
      print('⚠️ No AbuseIPDB API key found, using mock response');
      return _getMockResponse(number);
    }
    
    print('✅ Using real AbuseIPDB API with key: ${useApiKey.substring(0, 8)}...');

    try {
      // Try FraudScore API first for phone numbers
      if (keys['fraudscore']!.isNotEmpty) {
        final fraudResult = await checkPhoneWithFraudScore(number, apiKey: keys['fraudscore']!);
        if (fraudResult['source'] == 'FraudScore') {
          return fraudResult;
        }
      }

      // Fallback to AbuseIPDB for general reputation
      final response = await http.get(
        Uri.parse('$_abuseIpDbBase/check'),
        headers: {
          'Key': useApiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

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
    // Stricter URL validation: require protocol, valid domain, and only allow real/common TLDs
    final allowedTlds = [
      'com','org','net','gov','edu','io','co','us','uk','in','info','biz','me','app','dev','ai','ca','au','de','fr','jp','cn','ru','br','za','eu','tv','cc','xyz','site','online','store','tech','pro','club','news','live','digital','agency','solutions','group','media','world','today','company','systems','center','academy','support','cloud','network','consulting','finance','capital','law','health','care','shop','blog','press','space','website','fun','games','video','music','design','art','photo','photos','gallery','studio','works','events','team','partners','ventures','foundation','charity','ngo','int','mil','gov','edu','museum','name','mobi','asia','cat','jobs','tel','travel','xxx','id','my','sg','th','vn','ph','kr','hk','tw','es','it','pl','se','no','fi','dk','be','ch','at','cz','sk','hu','ro','bg','gr','tr','il','sa','ae','ir','pk','bd','lk','np','ua','by','kz','uz','ge','am','az','md','rs','hr','si','ba','me','al','mk','lt','lv','ee','is','lu','mt','cy','mc','sm','li','gi','fo','gl','je','gg','im','ax','bl','mf','pm','re','yt','tf','wf','pf','nc','gp','mq','gf','sr','aw','cw','sx','bq','vg','vi','ai','ms','bm','ky','tc','fk','gs','sh','ac','io','aq','bv','hm','sj','tf','um','wf','yt'
    ];
    final tldPattern = allowedTlds.join('|');
    final strictUrlPattern = RegExp(r'^(https?:\/\/)?([a-zA-Z0-9\-]+\.)+(' + tldPattern + r')(\:[0-9]+)?(\/[^\s]*)?$', caseSensitive: false);
    if (!strictUrlPattern.hasMatch(url.trim())) {
      return {
        'error': 'Invalid URL format',
        'riskScore': 90,
        'message': 'Malformed or invalid URL detected',
        'categories': ['invalid_url', 'malformed'],
        'source': 'Local Validation',
        'cached_at': DateTime.now().toIso8601String(),
      };
    }
    
    // Get saved API keys
    final keys = await _getApiKeys();
    final useApiKey = apiKey ?? keys['safe_browsing'] ?? '';
    
    // Debug: Show what key is being used
    print('🔍 Google Safe Browsing API Key check: ${useApiKey.isNotEmpty ? "${useApiKey.substring(0, 8)}..." : "EMPTY"}');
    
    // If no API key available, use enhanced mock response
    if (useApiKey.isEmpty) {
      print('⚠️ No Safe Browsing API key found, using mock response');
      return _getMockURLResponse(url);
    }
    
    print('✅ Using real Google Safe Browsing API with key: ${useApiKey.substring(0, 8)}...');

    try {
      // Google Safe Browsing API for URL checking
      final requestBody = {
        'client': {
          'clientId': 'civic-fraud-protection',
          'clientVersion': '1.0.0'
        },
        'threatInfo': {
          'threatTypes': ['MALWARE', 'SOCIAL_ENGINEERING', 'UNWANTED_SOFTWARE'],
          'platformTypes': ['ANY_PLATFORM'],
          'threatEntryTypes': ['URL'],
          'threatEntries': [{'url': url}]
        }
      };
      
      final response = await http.post(
        Uri.parse('$_safeBrowsingBase?key=$useApiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return _getMockURLResponse(url);
      }
    } catch (e) {
      return _getMockURLResponse(url);
    }
  }

  /// Check phone number using FraudScore API for advanced reputation analysis
  Future<Map<String, dynamic>> checkPhoneWithFraudScore(String phoneNumber, {required String apiKey}) async {
    if (apiKey.isEmpty) {
      return _getMockResponse(phoneNumber);
    }

    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final response = await http.get(
        Uri.parse('$_fraudScoreBase/$apiKey/$cleanPhone'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Transform FraudScore response to our format
        return {
          'phone': phoneNumber,
          'risk_score': data['fraud_score'] ?? 0,
          'carrier': data['carrier'] ?? 'Unknown',
          'line_type': data['line_type'] ?? 'Unknown',
          'country': data['country'] ?? 'Unknown',
          'region': data['region'] ?? 'Unknown',
          'city': data['city'] ?? 'Unknown',
          'valid': data['valid'] ?? false,
          'active': data['active'] ?? false,
          'recent_abuse': data['recent_abuse'] ?? false,
          'leaked': data['leaked'] ?? false,
          'spammer': data['spammer'] ?? false,
          'risky': data['risky'] ?? false,
          'reputation': data['reputation'] ?? 'unknown',
          'source': 'FraudScore',
          'checked_at': DateTime.now().toIso8601String(),
        };
      } else {
        return _getMockResponse(phoneNumber);
      }
    } catch (e) {
      return _getMockResponse(phoneNumber);
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

    if (uri == null || uri.host.isEmpty) {
      return {
        'error': 'Invalid URL format',
        'riskScore': 95,
        'message': 'URL validation failed - malformed or empty host',
        'categories': ['invalid_url', 'malformed'],
        'source': 'Local Analysis',
        'cached_at': DateTime.now().toIso8601String(),
      };
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