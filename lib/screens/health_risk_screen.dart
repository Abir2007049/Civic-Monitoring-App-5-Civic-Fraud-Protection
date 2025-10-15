import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import '../models/models.dart';
import '../services/health_risk_service.dart';
import '../services/db_service.dart';

class HealthRiskScreen extends StatefulWidget {
  const HealthRiskScreen({super.key});

  @override
  State<HealthRiskScreen> createState() => _HealthRiskScreenState();
}

class _HealthRiskScreenState extends State<HealthRiskScreen> {
  final HealthRiskService _healthService = HealthRiskService();
  final TextEditingController _textController = TextEditingController();
  HealthRiskResult? _lastAnalysis;
  HealthRiskStats? _stats;
  bool _isAnalyzing = false;
  List<FraudAlert> _healthAlerts = [];
  bool _scanInbox = true;
  bool _scanSent = true;
  bool _loadingSMS = false;
  final List<Map<String, dynamic>> _scannedMessages = [];
  bool _alertsOnly = true; // show only Medium/High by default

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _healthService.getStats();
    final alerts = await AppDatabase.instance.getAlerts();
      final healthAlerts = alerts.where((a) => a.type == 'health').toList();
    
    setState(() {
      _stats = stats;
      _healthAlerts = healthAlerts;
    });
  }

  Future<void> _scanDeviceMessages() async {
    setState(() => _loadingSMS = true);
    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission is required to scan messages')),
          );
        }
        setState(() => _loadingSMS = false);
        return;
      }

      final Telephony telephony = Telephony.instance;
      final List<Map<String, dynamic>> results = [];

      Future<void> processList(List<SmsMessage> list, String box) async {
        for (final sms in list.take(100)) {
          if (sms.body == null || sms.body!.isEmpty) continue;
          final analysis = await _healthService.analyzeText(sms.body!);
          // Always collect; we'll filter at render time if needed
          results.add({
            'box': box,
            'address': sms.address ?? (box == 'sent' ? 'Sent' : 'Unknown'),
            'body': sms.body!,
            'timestamp': sms.date != null ? DateTime.fromMillisecondsSinceEpoch(sms.date!).toIso8601String() : DateTime.now().toIso8601String(),
            'risk': analysis.riskLevel.name,
            'summary': analysis.message,
          });
        }
      }

      if (_scanInbox) {
        final inbox = await telephony.getInboxSms(columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE]);
        await processList(inbox, 'inbox');
      }
      if (_scanSent) {
        try {
          final sent = await telephony.getSentSms(columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE]);
          await processList(sent, 'sent');
        } catch (_) {
          // sent box may not be available; ignore
        }
      }

      results.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
      setState(() {
        _scannedMessages
          ..clear()
          ..addAll(results);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to scan messages: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingSMS = false);
    }
  }

  Future<void> _runHealthDemo() async {
    // Create 5 demo messages across categories with mixed inbox/sent
    final demos = [
      {
        'box': 'inbox',
        'address': '+8801712345678',
        'body': 'There\'s an outbreak of dengue in our area. Many people have high fever and severe headache. Hospital is full.',
        'minutesAgo': 2,
      },
      {
        'box': 'inbox',
        'address': 'Water Board',
        'body': 'Water contamination alert: several cases of diarrhea and vomiting after drinking tap water. Boil water before use.',
        'minutesAgo': 10,
      },
      {
        'box': 'sent',
        'address': '+8801999888777',
        'body': 'Gas leak near the old factory causing breathing problems and chest pain. Stay indoors and avoid the area.',
        'minutesAgo': 18,
      },
      {
        'box': 'inbox',
        'address': '+8801555666777',
        'body': 'Severe accident reported: multiple people injured and bleeding heavily, ambulance delay expected.',
        'minutesAgo': 25,
      },
      {
        'box': 'sent',
        'address': 'School Admin',
        'body': 'School closed due to mass illness; many students have cough and mild fever. Monitor symptoms at home.',
        'minutesAgo': 35,
      },
    ];

    final List<Map<String, dynamic>> results = [];
    for (final d in demos) {
      final text = d['body'] as String;
      final analysis = await _healthService.analyzeText(text);
      final ts = DateTime.now().subtract(Duration(minutes: d['minutesAgo'] as int)).toIso8601String();
      results.add({
        'box': d['box'],
        'address': d['address'],
        'body': text,
        'timestamp': ts,
        'risk': analysis.riskLevel.name,
        'summary': analysis.message,
      });
    }

    results.sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    setState(() {
      _scannedMessages
        ..clear()
        ..addAll(results);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loaded 5 demo health messages')),
      );
    }
  }

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to analyze')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await _healthService.analyzeText(_textController.text);
      setState(() {
        _lastAnalysis = result;
        _isAnalyzing = false;
      });

      // Reload data to show new alerts if any
      await _loadData();

      // Show notification if high risk
      if (result.riskLevel == RiskLevel.high) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('⚠️ HIGH HEALTH RISK DETECTED!'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Colors.red;
      case RiskLevel.medium:
        return Colors.orange;
      case RiskLevel.low:
        return Colors.blue;
    }
  }

  IconData _getRiskIcon(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Icons.warning_amber;
      case RiskLevel.medium:
        return Icons.info_outline;
      case RiskLevel.low:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Risk Monitor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Community Health Alert System',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Statistics Card
          if (_stats != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Health Alerts Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Total',
                        _stats!.totalAlerts.toString(),
                        Icons.assessment,
                        Colors.white,
                      ),
                      _buildStatItem(
                        'High',
                        _stats!.highRiskCount.toString(),
                        Icons.warning,
                        Colors.red.shade300,
                      ),
                      _buildStatItem(
                        'Medium',
                        _stats!.mediumRiskCount.toString(),
                        Icons.info,
                        Colors.orange.shade300,
                      ),
                      _buildStatItem(
                        'Low',
                        _stats!.lowRiskCount.toString(),
                        Icons.check,
                        Colors.green.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Analysis Input Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SMS Scan Controls
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sms, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('Scan SMS for Health Risks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Scan Inbox'),
                                  value: _scanInbox,
                                  onChanged: (v) => setState(() => _scanInbox = v),
                                ),
                              ),
                              Expanded(
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Scan Sent'),
                                  value: _scanSent,
                                  onChanged: (v) => setState(() => _scanSent = v),
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Only health alerts (MED/HIGH)'),
                            subtitle: const Text('Turn off to show all scanned messages'),
                            value: _alertsOnly,
                            onChanged: (v) => setState(() => _alertsOnly = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _loadingSMS ? null : _scanDeviceMessages,
                                  icon: _loadingSMS
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.search),
                                  label: Text(_loadingSMS ? 'Scanning...' : 'Scan Messages'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _runHealthDemo,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Run Demo'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Input Card
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.health_and_safety, color: Colors.teal),
                              SizedBox(width: 8),
                              Text(
                                'Analyze Text for Health Risks',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _textController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Enter text message, social media post, or any text to analyze...\n\nExample: "Many people in our area are experiencing high fever and breathing problems"',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isAnalyzing ? null : _analyzeText,
                              icon: _isAnalyzing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search),
                              label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Text'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Analysis Result
                  if (_lastAnalysis != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      color: _getRiskColor(_lastAnalysis!.riskLevel).withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _getRiskIcon(_lastAnalysis!.riskLevel),
                                  color: _getRiskColor(_lastAnalysis!.riskLevel),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Risk Level: ${_lastAnalysis!.riskLevel.name.toUpperCase()}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _getRiskColor(_lastAnalysis!.riskLevel),
                                        ),
                                      ),
                                      Text(
                                        'Confidence: ${(_lastAnalysis!.confidence * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              _lastAnalysis!.message,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            if (_lastAnalysis!.categories.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Detected Categories:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _lastAnalysis!.categories.map((cat) {
                                  return Chip(
                                    label: Text(
                                      cat.replaceAll('_', ' ').toUpperCase(),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    backgroundColor: _getRiskColor(_lastAnalysis!.riskLevel).withOpacity(0.2),
                                    side: BorderSide.none,
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                  );
                                }).toList(),
                              ),
                            ],

                            if (_lastAnalysis!.detectedKeywords.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Detected Keywords:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _lastAnalysis!.detectedKeywords.take(10).join(', '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],

                            if (_lastAnalysis!.recommendations.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Recommendations:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ..._lastAnalysis!.recommendations.map((rec) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.arrow_right, size: 20),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          rec,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Recent Alerts
                  if (_healthAlerts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Recent Health Alerts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._healthAlerts.take(5).map((alert) {
                        // Convert severity string to RiskLevel enum
                        final riskLevel = alert.severity == 'high' 
                            ? RiskLevel.high 
                            : alert.severity == 'medium' 
                                ? RiskLevel.medium 
                                : RiskLevel.low;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                              _getRiskIcon(riskLevel),
                              color: _getRiskColor(riskLevel),
                          ),
                          title: Text(
                            alert.message,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                              '${alert.timestamp.toString().split('.')[0]}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(
                                alert.severity.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                              backgroundColor: _getRiskColor(riskLevel).withOpacity(0.2),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  // SMS Scan Results
                  if (_scannedMessages.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Health-Related Messages',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...(_alertsOnly
                            ? _scannedMessages.where((m) => (m['risk'] == 'medium' || m['risk'] == 'high'))
                            : _scannedMessages)
                        .map((m) {
                      final color = m['risk'] == 'high' ? Colors.red : Colors.orange;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(m['box'] == 'sent' ? Icons.outbox : Icons.inbox, color: Colors.teal),
                          title: Text(
                            (m['body'] as String).length > 80 ? '${(m['body'] as String).substring(0,80)}...' : (m['body'] as String),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m['box'] == 'sent' ? 'Me →' : 'From:'} ${m['address']}'),
                              Text(m['summary'], style: TextStyle(color: m['risk'] == 'low' ? Colors.blue : color)),
                            ],
                          ),
                          trailing: Chip(
                            label: Text((m['risk'] as String).toUpperCase(), style: const TextStyle(fontSize: 10)),
                            backgroundColor: (m['risk'] == 'low' ? Colors.blue : color).withOpacity(0.15),
                            side: BorderSide.none,
                          ),
                        ),
                      );
                    }).toList(),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text('No messages matched. Tip: toggle off "Only health alerts" to see all scanned messages.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
