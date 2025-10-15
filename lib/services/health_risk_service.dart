import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'db_service.dart';

/// Service to detect health-related mentions in text that could indicate
/// community health risks (disease outbreaks, contamination, etc.)
class HealthRiskService {
  // Health risk keywords categorized by severity
  static const Map<String, List<String>> _healthKeywords = {
    'disease_outbreak': [
      'outbreak', 'epidemic', 'pandemic', 'contagious', 'infectious',
      'spreading fast', 'many sick', 'virus spreading', 'disease spreading',
      'infected', 'contaminated', 'quarantine', 'isolation ward',
      'fever outbreak', 'flu outbreak', 'cholera', 'dengue', 'typhoid',
      'hepatitis', 'tuberculosis', 'tb outbreak', 'measles', 'mumps',
      'covid', 'coronavirus', 'bird flu', 'swine flu', 'ebola', 'zika',
    ],
    'food_water_contamination': [
      'food poisoning', 'contaminated water', 'dirty water', 'water supply',
      'unsafe water', 'polluted water', 'bad food', 'spoiled food',
      'stomach infection', 'diarrhea outbreak', 'vomiting', 'gastroenteritis',
      'food contamination', 'expired food', 'rotten food', 'unsafe food',
      'water borne', 'waterborne disease', 'food borne', 'foodborne',
    ],
    'environmental_health': [
      'air pollution', 'toxic fumes', 'chemical leak', 'gas leak',
      'hazardous waste', 'radiation', 'asbestos', 'lead poisoning',
      'air quality', 'smog', 'dust storm', 'breathing problems',
      'respiratory issues', 'asthma attack', 'allergic reaction widespread',
    ],
    'medical_emergency': [
      'hospital full', 'no beds available', 'shortage medicine',
      'medicine unavailable', 'pharmacy out of stock', 'no doctors',
      'medical emergency', 'ambulance delay', 'healthcare crisis',
      'oxygen shortage', 'blood shortage', 'vaccine shortage',
      // acute events
      'heart attack', 'stroke', 'cardiac arrest', 'severe allergic reaction', 'anaphylaxis',
    ],
    'symptoms_cluster': [
      'many people sick', 'everyone sick', 'whole family sick',
      'entire village', 'entire area', 'neighborhood sick',
      'school closed sick', 'office closed sick', 'mass illness',
      'several cases', 'multiple patients', 'cluster of cases',
    ],
    'injury_emergency': [
      'injury', 'injured', 'accident', 'car crash', 'road accident', 'traffic accident',
      'fracture', 'broken bone', 'dislocation', 'sprain', 'cut', 'deep cut', 'wound',
      'knife wound', 'gunshot', 'bleeding heavily', 'severe bleeding', 'hemorrhage',
      'burn', 'burned', 'chemical burn', 'electric shock', 'electrocution',
      'head injury', 'concussion', 'fainted', 'unconscious', 'drowning', 'poisoning', 'overdose',
      'snake bite', 'dog bite', 'animal bite',
    ],
  };

  static const List<String> _urgentSymptoms = [
    'high fever', 'severe headache', 'difficulty breathing', 'chest pain',
    'persistent vomiting', 'bloody diarrhea', 'seizure', 'unconscious',
    'skin rash', 'jaundice', 'yellow eyes', 'bleeding', 'severe pain',
    'cannot breathe', 'loss of consciousness', 'severe burn', 'broken bone',
  ];

  /// Analyzes text for health risk indicators
  Future<HealthRiskResult> analyzeText(String text) async {
    if (text.trim().isEmpty) {
      return HealthRiskResult(
        riskLevel: RiskLevel.low,
        confidence: 0.0,
        detectedKeywords: [],
        categories: [],
        message: 'No text to analyze',
      );
    }

    final lowerText = text.toLowerCase();
    final List<String> detectedKeywords = [];
    final Set<String> categories = {};
    int totalMatches = 0;
    int highPriorityMatches = 0;

    // Check each category
    _healthKeywords.forEach((category, keywords) {
      for (final keyword in keywords) {
        if (lowerText.contains(keyword.toLowerCase())) {
          detectedKeywords.add(keyword);
          categories.add(category);
          totalMatches++;
          
          // High priority categories
          if (category == 'disease_outbreak' || category == 'medical_emergency') {
            highPriorityMatches += 2;
          } else {
            highPriorityMatches += 1;
          }
        }
      }
    });

    // Check urgent symptoms
    for (final symptom in _urgentSymptoms) {
      if (lowerText.contains(symptom.toLowerCase())) {
        detectedKeywords.add(symptom);
        categories.add('urgent_symptoms');
        highPriorityMatches += 2;
        totalMatches++;
      }
    }

    // Calculate risk level based on matches
    RiskLevel riskLevel;
    double confidence;
    String message;

    if (totalMatches == 0) {
      riskLevel = RiskLevel.low;
      confidence = 0.0;
      message = 'No health risk indicators detected';
    } else if (highPriorityMatches >= 4 || categories.contains('disease_outbreak')) {
      riskLevel = RiskLevel.high;
      confidence = 0.85 + (totalMatches * 0.02).clamp(0.0, 0.15);
      message = 'High health risk detected - Immediate attention required';
    } else if (highPriorityMatches >= 2 || totalMatches >= 3) {
      riskLevel = RiskLevel.medium;
      confidence = 0.60 + (totalMatches * 0.03).clamp(0.0, 0.30);
      message = 'Moderate health risk detected - Monitor situation';
    } else {
      riskLevel = RiskLevel.low;
      confidence = 0.30 + (totalMatches * 0.05).clamp(0.0, 0.20);
      message = 'Low health risk - Minor health mention detected';
    }

    // Save to database if medium or high risk
    if (riskLevel == RiskLevel.medium || riskLevel == RiskLevel.high) {
      await _saveHealthAlert(text, riskLevel, detectedKeywords, categories.toList());
    }

    return HealthRiskResult(
      riskLevel: riskLevel,
      confidence: confidence,
      detectedKeywords: detectedKeywords,
      categories: categories.toList(),
      message: message,
      recommendations: _generateRecommendations(categories.toList(), riskLevel),
    );
  }

