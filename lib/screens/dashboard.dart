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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
    final _numberCtrl = TextEditingController();
    final _smsCtrl = TextEditingController();
    final ReputationService _rep = ReputationService();
    final SMSAnalysisService _sms = SMSAnalysisService();
    List<FraudAlert> _alerts = [];
  SuspiciousNumber? _lastNumber;
    SMSAnalysisResult? _lastSMS;

    @override
    void initState() {
      super.initState();
      _loadAlerts();
    }

    Future<void> _loadAlerts() async {
      final alerts = await AppDatabase.instance.getAlerts();
      setState(() {
        _alerts = alerts.reversed.toList();
      });
    }

    Color _levelColor(RiskLevel level) {
      switch (level) {
        case RiskLevel.high:
          return Colors.red;
        case RiskLevel.medium:
          return Colors.orange;
        case RiskLevel.low:
        default:
          return Colors.blue;
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Civic Fraud Protection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              Text(
                'Dashboard',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.shield),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const BlocklistScreen()));
              },
              tooltip: 'Blocklist',
            ),
            IconButton(
              icon: const Icon(Icons.import_export),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
              },
              tooltip: 'Export/Import',
            ),
            IconButton(
              icon: const Icon(Icons.security),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreatIntelligenceScreen()));
              },
              tooltip: 'Threat Intelligence',
            ),
            IconButton(
              icon: const Icon(Icons.sms),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageSpamScreen()));
              },
              tooltip: 'SMS Spam',
            ),
            IconButton(
              icon: const Icon(Icons.phone),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSpamScreen()));
              },
              tooltip: 'Call Spam',
            ),
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RealTimeProtectionScreen()));
              },
              tooltip: 'Real-Time Protection',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number Reputation Card
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
                                  message: 'Checked \\${res.number} -> score \\${res.riskScore}',
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
                                  reason: 'High risk score: \\${_lastNumber!.riskScore}',
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added \\${_lastNumber!.number} to blocklist')),
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
                            Text('Risk: \\${_lastNumber!.riskScore} (\\${_lastNumber!.level.name})'),
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
              // SMS Analysis Card
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
                            message: 'SMS risk \\${res.riskScore}',
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
                            Text('Risk: \\${_lastSMS!.riskScore} (\\${_lastSMS!.level.name})'),
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
              // Recent Alerts Card
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
