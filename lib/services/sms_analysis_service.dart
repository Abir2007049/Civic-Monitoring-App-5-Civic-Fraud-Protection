import '../models/models.dart';

class SMSAnalysisService {
  static final _url = RegExp(r'(https?:\/\/|www\.)[\w\-]+(\.[\w\-]+)+\S*', caseSensitive: false);
  static final _urgent = RegExp(r'(urgent|immediately|now|action required)', caseSensitive: false);
  static final _money = RegExp(r'(won|lottery|prize|reward|refund|cash|jackpot)', caseSensitive: false);
  static final _cred = RegExp(r'(otp|password|pin|cvv|account|bank)', caseSensitive: false);
  static final _shorteners = RegExp(r'(bit\.ly|tinyurl\.com|goo\.gl|t\.co)', caseSensitive: false);

  Future<SMSAnalysisResult> analyze(String text) async {
    final t = text.trim();
    int score = 0;
    final reasons = <String>[];

    final hasLink = _url.hasMatch(t);
    final hasUrgency = _urgent.hasMatch(t);
    final hasMoney = _money.hasMatch(t);
    final hasCred = _cred.hasMatch(t);
    final hasShort = _shorteners.hasMatch(t);

    if (hasLink) {
      score += 25;
      reasons.add('contains_link');
    }
    if (hasShort) {
      score += 20;
      reasons.add('url_shortener');
    }
    if (hasUrgency) {
      score += 20;
      reasons.add('urgency_language');
    }
    if (hasMoney) {
      score += 15;
      reasons.add('money_or_prize');
    }
    if (hasCred) {
      score += 15;
      reasons.add('credentials_request');
    }
    if (t.length < 10) {
      score += 5;
      reasons.add('very_short');
    }

    score = score.clamp(0, 100);
    return SMSAnalysisResult(
      riskScore: score,
      reasons: reasons,
      containsLink: hasLink,
      hasUrgency: hasUrgency,
      hasMoneyOrPrize: hasMoney,
    );
  }
}
