// Core data models for fraud detection and identity protection

class SuspiciousNumber {
  final String phoneNumber;
  final String riskLevel; // low, medium, high, critical
  final List<String> riskReasons;
  final DateTime lastReported;
  final int reportCount;
  final String? country;
  final String? carrier;
  final bool isSpam;
  final bool isScam;
  final bool isRobo;
  
  SuspiciousNumber({
    required this.phoneNumber,
    required this.riskLevel,
    required this.riskReasons,
    required this.lastReported,
    required this.reportCount,
    this.country,
    this.carrier,
    this.isSpam = false,
    this.isScam = false,
    this.isRobo = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'phoneNumber': phoneNumber,
      'riskLevel': riskLevel,
      'riskReasons': riskReasons,
      'lastReported': lastReported.toIso8601String(),
      'reportCount': reportCount,
      'country': country,
      'carrier': carrier,
      'isSpam': isSpam,
      'isScam': isScam,
      'isRobo': isRobo,
    };
  }
  
  factory SuspiciousNumber.fromJson(Map<String, dynamic> json) {
    return SuspiciousNumber(
      phoneNumber: json['phoneNumber'],
      riskLevel: json['riskLevel'],
      riskReasons: List<String>.from(json['riskReasons']),
      lastReported: DateTime.parse(json['lastReported']),
      reportCount: json['reportCount'],
      country: json['country'],
      carrier: json['carrier'],
      isSpam: json['isSpam'] ?? false,
      isScam: json['isScam'] ?? false,
      isRobo: json['isRobo'] ?? false,
    );
  }
}

class FraudScore {
  final String identifier; // phone number, IP, or email
  final String type; // 'phone', 'ip', 'email'
  final double score; // 0.0 - 1.0 (higher is more fraudulent)
  final String confidence; // low, medium, high
  final List<String> indicators;
  final DateTime checkedAt;
  final String? source; // AbuseIPDB, FraudScore API, etc.
  
  FraudScore({
    required this.identifier,
    required this.type,
    required this.score,
    required this.confidence,
    required this.indicators,
    required this.checkedAt,
    this.source,
  });
  
  bool get isHighRisk => score > 0.7;
  bool get isMediumRisk => score > 0.4 && score <= 0.7;
  bool get isLowRisk => score <= 0.4;
  
  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'type': type,
      'score': score,
      'confidence': confidence,
      'indicators': indicators,
      'checkedAt': checkedAt.toIso8601String(),
      'source': source,
    };
  }
  
  factory FraudScore.fromJson(Map<String, dynamic> json) {
    return FraudScore(
      identifier: json['identifier'],
      type: json['type'],
      score: json['score'].toDouble(),
      confidence: json['confidence'],
      indicators: List<String>.from(json['indicators']),
      checkedAt: DateTime.parse(json['checkedAt']),
      source: json['source'],
    );
  }
}

class DeviceMetadata {
  final String deviceId;
  final String deviceModel;
  final String osVersion;
  final String appVersion;
  final String? networkOperator;
  final String? networkCountry;
  final String? simOperator;
  final String? simCountry;
  final bool isRooted;
  final bool isDeveloperMode;
  final List<String> installedApps;
  final DateTime collectedAt;
  
  DeviceMetadata({
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
    this.networkOperator,
    this.networkCountry,
    this.simOperator,
    this.simCountry,
    this.isRooted = false,
    this.isDeveloperMode = false,
    this.installedApps = const [],
    required this.collectedAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'networkOperator': networkOperator,
      'networkCountry': networkCountry,
      'simOperator': simOperator,
      'simCountry': simCountry,
      'isRooted': isRooted,
      'isDeveloperMode': isDeveloperMode,
      'installedApps': installedApps,
      'collectedAt': collectedAt.toIso8601String(),
    };
  }
  
