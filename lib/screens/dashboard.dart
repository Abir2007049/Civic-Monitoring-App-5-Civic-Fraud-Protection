import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/reputation_service.dart';
import '../services/sms_analysis_service.dart';
import '../services/db_service.dart';
import 'package_recommendation_screen.dart';
import 'blocklist_screen.dart';
import 'export_screen.dart';
import 'threat_intelligence_screen.dart';
import 'message_spam_screen.dart';
import 'call_spam_screen.dart';
import 'realtime_protection_screen.dart';
import 'health_risk_screen.dart';

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
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Civic Fraud Protection',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Color(0xFF006400),
                ),
              ),
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF006400),
                ),
              ),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'blocklist':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BlocklistScreen()));
                    break;
                  case 'export':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen()));
                    break;
                  case 'threat_intel':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ThreatIntelligenceScreen()));
                    break;
                  case 'sms_spam':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MessageSpamScreen()));
                    break;
                  case 'call_spam':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallSpamScreen()));
                    break;
                  case 'realtime':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RealTimeProtectionScreen()));
                    break;
                  case 'health_risk':
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthRiskScreen()));
                    break;
                  case 'package_recommendations':
                    Navigator.pushNamed(context, '/package_recommendations');
                    break;
                  case 'device_data':
                    Navigator.pushNamed(context, '/device_data');
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'blocklist',
                  child: Row(
                    children: [
                      Icon(Icons.shield),
                      SizedBox(width: 12),
                      Text('Blocklist'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.import_export),
                      SizedBox(width: 12),
                      Text('Export/Import'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'threat_intel',
                  child: Row(
                    children: [
                      Icon(Icons.security),
                      SizedBox(width: 12),
                      Text('Threat Intelligence'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'package_recommendations',
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard, color: Colors.purple),
                      SizedBox(width: 12),
                      Text('Package Recommendations'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sms_spam',
                  child: Row(
                    children: [
                      Icon(Icons.sms),
                      SizedBox(width: 12),
                      Text('SMS Spam Detection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'call_spam',
                  child: Row(
                    children: [
                      Icon(Icons.phone),
                      SizedBox(width: 12),
                      Text('Call Spam Protection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'realtime',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on),
                      SizedBox(width: 12),
                      Text('Real-Time Protection'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'health_risk',
                  child: Row(
                    children: [
                      Icon(Icons.health_and_safety, color: Colors.teal),
                      SizedBox(width: 12),
                      Text('Health Risk Monitor'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'device_data',
                  child: Row(
                    children: [
                      Icon(Icons.devices),
                      SizedBox(width: 12),
                      Text('Device Data'),
                    ],
                  ),
                ),
              ],
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
              // Health Risk Monitor Quick Access Card
              Card(
                elevation: 2,
                color: Colors.teal.shade50,
                child: InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthRiskScreen()));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.health_and_safety,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Health Risk Monitor',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Detect health risks in messages and alerts',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '🏥 Disease outbreaks • 💧 Contamination • ⚠️ Medical emergencies',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                      ],
                    ),
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
