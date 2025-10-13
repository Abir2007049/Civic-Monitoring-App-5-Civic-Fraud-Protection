import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/reputation_service.dart';
import '../services/sms_analysis_service.dart';
import '../services/db_service.dart';
import 'blocklist_screen.dart';
import 'export_screen.dart';
import 'threat_intelligence_screen.dart';
import 'message_spam_screen.dart';
import 'call_spam_screen.dart';
import 'realtime_protection_screen.dart';
import 'api_configuration_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _numberCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();

  final _rep = ReputationService();
  final _sms = SMSAnalysisService();
  SuspiciousNumber? _lastNumber;
  SMSAnalysisResult? _lastSMS;
  List<FraudAlert> _alerts = const [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final items = await AppDatabase.instance.getAlerts();
    setState(() => _alerts = items);
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _smsCtrl.dispose();
    super.dispose();
  }

  Color _levelColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.high:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Protection Dashboard'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'blocklist':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BlocklistScreen()),
                  );
                  break;
                case 'export':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExportScreen()),
                  );
                  break;
                case 'intelligence':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ThreatIntelligenceScreen()),
                  );
                  break;
                case 'message_spam':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MessageSpamScreen()),
                  );
                  break;
                case 'call_spam':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CallSpamScreen()),
                  );
                  break;
                case 'realtime':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RealTimeProtectionScreen()),
                  );
                  break;
                case 'api_config':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ApiConfigurationScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'blocklist',
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('Blocked Numbers'),
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('Data Management'),
                ),
              ),
              const PopupMenuItem(
                value: 'intelligence',
                child: ListTile(
                  leading: Icon(Icons.cloud_sync),
                  title: Text('Threat Intelligence'),
                ),
              ),
              const PopupMenuItem(
                value: 'message_spam',
                child: ListTile(
                  leading: Icon(Icons.message),
                  title: Text('Message Spam Detection'),
                ),
              ),
              const PopupMenuItem(
                value: 'call_spam',
                child: ListTile(
                  leading: Icon(Icons.phone),
                  title: Text('Call Spam Protection'),
                ),
              ),
              const PopupMenuItem(
                value: 'realtime',
                child: ListTile(
                  leading: Icon(Icons.shield),
                  title: Text('Real-Time Protection'),
                ),
              ),
              const PopupMenuItem(
                value: 'api_config',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('API Configuration'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    const Text('Check Number Reputation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _numberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final res = await _rep.checkNumber(_numberCtrl.text);
                              setState(() => _lastNumber = res);
                              await AppDatabase.instance.addAlert(FraudAlert(
                                type: 'number',
                                message: 'Checked ${res.number} -> score ${res.riskScore}',
                                severity: res.level.name,
                                timestamp: DateTime.now(),
                              ));
                              _loadAlerts();
                            },
                            child: const Text('Analyze Number'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_lastNumber != null && _lastNumber!.riskScore >= 40)
                          ElevatedButton.icon(
                            onPressed: () async {
                              await AppDatabase.instance.addBlocked(
                                _lastNumber!.number,
                                reason: 'High risk score: ${_lastNumber!.riskScore}',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added ${_lastNumber!.number} to blocklist')),
                              );
                            },
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text('Block'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          ),
                      ],
                    ),
                    if (_lastNumber != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _levelColor(_lastNumber!.level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Risk: ${_lastNumber!.riskScore} (${_lastNumber!.level.name})'),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        children: _lastNumber!.tags
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analyze SMS Text', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _smsCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Paste SMS content here',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final res = await _sms.analyze(_smsCtrl.text);
                        setState(() => _lastSMS = res);
                        await AppDatabase.instance.addAlert(FraudAlert(
                          type: 'sms',
                          message: 'SMS risk ${res.riskScore}',
                          severity: res.level.name,
                          timestamp: DateTime.now(),
                        ));
                        _loadAlerts();
                      },
                      child: const Text('Analyze SMS'),
                    ),
                    if (_lastSMS != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _levelColor(_lastSMS!.level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Risk: ${_lastSMS!.riskScore} (${_lastSMS!.level.name})'),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        children: _lastSMS!.reasons
                            .map((t) => Chip(label: Text(t)))
                            .toList(),
                      ),
                    ]
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_alerts.isEmpty)
                      const Text('No alerts yet')
                    else
                      ..._alerts.take(10).map((a) => ListTile(
                            leading: Icon(
                              a.severity == 'high'
                                  ? Icons.error
                                  : a.severity == 'medium'
                                      ? Icons.warning
                                      : Icons.info,
                              color: a.severity == 'high'
                                  ? Colors.red
                                  : a.severity == 'medium'
                                      ? Colors.orange
                                      : Colors.blue,
                            ),
                            title: Text(a.message),
                            subtitle: Text('${a.type} • ${a.timestamp}'),
                          )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