  factory DeviceMetadata.fromJson(Map<String, dynamic> json) {
    return DeviceMetadata(
      deviceId: json['deviceId'],
      deviceModel: json['deviceModel'],
      osVersion: json['osVersion'],
      appVersion: json['appVersion'],
      networkOperator: json['networkOperator'],
      networkCountry: json['networkCountry'],
      simOperator: json['simOperator'],
      simCountry: json['simCountry'],
      isRooted: json['isRooted'] ?? false,
      isDeveloperMode: json['isDeveloperMode'] ?? false,
      installedApps: List<String>.from(json['installedApps'] ?? []),
      collectedAt: DateTime.parse(json['collectedAt']),
    );
  }
}

class SMSAnalysisResult {
  final String messageId;
  final String sender;
  final String content;
  final DateTime receivedAt;
  final double riskScore; // 0.0 - 1.0
  final List<String> riskIndicators;
  final List<String> detectedLinks;
  final List<String> suspiciousPatterns;
  final bool isPhishing;
  final bool isSmishing; // SMS phishing
  final bool isSpam;
  final bool containsMaliciousLink;
  
  SMSAnalysisResult({
    required this.messageId,
    required this.sender,
    required this.content,
    required this.receivedAt,
    required this.riskScore,
    required this.riskIndicators,
    required this.detectedLinks,
    required this.suspiciousPatterns,
    this.isPhishing = false,
    this.isSmishing = false,
    this.isSpam = false,
    this.containsMaliciousLink = false,
  });
  
  bool get isHighRisk => riskScore > 0.7;
  bool get shouldBlock => isPhishing || isSmishing || containsMaliciousLink;
  
  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'sender': sender,
      'content': content,
      'receivedAt': receivedAt.toIso8601String(),
      'riskScore': riskScore,
      'riskIndicators': riskIndicators,
      'detectedLinks': detectedLinks,
      'suspiciousPatterns': suspiciousPatterns,
      'isPhishing': isPhishing,
      'isSmishing': isSmishing,
      'isSpam': isSpam,
      'containsMaliciousLink': containsMaliciousLink,
    };
  }
  
  factory SMSAnalysisResult.fromJson(Map<String, dynamic> json) {
    return SMSAnalysisResult(
      messageId: json['messageId'],
      sender: json['sender'],
      content: json['content'],
      receivedAt: DateTime.parse(json['receivedAt']),
      riskScore: json['riskScore'].toDouble(),
      riskIndicators: List<String>.from(json['riskIndicators']),
      detectedLinks: List<String>.from(json['detectedLinks']),
      suspiciousPatterns: List<String>.from(json['suspiciousPatterns']),
      isPhishing: json['isPhishing'] ?? false,
      isSmishing: json['isSmishing'] ?? false,
      isSpam: json['isSpam'] ?? false,
      containsMaliciousLink: json['containsMaliciousLink'] ?? false,
    );
  }
}

class FraudAlert {
  final String id;
  final String type; // 'call', 'sms', 'app', 'network'
  final String severity; // 'low', 'medium', 'high', 'critical'
  final String title;
  final String description;
  final String? phoneNumber;
  final String? ipAddress;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isRead;
  final bool isActionTaken;
  
  FraudAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.phoneNumber,
    this.ipAddress,
    this.metadata = const {},
    required this.createdAt,
    this.isRead = false,
    this.isActionTaken = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'phoneNumber': phoneNumber,
      'ipAddress': ipAddress,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'isActionTaken': isActionTaken,
    };
  }
  
  factory FraudAlert.fromJson(Map<String, dynamic> json) {
    return FraudAlert(
      id: json['id'],
      type: json['type'],
      severity: json['severity'],
      title: json['title'],
      description: json['description'],
      phoneNumber: json['phoneNumber'],
      ipAddress: json['ipAddress'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
      isActionTaken: json['isActionTaken'] ?? false,
    );
  }
}

