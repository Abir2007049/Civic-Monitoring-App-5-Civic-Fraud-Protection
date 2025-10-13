import 'package:flutter/material.dart';
import '../services/threat_intelligence_service.dart';

class ThreatIntelligenceScreen extends StatefulWidget {
  const ThreatIntelligenceScreen({super.key});

  @override
  State<ThreatIntelligenceScreen> createState() => _ThreatIntelligenceScreenState();
}

class _ThreatIntelligenceScreenState extends State<ThreatIntelligenceScreen> {
  final _numberController = TextEditingController();
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _service = ThreatIntelligenceService();
  
  Map<String, dynamic>? _numberResult;
  Map<String, dynamic>? _urlResult;
  bool _checkingNumber = false;
  bool _checkingUrl = false;

  Future<void> _checkNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) return;

    setState(() {
      _checkingNumber = true;
      _numberResult = null;
    });

    try {
      final result = await _service.checkNumberWithAPI(
        number,
        apiKey: _apiKeyController.text.trim().isNotEmpty ? _apiKeyController.text.trim() : null,
      );
      setState(() => _numberResult = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking number: $e')),
      );
    } finally {
      setState(() => _checkingNumber = false);
    }
  }

  Future<void> _checkUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _checkingUrl = true;
      _urlResult = null;
    });

    try {
      final result = await _service.checkURLWithAPI(
        url,
        apiKey: _apiKeyController.text.trim().isNotEmpty ? _apiKeyController.text.trim() : null,
      );
      setState(() => _urlResult = result);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking URL: $e')),
      );
    } finally {
      setState(() => _checkingUrl = false);
    }
  }

  Color _getRiskColor(int riskScore) {
    if (riskScore >= 70) return Colors.red;
    if (riskScore >= 40) return Colors.orange;
    return Colors.green;
  }

  Widget _buildResultCard(String title, Map<String, dynamic>? result, IconData icon) {
    if (result == null) return const SizedBox.shrink();

    final riskScore = result['risk_score'] as int? ?? 0;
    final categories = result['categories'] as List<dynamic>? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getRiskColor(riskScore),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Risk Score: $riskScore/100'),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: categories
                    .map((cat) => Chip(
                          label: Text(cat.toString()),
                          backgroundColor: _getRiskColor(riskScore).withOpacity(0.2),
                        ))
                    .toList(),
              ),
            ],
            if (result['sources'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Sources: ${(result['sources'] as List).join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (result['report_count'] != null && result['report_count'] > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Reported ${result['report_count']} times',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (result['last_reported'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last reported: ${DateTime.parse(result['last_reported']).toString().split('.')[0]}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Intelligence'),
        actions: [
          IconButton(
            onPressed: () {
              _service.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear Cache',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Key Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('API Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'API Key (optional)',
                        helperText: 'Leave empty for demo mode',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Number Intelligence
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Number Intelligence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _numberController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _checkingNumber ? null : _checkNumber,
                      icon: _checkingNumber 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(_checkingNumber ? 'Checking...' : 'Check Number'),
                    ),
                  ],
                ),
              ),
            ),

            _buildResultCard('Number Analysis', _numberResult, Icons.phone),

            const SizedBox(height: 12),

            // URL Intelligence
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('URL Intelligence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _checkingUrl ? null : _checkUrl,
                      icon: _checkingUrl 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link),
                      label: Text(_checkingUrl ? 'Checking...' : 'Check URL'),
                    ),
                  ],
                ),
              ),
            ),

            _buildResultCard('URL Analysis', _urlResult, Icons.link),

            const SizedBox(height: 12),

            // Cache Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'Cache Size: ${_service.getCacheSize()} entries\n\n'
                      'This screen demonstrates cloud-based threat intelligence. '
                      'In demo mode, responses are generated locally based on patterns. '
                      'With a real API key, it would query actual threat databases.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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

  @override
  void dispose() {
    _numberController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
}