  /// Saves health alert to database
  Future<void> _saveHealthAlert(
    String text,
    RiskLevel riskLevel,
    List<String> keywords,
    List<String> categories,
  ) async {
    final alert = FraudAlert(
        type: 'health',
        severity: riskLevel.name,
        message: 'Health risk: ${categories.join(", ")} - ${keywords.take(3).join(", ")}',
        timestamp: DateTime.now(),
    );
    
      await AppDatabase.instance.addAlert(alert);
  }

  /// Generates recommendations based on detected categories
  List<String> _generateRecommendations(List<String> categories, RiskLevel risk) {
    final recommendations = <String>[];

    if (categories.contains('disease_outbreak')) {
      recommendations.add('🏥 Report to local health authorities immediately');
      recommendations.add('😷 Follow hygiene protocols and wear masks');
      recommendations.add('🚫 Avoid crowded areas if possible');
    }

    if (categories.contains('food_water_contamination')) {
      recommendations.add('💧 Boil drinking water before consumption');
      recommendations.add('🍲 Avoid eating outside food');
      recommendations.add('🚰 Report to water supply authority');
    }

    if (categories.contains('environmental_health')) {
      recommendations.add('🌬️ Stay indoors if air quality is poor');
      recommendations.add('😷 Use N95 masks if going outside');
      recommendations.add('📞 Contact environmental protection agency');
    }

    if (categories.contains('medical_emergency')) {
      recommendations.add('🚑 Contact emergency medical services');
      recommendations.add('🏥 Identify alternative healthcare facilities');
      recommendations.add('💊 Stock essential medicines if possible');
    }

    if (categories.contains('symptoms_cluster')) {
      recommendations.add('📊 Monitor and document cases in your area');
      recommendations.add('🏥 Report cluster to local health department');
      recommendations.add('🔒 Practice social distancing');
    }

    // General recommendations based on risk level
    if (risk == RiskLevel.high) {
      recommendations.add('⚠️ Share this information with neighbors');
      recommendations.add('📱 Keep emergency contacts readily available');
    }

    if (recommendations.isEmpty) {
      recommendations.add('ℹ️ Monitor the situation and stay informed');
      recommendations.add('📱 Report any worsening conditions to authorities');
    }

    return recommendations;
  }

  /// Batch analyze multiple texts (e.g., SMS messages)
  Future<List<HealthRiskResult>> analyzeMultiple(List<String> texts) async {
    final results = <HealthRiskResult>[];
    for (final text in texts) {
      results.add(await analyzeText(text));
    }
    return results;
  }

  /// Get statistics on health risks detected
  Future<HealthRiskStats> getStats() async {
    final alerts = await AppDatabase.instance.getAlerts();
      final healthAlerts = alerts.where((a) => a.type == 'health').toList();

    return HealthRiskStats(
      totalAlerts: healthAlerts.length,
        highRiskCount: healthAlerts.where((a) => a.severity == 'high').length,
        mediumRiskCount: healthAlerts.where((a) => a.severity == 'medium').length,
        lowRiskCount: healthAlerts.where((a) => a.severity == 'low').length,
      recentAlerts: healthAlerts.take(10).toList(),
    );
  }
}

/// Result of health risk analysis
class HealthRiskResult {
  final RiskLevel riskLevel;
  final double confidence;
  final List<String> detectedKeywords;
  final List<String> categories;
  final String message;
  final List<String> recommendations;

  HealthRiskResult({
    required this.riskLevel,
    required this.confidence,
    required this.detectedKeywords,
    required this.categories,
    required this.message,
    this.recommendations = const [],
  });
}

/// Statistics for health risk monitoring
class HealthRiskStats {
  final int totalAlerts;
  final int highRiskCount;
  final int mediumRiskCount;
  final int lowRiskCount;
  final List<FraudAlert> recentAlerts;

  HealthRiskStats({
    required this.totalAlerts,
    required this.highRiskCount,
    required this.mediumRiskCount,
    required this.lowRiskCount,
    required this.recentAlerts,
  });
}
