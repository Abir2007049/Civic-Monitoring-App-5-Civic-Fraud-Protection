import 'package:call_log/call_log.dart';
import 'package:telephony/telephony.dart';

enum PackageDuration { days7, days15, days30 }

class UsageStats {
  final int outgoingCallMinutes;
  final int outgoingCallCount;
  final int sentSmsCount;
  final double estimatedDataGB;
  final DateTime periodStart;
  final DateTime periodEnd;

  UsageStats({
    required this.outgoingCallMinutes,
    required this.outgoingCallCount,
    required this.sentSmsCount,
    required this.estimatedDataGB,
    required this.periodStart,
    required this.periodEnd,
  });

  int get daysInPeriod => periodEnd.difference(periodStart).inDays + 1;
}

class PackageRecommendation {
  final String name;
  final int dataGB;
  final int callMinutes;
  final int smsCount;
  final PackageDuration duration;
  final double estimatedPrice;
  final String description;
  final bool recommended;

  PackageRecommendation({
    required this.name,
    required this.dataGB,
    required this.callMinutes,
    required this.smsCount,
    required this.duration,
    required this.estimatedPrice,
    required this.description,
    this.recommended = false,
  });

  String get durationLabel {
    switch (duration) {
      case PackageDuration.days7:
        return '7 Days';
      case PackageDuration.days15:
        return '15 Days';
      case PackageDuration.days30:
        return '30 Days';
    }
  }

  int get durationDays {
    switch (duration) {
      case PackageDuration.days7:
        return 7;
      case PackageDuration.days15:
        return 15;
      case PackageDuration.days30:
        return 30;
    }
  }
}

class TelecomAnalysisService {
  /// Analyze call logs and SMS for the last [days] period
  Future<UsageStats> analyzeUsage(int days) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    final cutoffMs = cutoff.millisecondsSinceEpoch;

    // Analyze call logs
    final callLogs = await CallLog.get();
    int outgoingMinutes = 0;
    int outgoingCount = 0;

    for (final entry in callLogs) {
      if (entry.timestamp != null && entry.timestamp! >= cutoffMs) {
        // CallType.outgoing is typically 2
        if (entry.callType == CallType.outgoing) {
          outgoingCount++;
          if (entry.duration != null) {
            outgoingMinutes += (entry.duration! / 60).ceil();
          }
        }
      }
    }

    // Analyze sent SMS
    final telephony = Telephony.instance;
    final sentSms = await telephony.getSentSms(
      columns: [SmsColumn.DATE],
    );
    final sentCount = sentSms.where((sms) {
      if (sms.date == null) return false;
      final msgDate = DateTime.fromMillisecondsSinceEpoch(sms.date!);
      return msgDate.isAfter(cutoff);
    }).length;

    // Estimate data usage (rough heuristic: 1GB per week for average user)
    // You could enhance this by reading actual data usage if available
    final estimatedDataGB = (days / 7.0) * 1.0;

