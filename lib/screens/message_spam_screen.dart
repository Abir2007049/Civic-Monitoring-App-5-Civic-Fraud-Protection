import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sms_analysis_service.dart';
import '../services/reputation_service.dart';
import '../services/db_service.dart';
import '../models/models.dart';

class MessageSpamScreen extends StatefulWidget {
  const MessageSpamScreen({super.key});

  @override
  State<MessageSpamScreen> createState() => _MessageSpamScreenState();
}

class _MessageSpamScreenState extends State<MessageSpamScreen> {
  final _messageController = TextEditingController();
  final _smsService = SMSAnalysisService();
  final _repService = ReputationService();
  
  List<Map<String, dynamic>> _recentMessages = [];
  bool _autoScanEnabled = true;
  bool _blockHighRisk = false;
  bool _analyzing = false;
  
  SMSAnalysisResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadRecentMessages();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoScanEnabled = prefs.getBool('auto_scan_messages') ?? true;
      _blockHighRisk = prefs.getBool('block_high_risk_senders') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_scan_messages', _autoScanEnabled);
    await prefs.setBool('block_high_risk_senders', _blockHighRisk);
  }

  Future<void> _loadRecentMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString('recent_messages') ?? '[]';
    final messages = jsonDecode(messagesJson) as List<dynamic>;
    setState(() {
      _recentMessages = messages.cast<Map<String, dynamic>>();
    });
  }

  Future<void> _saveRecentMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('recent_messages', jsonEncode(_recentMessages));
  }

  Future<void> _analyzeMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _analyzing = true);

    try {
      final result = await _smsService.analyze(message);
      setState(() => _lastResult = result);

      // Add to recent messages
      final messageData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': message.length > 50 ? '${message.substring(0, 50)}...' : message,
        'full_content': message,
        'risk_score': result.riskScore,
        'level': result.level.name,
        'reasons': result.reasons,
        'timestamp': DateTime.now().toIso8601String(),
        'sender': 'Manual Analysis',
      };

      _recentMessages.insert(0, messageData);
      if (_recentMessages.length > 50) {
        _recentMessages = _recentMessages.take(50).toList();
      }
      await _saveRecentMessages();

      // Log alert
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'message_spam',
        message: 'Message spam analysis: ${result.riskScore}/100 risk',
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

  Future<void> _simulateIncomingMessage(String sender, String content) async {
    final result = await _smsService.analyze(content);
    final senderRep = await _repService.checkNumber(sender);

    final messageData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'content': content.length > 50 ? '${content.substring(0, 50)}...' : content,
      'full_content': content,
      'risk_score': result.riskScore,
      'level': result.level.name,
      'reasons': result.reasons,
      'timestamp': DateTime.now().toIso8601String(),
      'sender': sender,
      'sender_risk': senderRep.riskScore,
      'auto_processed': true,
    };

    // Auto-block if enabled and high risk
    if (_blockHighRisk && (result.riskScore >= 70 || senderRep.riskScore >= 70)) {
      messageData['blocked'] = true;
      await AppDatabase.instance.addBlocked(sender, reason: 'Auto-blocked: High spam risk');
      
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'auto_block',
        message: 'Auto-blocked $sender (Message: ${result.riskScore}, Sender: ${senderRep.riskScore})',
        severity: 'high',
        timestamp: DateTime.now(),
      ));
    }

    setState(() {
      _recentMessages.insert(0, messageData);
      if (_recentMessages.length > 50) {
        _recentMessages = _recentMessages.take(50).toList();
      }
    });
    await _saveRecentMessages();
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      default: return Colors.green;
    }
  }

  Widget _buildMessageTile(Map<String, dynamic> message) {
    final riskScore = message['risk_score'] as int;
    final level = message['level'] as String;
    final blocked = message['blocked'] as bool? ?? false;
    final autoProcessed = message['auto_processed'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              blocked ? Icons.block : Icons.message,
              color: blocked ? Colors.red : _getRiskColor(level),
            ),
            if (autoProcessed) const Icon(Icons.auto_awesome, size: 12),
          ],
        ),
        title: Text(
          message['content'] as String,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${message['sender']}'),
            Text('Risk: $riskScore/100 ($level)'),
            if (message['reasons'] != null && (message['reasons'] as List).isNotEmpty)
              Wrap(
                spacing: 4,
                children: (message['reasons'] as List<dynamic>)
                    .take(3)
                    .map((r) => Chip(
                          label: Text(r.toString(), style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
          ],
        ),
        trailing: blocked
            ? const Icon(Icons.block, color: Colors.red)
            : Text('${DateTime.parse(message['timestamp'] as String).hour}:${DateTime.parse(message['timestamp'] as String).minute.toString().padLeft(2, '0')}'),
        onTap: () => _showMessageDetails(message),
      ),
    );
  }

  void _showMessageDetails(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Message Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('From: ${message['sender']}'),
              const SizedBox(height: 8),
              Text('Risk Score: ${message['risk_score']}/100 (${message['level']})'),
              const SizedBox(height: 8),
              const Text('Full Message:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(message['full_content'] as String),
              const SizedBox(height: 8),
              if (message['reasons'] != null && (message['reasons'] as List).isNotEmpty) ...[
                const Text('Risk Factors:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...(message['reasons'] as List<dynamic>).map((r) => Text('• $r')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!(message['blocked'] as bool? ?? false))
            ElevatedButton(
              onPressed: () async {
                await AppDatabase.instance.addBlocked(
                  message['sender'] as String,
                  reason: 'Manually blocked from message analysis',
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Blocked ${message['sender']}')),
                );
              },
              child: const Text('Block Sender'),
            ),
        ],
      ),
    );
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
              'Fraud Detection',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Message Spam',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'demo':
                  _showDemoDialog();
                  break;
                case 'clear':
                  _clearRecentMessages();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'demo', child: Text('Run Demo')),
              const PopupMenuItem(value: 'clear', child: Text('Clear History')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Settings Card
                  Card(
                    margin: const EdgeInsets.all(16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.settings, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Protection Settings',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-scan messages'),
                            subtitle: const Text('Automatically analyze incoming messages', style: TextStyle(fontSize: 12)),
                            value: _autoScanEnabled,
                            onChanged: (value) {
                              setState(() => _autoScanEnabled = value);
                              _saveSettings();
                            },
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto-block high-risk senders'),
                            subtitle: const Text('Automatically block senders with ≥70% risk', style: TextStyle(fontSize: 12)),
                            value: _blockHighRisk,
                            onChanged: (value) {
                              setState(() => _blockHighRisk = value);
                              _saveSettings();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Manual Analysis
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Manual Message Analysis',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _messageController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Paste message content',
                              hintText: 'Enter or paste SMS content here...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _analyzing ? null : _analyzeMessage,
                              icon: _analyzing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.analytics),
                              label: Text(_analyzing ? 'Analyzing...' : 'Analyze Message'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          if (_lastResult != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getRiskColor(_lastResult!.level.name).withOpacity(0.1),
                                border: Border.all(color: _getRiskColor(_lastResult!.level.name), width: 2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _lastResult!.level.name == 'high' ? Icons.error : 
                                        _lastResult!.level.name == 'medium' ? Icons.warning : Icons.info,
                                        color: _getRiskColor(_lastResult!.level.name),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Risk: ${_lastResult!.riskScore}/100 (${_lastResult!.level.name.toUpperCase()})',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _getRiskColor(_lastResult!.level.name),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_lastResult!.reasons.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: _lastResult!.reasons.map((r) => Chip(
                                        label: Text(r, style: const TextStyle(fontSize: 11)),
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      )).toList(),
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

                  // Recent Messages Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: Theme.of(context).primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Messages (${_recentMessages.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Recent Messages List
            _recentMessages.isEmpty
                ? const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.message_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No messages analyzed yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          SizedBox(height: 4),
                          Text('Use manual analysis or run demo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMessageTile(_recentMessages[index]),
                        childCount: _recentMessages.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showDemoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Run Demo Messages'),
        content: const Text('This will simulate receiving various types of messages to demonstrate spam detection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _runDemo();
            },
            child: const Text('Run Demo'),
          ),
        ],
      ),
    );
  }

  Future<void> _runDemo() async {
    final demoMessages = [
      {'sender': '+1234567890', 'content': 'Hello! How are you today?'},
      {'sender': '+1800SCAM99', 'content': 'URGENT! You have won \$50,000! Click http://bit.ly/fake-prize to claim now!'},
      {'sender': '140123456', 'content': 'Your bank account has been compromised. Please verify your OTP 123456 immediately.'},
      {'sender': '+9876543210', 'content': 'Meeting at 3 PM today. See you there!'},
      {'sender': '0000000', 'content': 'Congratulations! You are our lucky winner. Send us your bank details to claim your lottery prize of \$100,000'},
      {'sender': '+1555444333', 'content': 'Happy birthday! Hope you have a great day.'},
    ];

    for (int i = 0; i < demoMessages.length; i++) {
      await _simulateIncomingMessage(
        demoMessages[i]['sender']!,
        demoMessages[i]['content']!,
      );
      await Future.delayed(const Duration(milliseconds: 500));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Demo completed! Check the message history.')),
    );
  }

  void _clearRecentMessages() {
    setState(() => _recentMessages.clear());
    _saveRecentMessages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message history cleared')),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}