import 'dart:math';

import '../models/models.dart';
import 'db_service.dart';

class ReputationService {
  static final _digitsOnly = RegExp(r'^\+?[0-9]{6,15}$');

  Future<SuspiciousNumber> checkNumber(String input) async {
    final number = input.trim();
    final now = DateTime.now();
    final tags = <String>[];
    int score = 0;

    // Basic format validation
    if (!_digitsOnly.hasMatch(number)) {
      score += 25;
      tags.add('invalid_format');
    }

    // Repeated patterns
    if (_hasRepeats(number)) {
      score += 20;
      tags.add('repeating_digits');
    }

    // Sequential digits
    if (_hasSequential(number)) {
      score += 15;
      tags.add('sequential_digits');
    }

    // Toll-free or marketing-like prefixes (heuristic)
    if (number.startsWith('1800') || number.startsWith('800') || number.startsWith('140')) {
      score += 10;
      tags.add('tollfree_like');
    }

    // If in local blocklist, mark high
    final blocked = await AppDatabase.instance.getBlocked();
    if (blocked.any((b) => (b['number'] as String).replaceAll(' ', '') == number)) {
      score = max(score, 85);
      tags.add('locally_blocked');
    }

    score = score.clamp(0, 100);
    return SuspiciousNumber(number: number, riskScore: score, tags: tags, lastChecked: now);
  }

  bool _hasRepeats(String s) {
    if (s.length < 4) return false;
    final ch = s[0];
    return s.split('').every((c) => c == ch);
  }

  bool _hasSequential(String s) {
    const seq = '01234567890';
    for (int i = 0; i < s.length - 3; i++) {
      final sub = s.substring(i, i + 4);
      if (seq.contains(sub)) return true;
    }
    return false;
  }
}