class FraudProtectionSettings {
  final bool autoBlockSpam;
  final bool autoBlockScam;
  final bool autoBlockRobo;
  final bool enableSMSFiltering;
  final bool enablePhishingProtection;
  final bool enableRealtimeScanning;
  final double riskThreshold; // 0.0 - 1.0
  final List<String> trustedNumbers;
  final List<String> blockedNumbers;
  final bool notifyOnSuspiciousActivity;
  final bool shareAnonymousData;
  
  FraudProtectionSettings({
    this.autoBlockSpam = true,
    this.autoBlockScam = true,
    this.autoBlockRobo = true,
    this.enableSMSFiltering = true,
    this.enablePhishingProtection = true,
    this.enableRealtimeScanning = true,
    this.riskThreshold = 0.6,
    this.trustedNumbers = const [],
    this.blockedNumbers = const [],
    this.notifyOnSuspiciousActivity = true,
    this.shareAnonymousData = false,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'autoBlockSpam': autoBlockSpam,
      'autoBlockScam': autoBlockScam,
      'autoBlockRobo': autoBlockRobo,
      'enableSMSFiltering': enableSMSFiltering,
      'enablePhishingProtection': enablePhishingProtection,
      'enableRealtimeScanning': enableRealtimeScanning,
      'riskThreshold': riskThreshold,
      'trustedNumbers': trustedNumbers,
      'blockedNumbers': blockedNumbers,
      'notifyOnSuspiciousActivity': notifyOnSuspiciousActivity,
      'shareAnonymousData': shareAnonymousData,
    };
  }
  
  factory FraudProtectionSettings.fromJson(Map<String, dynamic> json) {
    return FraudProtectionSettings(
      autoBlockSpam: json['autoBlockSpam'] ?? true,
      autoBlockScam: json['autoBlockScam'] ?? true,
      autoBlockRobo: json['autoBlockRobo'] ?? true,
      enableSMSFiltering: json['enableSMSFiltering'] ?? true,
      enablePhishingProtection: json['enablePhishingProtection'] ?? true,
      enableRealtimeScanning: json['enableRealtimeScanning'] ?? true,
      riskThreshold: json['riskThreshold']?.toDouble() ?? 0.6,
      trustedNumbers: List<String>.from(json['trustedNumbers'] ?? []),
      blockedNumbers: List<String>.from(json['blockedNumbers'] ?? []),
      notifyOnSuspiciousActivity: json['notifyOnSuspiciousActivity'] ?? true,
      shareAnonymousData: json['shareAnonymousData'] ?? false,
    );
  }
  
  FraudProtectionSettings copyWith({
    bool? autoBlockSpam,
    bool? autoBlockScam,
    bool? autoBlockRobo,
    bool? enableSMSFiltering,
    bool? enablePhishingProtection,
    bool? enableRealtimeScanning,
    double? riskThreshold,
    List<String>? trustedNumbers,
    List<String>? blockedNumbers,
    bool? notifyOnSuspiciousActivity,
    bool? shareAnonymousData,
  }) {
    return FraudProtectionSettings(
      autoBlockSpam: autoBlockSpam ?? this.autoBlockSpam,
      autoBlockScam: autoBlockScam ?? this.autoBlockScam,
      autoBlockRobo: autoBlockRobo ?? this.autoBlockRobo,
      enableSMSFiltering: enableSMSFiltering ?? this.enableSMSFiltering,
      enablePhishingProtection: enablePhishingProtection ?? this.enablePhishingProtection,
      enableRealtimeScanning: enableRealtimeScanning ?? this.enableRealtimeScanning,
      riskThreshold: riskThreshold ?? this.riskThreshold,
      trustedNumbers: trustedNumbers ?? this.trustedNumbers,
      blockedNumbers: blockedNumbers ?? this.blockedNumbers,
      notifyOnSuspiciousActivity: notifyOnSuspiciousActivity ?? this.notifyOnSuspiciousActivity,
      shareAnonymousData: shareAnonymousData ?? this.shareAnonymousData,
    );
  }
}