    return UsageStats(
      outgoingCallMinutes: outgoingMinutes,
      outgoingCallCount: outgoingCount,
      sentSmsCount: sentCount,
      estimatedDataGB: estimatedDataGB,
      periodStart: cutoff,
      periodEnd: now,
    );
  }

  /// Generate package recommendations based on usage stats
  List<PackageRecommendation> recommendPackages(UsageStats stats) {
    // Project usage for different package durations
    final dailyMinutes = stats.outgoingCallMinutes / stats.daysInPeriod;
    final dailySms = stats.sentSmsCount / stats.daysInPeriod;
    final dailyData = stats.estimatedDataGB / stats.daysInPeriod;

    final packages = <PackageRecommendation>[];

    // 7-day packages
    final mins7 = (dailyMinutes * 7 * 1.2).ceil(); // 20% buffer
    final sms7 = (dailySms * 7 * 1.2).ceil();
    final data7 = (dailyData * 7 * 1.2).ceil();
    packages.add(PackageRecommendation(
      name: 'Weekly Starter',
      dataGB: _roundData(data7),
      callMinutes: _roundMinutes(mins7),
      smsCount: _roundSms(sms7),
      duration: PackageDuration.days7,
      estimatedPrice: _estimatePrice(_roundData(data7), _roundMinutes(mins7), _roundSms(sms7), 7),
      description: 'Perfect for short-term needs',
    ));

    // 15-day packages
    final mins15 = (dailyMinutes * 15 * 1.15).ceil();
    final sms15 = (dailySms * 15 * 1.15).ceil();
    final data15 = (dailyData * 15 * 1.15).ceil();
    packages.add(PackageRecommendation(
      name: 'Bi-Weekly Plus',
      dataGB: _roundData(data15),
      callMinutes: _roundMinutes(mins15),
      smsCount: _roundSms(sms15),
      duration: PackageDuration.days15,
      estimatedPrice: _estimatePrice(_roundData(data15), _roundMinutes(mins15), _roundSms(sms15), 15),
      description: 'Great value for moderate users',
      recommended: true, // Mark as recommended
    ));

    // 30-day packages
    final mins30 = (dailyMinutes * 30 * 1.1).ceil();
    final sms30 = (dailySms * 30 * 1.1).ceil();
    final data30 = (dailyData * 30 * 1.1).ceil();
    packages.add(PackageRecommendation(
      name: 'Monthly Premium',
      dataGB: _roundData(data30),
      callMinutes: _roundMinutes(mins30),
      smsCount: _roundSms(sms30),
      duration: PackageDuration.days30,
      estimatedPrice: _estimatePrice(_roundData(data30), _roundMinutes(mins30), _roundSms(sms30), 30),
      description: 'Best value for regular users',
    ));

    // Add a light user option if usage is very low
    if (stats.outgoingCallMinutes < 30 && stats.sentSmsCount < 50) {
      packages.insert(
        0,
        PackageRecommendation(
          name: 'Light User',
          dataGB: 1,
          callMinutes: 50,
          smsCount: 100,
          duration: PackageDuration.days7,
          estimatedPrice: 49.0,
          description: 'Minimal usage package',
        ),
      );
    }

    // Add unlimited package for heavy users
    if (stats.outgoingCallMinutes > 500 || stats.estimatedDataGB > 10) {
      packages.add(PackageRecommendation(
        name: 'Unlimited Pro',
        dataGB: 999, // Represent unlimited
        callMinutes: 9999,
        smsCount: 9999,
        duration: PackageDuration.days30,
        estimatedPrice: 999.0,
        description: 'Unlimited calls, SMS & data',
        recommended: stats.outgoingCallMinutes > 1000,
      ));
    }

    return packages;
  }

  int _roundData(int gb) {
    if (gb < 1) return 1;
    if (gb < 3) return 2;
    if (gb < 5) return 3;
    if (gb < 7) return 5;
    if (gb < 12) return 10;
    if (gb < 20) return 15;
    return 20;
  }

  int _roundMinutes(int mins) {
    if (mins < 30) return 30;
    if (mins < 50) return 50;
    if (mins < 100) return 100;
    if (mins < 200) return 200;
    if (mins < 300) return 300;
    if (mins < 500) return 500;
    if (mins < 1000) return 1000;
    return 2000;
  }

  int _roundSms(int sms) {
    if (sms < 50) return 50;
    if (sms < 100) return 100;
    if (sms < 200) return 200;
    if (sms < 500) return 500;
    return 1000;
  }

  double _estimatePrice(int dataGB, int mins, int sms, int days) {
    // Simple pricing model (you can adjust based on local rates)
    double base = 0;
    base += dataGB * 15.0; // 15 per GB
    base += (mins / 100) * 10.0; // 10 per 100 mins
    base += (sms / 100) * 5.0; // 5 per 100 SMS

    // Duration discount
    if (days >= 30) {
      base *= 0.85; // 15% discount for monthly
    } else if (days >= 15) {
      base *= 0.90; // 10% discount for bi-weekly
    }

    return (base / 10).ceil() * 10.0; // Round to nearest 10
  }

  /// Get usage prediction for next period
  Map<String, dynamic> predictNextPeriod(UsageStats stats, int targetDays) {
    final dailyMinutes = stats.outgoingCallMinutes / stats.daysInPeriod;
    final dailySms = stats.sentSmsCount / stats.daysInPeriod;
    final dailyData = stats.estimatedDataGB / stats.daysInPeriod;

    return {
      'minutes': (dailyMinutes * targetDays).ceil(),
      'sms': (dailySms * targetDays).ceil(),
      'data_gb': (dailyData * targetDays),
      'days': targetDays,
    };
  }
}
