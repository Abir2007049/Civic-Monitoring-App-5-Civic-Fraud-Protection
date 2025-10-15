import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/telecom_analysis_service.dart';

class PackageRecommendationScreen extends StatefulWidget {
  const PackageRecommendationScreen({Key? key}) : super(key: key);

  @override
  State<PackageRecommendationScreen> createState() => _PackageRecommendationScreenState();
}

class _PackageRecommendationScreenState extends State<PackageRecommendationScreen> {
  final TelecomAnalysisService _analysisService = TelecomAnalysisService();
  UsageStats? _currentUsage;
  List<PackageRecommendation> _recommendations = [];
  bool _loading = false;
  int _analysisDays = 30;

  @override
  void initState() {
    super.initState();
    _analyzeUsage();
  }

  Future<void> _analyzeUsage() async {
    setState(() => _loading = true);

    // Request permissions
    await [Permission.phone, Permission.sms].request();

    try {
      final usage = await _analysisService.analyzeUsage(_analysisDays);
      final packages = _analysisService.recommendPackages(usage);

      setState(() {
        _currentUsage = usage;
        _recommendations = packages;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing usage: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Package Recommendations',
          style: TextStyle(
            color: Color(0xFF006400),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _analyzeUsage,
            tooltip: 'Refresh Analysis',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnalysisPeriodSelector(),
                  const SizedBox(height: 16),
                  if (_currentUsage != null) ...[
                    _buildUsageStatsCard(),
                    const SizedBox(height: 24),
                    _buildRecommendationsSection(),
                  ] else
                    const Center(
                      child: Text('No usage data available'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAnalysisPeriodSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analysis Period',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 Days')),
                ButtonSegment(value: 15, label: Text('15 Days')),
                ButtonSegment(value: 30, label: Text('30 Days')),
              ],
              selected: {_analysisDays},
              onSelectionChanged: (Set<int> selected) {
                setState(() {
                  _analysisDays = selected.first;
                });
                _analyzeUsage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageStatsCard() {
    final usage = _currentUsage!;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Color(0xFF006400)),
                const SizedBox(width: 8),
                Text(
                  'Your Usage (Last ${usage.daysInPeriod} Days)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatRow(
              Icons.phone_forwarded,
              'Outgoing Calls',
              '${usage.outgoingCallMinutes} mins',
              '${usage.outgoingCallCount} calls',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.sms,
              'Sent Messages',
              '${usage.sentSmsCount} SMS',
              '',
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildStatRow(
              Icons.data_usage,
              'Estimated Data',
              '${usage.estimatedDataGB.toStringAsFixed(1)} GB',
              'Approximate',
              Colors.orange,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Daily Average: ${(usage.outgoingCallMinutes / usage.daysInPeriod).toStringAsFixed(1)} mins, ${(usage.sentSmsCount / usage.daysInPeriod).toStringAsFixed(1)} SMS',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    IconData icon,
    String label,
    String value,
    String subtitle,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.card_giftcard, color: Color(0xFF006400)),
            SizedBox(width: 8),
            Text(
              'Recommended Packages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Based on your usage patterns',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ..._recommendations.map((pkg) => _buildPackageCard(pkg)),
      ],
    );
  }

  Widget _buildPackageCard(PackageRecommendation pkg) {
    return Card(
      elevation: pkg.recommended ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: pkg.recommended
            ? const BorderSide(color: Color(0xFF006400), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pkg.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (pkg.recommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF006400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'RECOMMENDED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        pkg.description,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳${pkg.estimatedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006400),
                      ),
                    ),
                    Text(
                      pkg.durationLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPackageFeature(
                  Icons.data_usage,
                  pkg.dataGB == 999 ? 'Unlimited' : '${pkg.dataGB}GB',
                  'Data',
                ),
                _buildPackageFeature(
                  Icons.phone,
                  pkg.callMinutes == 9999 ? 'Unlimited' : '${pkg.callMinutes}',
                  'Minutes',
                ),
                _buildPackageFeature(
                  Icons.sms,
                  pkg.smsCount == 9999 ? 'Unlimited' : '${pkg.smsCount}',
                  'SMS',
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showPackageDetails(pkg);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: pkg.recommended
                      ? const Color(0xFF006400)
                      : Colors.grey.shade300,
                  foregroundColor: pkg.recommended ? Colors.white : Colors.black,
                ),
                child: const Text('View Details'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageFeature(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF006400), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showPackageDetails(PackageRecommendation pkg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pkg.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pkg.description),
            const SizedBox(height: 16),
            _buildDetailRow('Data', pkg.dataGB == 999 ? 'Unlimited' : '${pkg.dataGB} GB'),
            _buildDetailRow('Call Minutes', pkg.callMinutes == 9999 ? 'Unlimited' : '${pkg.callMinutes} mins'),
            _buildDetailRow('SMS', pkg.smsCount == 9999 ? 'Unlimited' : '${pkg.smsCount} messages'),
            _buildDetailRow('Validity', pkg.durationLabel),
            _buildDetailRow('Price', '৳${pkg.estimatedPrice.toStringAsFixed(0)}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This recommendation is based on your last ${_currentUsage?.daysInPeriod ?? _analysisDays} days of usage.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
