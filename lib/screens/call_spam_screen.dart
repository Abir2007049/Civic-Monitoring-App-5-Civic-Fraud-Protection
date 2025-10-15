import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:call_log/call_log.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/reputation_service.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../models/models.dart';

class CallSpamScreen extends StatefulWidget {
  const CallSpamScreen({super.key});

  @override
  State<CallSpamScreen> createState() => _CallSpamScreenState();
}

class _CallSpamScreenState extends State<CallSpamScreen> {
  final _numberController = TextEditingController();
  final _repService = ReputationService();
  
  List<Map<String, dynamic>> _recentCalls = [];
  bool _autoBlockEnabled = false;
  bool _showSpamCallsOnly = false;
  bool _analyzing = false;
  int _spamCallsBlocked = 0;
  
  SuspiciousNumber? _lastAnalysis;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadRecentCalls();
    _loadStats();
    _requestPermissionsAndLoadDeviceCalls();
    NotificationService().init(context);
  }

  Future<void> _requestPermissionsAndLoadDeviceCalls() async {
    final status = await Permission.phone.request();
    if (status.isGranted) {
      await _loadDeviceCallLogs();
    }
  }

  Future<void> _loadDeviceCallLogs() async {
    try {
      final Iterable<CallLogEntry> entries = await CallLog.get();
      final List<Map<String, dynamic>> deviceCalls = [];
      
      for (final entry in entries.take(50)) {
        // Analyze each call for spam
        final number = entry.number ?? 'Unknown';
        if (number == 'Unknown' || number.isEmpty) continue;
        
        // Check reputation
        final result = await _repService.checkNumber(number);

        // If number is blocked in app, show notification
        final blockedNumbers = await AppDatabase.instance.getBlocked();
        if (blockedNumbers.any((b) => b['number'] == number)) {
          await NotificationService().showNotification(
            title: 'Blocked Number Detected',
            body: 'Blocked number $number tried to call you.',
          );
        }
        
        final callData = {
          'id': entry.timestamp.toString(),
          'number': number,
          'name': entry.name ?? 'Unknown',
          'risk_score': result.riskScore,
          'level': result.level.name,
          'tags': result.tags,
          'timestamp': DateTime.fromMillisecondsSinceEpoch(entry.timestamp!).toIso8601String(),
          'type': _getCallTypeName(entry.callType),
          'duration': entry.duration ?? 0,
          'blocked': result.riskScore >= 60,
        };
        
        deviceCalls.add(callData);
        
        // Auto-block high-risk calls
        if (_autoBlockEnabled && result.riskScore >= 60) {
          setState(() => _spamCallsBlocked++);
          await _saveStats();
        }
      }
      
      setState(() {
        _recentCalls = deviceCalls;
      });
      await _saveRecentCalls();
    } catch (e) {
      print('Error loading device call logs: $e');
    }
  }

  String _getCallTypeName(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.rejected:
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoBlockEnabled = prefs.getBool('auto_block_calls') ?? false;
      _showSpamCallsOnly = prefs.getBool('show_spam_calls_only') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_block_calls', _autoBlockEnabled);
    await prefs.setBool('show_spam_calls_only', _showSpamCallsOnly);
  }

  Future<void> _loadRecentCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final callsJson = prefs.getString('recent_calls') ?? '[]';
    final calls = jsonDecode(callsJson) as List<dynamic>;
    setState(() {
      _recentCalls = calls.cast<Map<String, dynamic>>();
    });
  }

  Future<void> _saveRecentCalls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_calls', jsonEncode(_recentCalls));
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _spamCallsBlocked = prefs.getInt('spam_calls_blocked') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('spam_calls_blocked', _spamCallsBlocked);
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Remove any non-digit characters except + from phone number
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  Future<void> _analyzeNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;

    setState(() => _analyzing = true);

    try {
      final result = await _repService.checkNumber(number);
      setState(() => _lastAnalysis = result);

      // Add to call log
      final callData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'number': number,
        'risk_score': result.riskScore,
        'level': result.level.name,
        'tags': result.tags,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'manual_check',
        'duration': 0,
        'blocked': false,
      };

      _recentCalls.insert(0, callData);
      if (_recentCalls.length > 100) {
        _recentCalls = _recentCalls.take(100).toList();
      }
      await _saveRecentCalls();

      // Log alert
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'call_analysis',
        message: 'Number analysis: $number -> ${result.riskScore}/100 risk',
        severity: result.level.name,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    } finally {
      setState(() => _analyzing = false);
    }
  }

  Future<void> _simulateIncomingCall(String number, {int duration = 0, bool isSpam = false}) async {
    final result = await _repService.checkNumber(number);
    
    // Determine if call should be blocked
    bool blocked = false;
    String callType = 'incoming';
    
    if (_autoBlockEnabled && (result.riskScore >= 60 || isSpam)) {
      blocked = true;
      callType = 'blocked';
      setState(() => _spamCallsBlocked++);
      await _saveStats();
      
      await AppDatabase.instance.addBlocked(number, reason: 'Auto-blocked spam call');
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'call_blocked',
        message: 'Auto-blocked call from $number (Risk: ${result.riskScore}/100)',
        severity: result.riskScore >= 80 ? 'high' : 'medium',
        timestamp: DateTime.now(),
      ));
    }

    final callData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'number': number,
      'risk_score': result.riskScore,
      'level': result.level.name,
      'tags': result.tags,
      'timestamp': DateTime.now().toIso8601String(),
      'type': callType,
      'duration': duration,
      'blocked': blocked,
      'is_spam': isSpam || result.riskScore >= 70,
    };

    setState(() {
      _recentCalls.insert(0, callData);
      if (_recentCalls.length > 100) {
        _recentCalls = _recentCalls.take(100).toList();
      }
    });
    await _saveRecentCalls();
  }

  List<Map<String, dynamic>> get _filteredCalls {
    if (_showSpamCallsOnly) {
      return _recentCalls.where((call) => 
        call['is_spam'] == true || 
        call['blocked'] == true || 
        (call['risk_score'] as int) >= 60
      ).toList();
    }
    return _recentCalls;
  }

  Color _getCallTypeColor(Map<String, dynamic> call) {
    if (call['blocked'] == true) return Colors.red;
    if (call['is_spam'] == true) return Colors.orange;
    final riskScore = call['risk_score'] as int;
    if (riskScore >= 70) return Colors.red;
    if (riskScore >= 40) return Colors.orange;
    return Colors.green;
  }

  IconData _getCallIcon(Map<String, dynamic> call) {
    if (call['blocked'] == true) return Icons.block;
    if (call['type'] == 'manual_check') return Icons.search;
    return Icons.phone;
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return 'N/A';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  Widget _buildCallTile(Map<String, dynamic> call) {
    final riskScore = call['risk_score'] as int;
    final level = call['level'] as String;
    final blocked = call['blocked'] as bool? ?? false;
    final isSpam = call['is_spam'] as bool? ?? false;
    final duration = call['duration'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
      child: ListTile(
        leading: Icon(
          _getCallIcon(call),
          color: _getCallTypeColor(call),
        ),
        title: Text(call['number'] as String),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk: $riskScore/100 ($level) • ${_formatDuration(duration)}'),
            if (call['tags'] != null && (call['tags'] as List).isNotEmpty)
              Wrap(
                spacing: 4,
                children: (call['tags'] as List<dynamic>)
                    .take(2)
                    .map((tag) => Chip(
                          label: Text(tag.toString(), style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (blocked) const Icon(Icons.block, color: Colors.red, size: 20),
            if (isSpam && !blocked) const Icon(Icons.warning, color: Colors.orange, size: 20),
            Text(
              '${DateTime.parse(call['timestamp'] as String).hour}:${DateTime.parse(call['timestamp'] as String).minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        onTap: () => _showCallDetails(call),
      ),
    );
  }

  void _showCallDetails(Map<String, dynamic> call) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Details'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Number: ${call['number']}'),
            const SizedBox(height: 8),
            Text('Risk Score: ${call['risk_score']}/100 (${call['level']})'),
            Text('Duration: ${_formatDuration(call['duration'] as int? ?? 0)}'),
            Text('Type: ${call['type']}'),
            Text('Time: ${DateTime.parse(call['timestamp'] as String).toString().split('.')[0]}'),
            const SizedBox(height: 8),
            if (call['tags'] != null && (call['tags'] as List).isNotEmpty) ...[
              const Text('Risk Factors:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(call['tags'] as List<dynamic>).map((tag) => Text('• $tag')),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if ((call['risk_score'] as int? ?? 0) < 70)
            ElevatedButton.icon(
              icon: const Icon(Icons.phone),
              onPressed: () {
                Navigator.pop(context);
                _makePhoneCall(call['number'] as String);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              label: const Text('Call'),
            ),
          if (!(call['blocked'] as bool? ?? false))
            ElevatedButton(
              onPressed: () async {
                await AppDatabase.instance.addBlocked(
                  call['number'] as String,
                  reason: 'Manually blocked from call log',
                );
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Blocked ${call['number']}')),
                  );
                }
              },
              child: const Text('Block Number'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Call Spam Protection',
          style: TextStyle(
            color: Color(0xFF006400),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceCallLogs,
            tooltip: 'Refresh Device Calls',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'demo':
                  _runCallDemo();
                  break;
                case 'clear':
                  _clearCallHistory();
                  break;
                case 'stats':
                  _showStatsDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'demo', child: Text('Run Demo Calls')),
              const PopupMenuItem(value: 'stats', child: Text('View Statistics')),
              const PopupMenuItem(value: 'clear', child: Text('Clear History')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$_spamCallsBlocked',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const Text('Spam Calls\nBlocked', textAlign: TextAlign.center),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_recentCalls.length}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const Text('Total Calls\nAnalyzed', textAlign: TextAlign.center),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        '${_recentCalls.where((c) => (c['risk_score'] as int) >= 60).length}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const Text('High Risk\nCalls', textAlign: TextAlign.center),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Settings Card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Call Protection Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  SwitchListTile(
                    title: const Text('Auto-block spam calls'),
                    subtitle: const Text('Automatically block calls with ≥60% risk'),
                    value: _autoBlockEnabled,
                    onChanged: (value) {
                      setState(() => _autoBlockEnabled = value);
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show spam calls only'),
                    subtitle: const Text('Filter call history to show only suspicious calls'),
                    value: _showSpamCallsOnly,
                    onChanged: (value) {
                      setState(() => _showSpamCallsOnly = value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Manual Analysis
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Check Number', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numberController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _analyzing ? null : _analyzeNumber,
                        icon: _analyzing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.search),
                        label: const Text('Check'),
                      ),
                    ],
                  ),
                  if (_lastAnalysis != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_lastAnalysis!.riskScore >= 70 ? Colors.red : _lastAnalysis!.riskScore >= 40 ? Colors.orange : Colors.green).withOpacity(0.1),
                        border: Border.all(color: _lastAnalysis!.riskScore >= 70 ? Colors.red : _lastAnalysis!.riskScore >= 40 ? Colors.orange : Colors.green),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Risk: ${_lastAnalysis!.riskScore}/100 (${_lastAnalysis!.level.name})'),
                          if (_lastAnalysis!.tags.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: _lastAnalysis!.tags.map((tag) => Chip(label: Text(tag))).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Call History
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Call History (${_filteredCalls.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _filteredCalls.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showSpamCallsOnly ? Icons.block : Icons.phone_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(_showSpamCallsOnly ? 'No spam calls detected' : 'No calls in history'),
                              const Text('Use check number or run demo'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredCalls.length,
                          itemBuilder: (context, index) => _buildCallTile(_filteredCalls[index]),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runCallDemo() async {
    final demoCalls = [
      {'number': '+1234567890', 'duration': 45, 'isSpam': false},
      {'number': '1800SPAM99', 'duration': 0, 'isSpam': true},
      {'number': '140123456', 'duration': 0, 'isSpam': true},
      {'number': '+9876543210', 'duration': 120, 'isSpam': false},
      {'number': '0000000', 'duration': 0, 'isSpam': true},
      {'number': '+1555444333', 'duration': 30, 'isSpam': false},
      {'number': '999888777', 'duration': 0, 'isSpam': true},
    ];

    for (final call in demoCalls) {
      await _simulateIncomingCall(
        call['number'] as String,
        duration: call['duration'] as int,
        isSpam: call['isSpam'] as bool,
      );
      await Future.delayed(const Duration(milliseconds: 300));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo calls completed!')),
    );
  }

  void _clearCallHistory() {
    setState(() => _recentCalls.clear());
    _saveRecentCalls();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call history cleared')),
    );
  }

  void _showStatsDialog() {
    final totalCalls = _recentCalls.length;
    final blockedCalls = _recentCalls.where((c) => c['blocked'] == true).length;
    final spamCalls = _recentCalls.where((c) => c['is_spam'] == true || (c['risk_score'] as int) >= 70).length;
    final safeCalls = totalCalls - spamCalls;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Protection Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Calls Analyzed: $totalCalls'),
            Text('Spam Calls Detected: $spamCalls'),
            Text('Calls Auto-Blocked: $blockedCalls'),
            Text('Safe Calls: $safeCalls'),
            const SizedBox(height: 16),
            if (totalCalls > 0)
              Text('Protection Rate: ${((blockedCalls / spamCalls * 100).clamp(0, 100)).toStringAsFixed(1)}%'),
          ],
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

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }
}