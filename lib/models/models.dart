enum RiskLevel { low, medium, high }

class SuspiciousNumber {
  final String number;
  final int riskScore; // 0-100
  final List<String> tags;
  final DateTime lastChecked;

  const SuspiciousNumber({
    required this.number,
    required this.riskScore,
    required this.tags,
    required this.lastChecked,
  });

  RiskLevel get level => riskScore >= 70
      ? RiskLevel.high
      : riskScore >= 40
          ? RiskLevel.medium
          : RiskLevel.low;
}

class SMSAnalysisResult {
  final int riskScore; // 0-100
  final List<String> reasons;
  final bool containsLink;
  final bool hasUrgency;
  final bool hasMoneyOrPrize;

  const SMSAnalysisResult({
    required this.riskScore,
    required this.reasons,
    required this.containsLink,
    required this.hasUrgency,
    required this.hasMoneyOrPrize,
  });

  RiskLevel get level => riskScore >= 70
      ? RiskLevel.high
      : riskScore >= 40
          ? RiskLevel.medium
          : RiskLevel.low;
}

class FraudAlert {
  final int? id;
  final String type; // sms|number
  final String message;
  final String severity; // low|medium|high
  final DateTime timestamp;

  const FraudAlert({this.id, required this.type, required this.message, required this.severity, required this.timestamp});
}
