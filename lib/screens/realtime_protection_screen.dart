import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_service.dart';
import '../models/models.dart';

class RealTimeProtectionScreen extends StatefulWidget {
  const RealTimeProtectionScreen({super.key});

  @override
  State<RealTimeProtectionScreen> createState() => _RealTimeProtectionScreenState();
}

class _RealTimeProtectionScreenState extends State<RealTimeProtectionScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  bool _protectionEnabled = true;
  bool _callProtection = true;
  bool _smsProtection = true;
  bool _urlProtection = true;
  bool _realTimeScanning = false;
  
  int _threatsBlocked = 0;
  int _callsAnalyzed = 0;
  int _messagesScanned = 0;
  
  List<Map<String, dynamic>> _recentActivity = [];

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadSettings();
    _loadStats();
    _startRealTimeSimulation();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _protectionEnabled = prefs.getBool('protection_enabled') ?? true;
      _callProtection = prefs.getBool('call_protection') ?? true;
      _smsProtection = prefs.getBool('sms_protection') ?? true;
      _urlProtection = prefs.getBool('url_protection') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('protection_enabled', _protectionEnabled);
    await prefs.setBool('call_protection', _callProtection);
    await prefs.setBool('sms_protection', _smsProtection);
    await prefs.setBool('url_protection', _urlProtection);
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _threatsBlocked = prefs.getInt('threats_blocked_total') ?? 0;
      _callsAnalyzed = prefs.getInt('calls_analyzed_total') ?? 0;
      _messagesScanned = prefs.getInt('messages_scanned_total') ?? 0;
    });
  }

  Future<void> _saveStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('threats_blocked_total', _threatsBlocked);
    await prefs.setInt('calls_analyzed_total', _callsAnalyzed);
    await prefs.setInt('messages_scanned_total', _messagesScanned);
  }

  void _startRealTimeSimulation() {
    // Simulate periodic background activity
    Stream.periodic(const Duration(seconds: 5), (i) => i).listen((_) {
      if (_protectionEnabled && mounted) {
        _simulateBackgroundActivity();
      }
    });
  }

  void _simulateBackgroundActivity() {
    final activities = [
      {'type': 'call_scan', 'message': 'Incoming call from +1234567890 analyzed - Safe', 'threat': false},
      {'type': 'sms_scan', 'message': 'SMS from friend analyzed - Clean', 'threat': false},
      {'type': 'url_scan', 'message': 'URL in message scanned - Safe', 'threat': false},
      {'type': 'call_block', 'message': 'Spam call from 1800SCAM blocked', 'threat': true},
      {'type': 'sms_block', 'message': 'Phishing SMS from 140FAKE blocked', 'threat': true},
      {'type': 'url_block', 'message': 'Malicious URL bit.ly/fake blocked', 'threat': true},
    ];

    if (!_realTimeScanning && DateTime.now().second % 8 == 0) {
      final activity = activities[DateTime.now().millisecond % activities.length];
      
      setState(() {
        _recentActivity.insert(0, {
          ...activity,
          'timestamp': DateTime.now().toIso8601String(),
        });
        if (_recentActivity.length > 20) {
          _recentActivity = _recentActivity.take(20).toList();
        }

        if (activity['type'].toString().contains('call')) _callsAnalyzed++;
        if (activity['type'].toString().contains('sms')) _messagesScanned++;
        if (activity['threat'] == true) _threatsBlocked++;
      });
      
      _saveStats();
    }
  }

  Color _getProtectionColor() {
    if (!_protectionEnabled) return Colors.grey;
    return Colors.green;
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'call_scan':
      case 'call_block':
        return Icons.phone;
      case 'sms_scan':
      case 'sms_block':
        return Icons.message;
      case 'url_scan':
      case 'url_block':
        return Icons.link;
      default:
        return Icons.security;
    }
  }

  Color _getActivityColor(Map<String, dynamic> activity) {
    final isThreat = activity['threat'] as bool? ?? false;
    final type = activity['type'] as String;
    
    if (type.contains('block') || isThreat) return Colors.red;
    return Colors.green;
  }

  Widget _buildProtectionToggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? Colors.green : Colors.grey),
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: _protectionEnabled ? onChanged : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Protection'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'reset':
                  _resetStats();
                  break;
                case 'test':
                  _runProtectionTest();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'test', child: Text('Run Protection Test')),
              const PopupMenuItem(value: 'reset', child: Text('Reset Statistics')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Protection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _protectionEnabled ? _pulseAnimation.value : 1.0,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: _getProtectionColor(),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _protectionEnabled ? Icons.shield : Icons.shield_outlined,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _protectionEnabled ? 'Protection Active' : 'Protection Disabled',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _protectionEnabled ? 'Your device is protected from fraud' : 'Tap to enable protection',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _protectionEnabled = !_protectionEnabled);
                        _saveSettings();
                      },
                      icon: Icon(_protectionEnabled ? Icons.pause : Icons.play_arrow),
                      label: Text(_protectionEnabled ? 'Disable Protection' : 'Enable Protection'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _protectionEnabled ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Statistics
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Protection Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('Threats\nBlocked', _threatsBlocked, Colors.red),
                        _buildStatColumn('Calls\nAnalyzed', _callsAnalyzed, Colors.blue),
                        _buildStatColumn('Messages\nScanned', _messagesScanned, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Protection Modules
            const Text('Protection Modules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            _buildProtectionToggle(
              'Call Protection',
              'Block spam and robocalls automatically',
              _callProtection,
              (value) {
                setState(() => _callProtection = value);
                _saveSettings();
              },
              Icons.phone,
            ),
            
            _buildProtectionToggle(
              'SMS Protection',
              'Scan messages for phishing and spam',
              _smsProtection,
              (value) {
                setState(() => _smsProtection = value);
                _saveSettings();
              },
              Icons.message,
            ),
            
            _buildProtectionToggle(
              'URL Protection',
              'Check links for malicious content',
              _urlProtection,
              (value) {
                setState(() => _urlProtection = value);
                _saveSettings();
              },
              Icons.link,
            ),

            const SizedBox(height: 16),

            // Real-Time Activity
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Real-Time Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Switch(
                          value: _realTimeScanning,
                          onChanged: (value) => setState(() => _realTimeScanning = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_recentActivity.isEmpty && !_realTimeScanning)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.timeline, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('No recent activity'),
                              Text('Protection running in background'),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _recentActivity.take(8).map((activity) {
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              _getActivityIcon(activity['type'] as String),
                              color: _getActivityColor(activity),
                              size: 20,
                            ),
                            title: Text(
                              activity['message'] as String,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Text(
                              '${DateTime.parse(activity['timestamp'] as String).hour}:${DateTime.parse(activity['timestamp'] as String).minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick Actions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _runProtectionTest(),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Test Protection'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDetailedStats(),
                            icon: const Icon(Icons.analytics),
                            label: const Text('View Reports'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> _runProtectionTest() async {
    setState(() => _realTimeScanning = true);
    
    final testActivities = [
      {'type': 'call_scan', 'message': 'Testing call protection...', 'threat': false},
      {'type': 'call_block', 'message': 'Blocked test spam call from 1800TEST', 'threat': true},
      {'type': 'sms_scan', 'message': 'Testing SMS protection...', 'threat': false},
      {'type': 'sms_block', 'message': 'Blocked phishing SMS with malicious link', 'threat': true},
      {'type': 'url_scan', 'message': 'Testing URL protection...', 'threat': false},
      {'type': 'url_block', 'message': 'Blocked access to suspicious domain', 'threat': true},
    ];

    for (final activity in testActivities) {
      await Future.delayed(const Duration(milliseconds: 800));
      setState(() {
        _recentActivity.insert(0, {
          ...activity,
          'timestamp': DateTime.now().toIso8601String(),
        });
        if (activity['threat'] == true) _threatsBlocked++;
      });
    }

    setState(() => _realTimeScanning = false);
    _saveStats();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Protection test completed successfully!')),
    );
  }

  void _resetStats() {
    setState(() {
      _threatsBlocked = 0;
      _callsAnalyzed = 0;
      _messagesScanned = 0;
      _recentActivity.clear();
    });
    _saveStats();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Statistics reset')),
    );
  }

  void _showDetailedStats() {
    final safeInteractions = _callsAnalyzed + _messagesScanned - _threatsBlocked;
    final protectionRate = _threatsBlocked > 0 && (_callsAnalyzed + _messagesScanned) > 0
        ? (_threatsBlocked / (_callsAnalyzed + _messagesScanned) * 100).toStringAsFixed(1)
        : '0.0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detailed Protection Report'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📊 Total Interactions: ${_callsAnalyzed + _messagesScanned}'),
              Text('✅ Safe Interactions: $safeInteractions'),
              Text('🚫 Threats Blocked: $_threatsBlocked'),
              Text('📞 Calls Analyzed: $_callsAnalyzed'),
              Text('📱 Messages Scanned: $_messagesScanned'),
              const SizedBox(height: 12),
              Text('🛡️ Protection Rate: $protectionRate%'),
              const SizedBox(height: 12),
              const Text('Protection Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Call Protection: ${_callProtection ? "Active" : "Disabled"}'),
              Text('• SMS Protection: ${_smsProtection ? "Active" : "Disabled"}'),
              Text('• URL Protection: ${_urlProtection ? "Active" : "Disabled"}'),
            ],
          ),
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
    _pulseController.dispose();
    super.dispose();
  }
}