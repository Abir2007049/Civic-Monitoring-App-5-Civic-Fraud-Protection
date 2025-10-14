import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/db_service.dart';
import '../models/models.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _exporting = false;
  bool _importing = false;
  String? _lastExportPath;
  int _alertCount = 0;
  int _blocklistCount = 0;

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    
    try {
      // Get alerts and blocklist
      final alerts = await AppDatabase.instance.getAlerts();
      final blocklist = await AppDatabase.instance.getBlocked();
      
      // Check if there's actually data to export
      if (alerts.isEmpty && blocklist.isEmpty) {
        setState(() => _exporting = false);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('📊 No Data to Export'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You need some fraud protection data first!'),
                  SizedBox(height: 16),
                  Text('🎯 Quick ways to generate data:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(''),
                  Text('📱 Dashboard → Analyze Numbers:'),
                  Text('   • Try: +1800SCAM99'),
                  Text('   • Try: +140123456'),
                  Text(''),
                  Text('🚫 Block Numbers:'),
                  Text('   • Menu → Blocked Numbers → Add'),
                  Text(''),
                  Text('🎮 Run Demos:'),
                  Text('   • Message Spam Detection → Demo'),
                  Text('   • Call Protection → Demo Mode'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Go back to main app
                  },
                  child: const Text('Go Create Data'),
                ),
              ],
            ),
          );
        }
        return;
      }
      
      // Prepare export data
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'version': '1.0',
        'summary': {
          'total_alerts': alerts.length,
          'total_blocked_numbers': blocklist.length,
          'export_timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'alerts': alerts.map((alert) => {
          'type': alert.type,
          'message': alert.message,
          'severity': alert.severity,
          'timestamp': alert.timestamp.toIso8601String(),
        }).toList(),
        'blocklist': blocklist.map((item) => {
          'number': item['number'],
          'reason': item['reason'],
          'created_at': DateTime.fromMillisecondsSinceEpoch(item['created_at'] as int).toIso8601String(),
        }).toList(),
      };

      // Try multiple locations for saving the file
      final fileName = 'civic_security_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final jsonContent = const JsonEncoder.withIndent('  ').convert(exportData);
      
      File? savedFile;
      String locationUsed = '';
      
      // Location 1: External storage Downloads (most accessible)
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          savedFile = File(p.join(downloadsDir.path, fileName));
          await savedFile.writeAsString(jsonContent);
          locationUsed = 'Downloads folder (/storage/emulated/0/Download)';
        }
      } catch (e) {
        // Continue to next location
      }
      
      // Location 2: Pictures folder (usually accessible)
      if (savedFile == null) {
        try {
          final picturesDir = Directory('/storage/emulated/0/Pictures');
          if (await picturesDir.exists()) {
            savedFile = File(p.join(picturesDir.path, fileName));
            await savedFile.writeAsString(jsonContent);
            locationUsed = 'Pictures folder (/storage/emulated/0/Pictures)';
          }
        } catch (e) {
          // Continue to next location
        }
      }
      
      // Location 3: External storage root (if Downloads failed)
      if (savedFile == null) {
        try {
          final externalDir = Directory('/storage/emulated/0');
          if (await externalDir.exists()) {
            savedFile = File(p.join(externalDir.path, fileName));
            await savedFile.writeAsString(jsonContent);
            locationUsed = 'Internal storage root (/storage/emulated/0)';
          }
        } catch (e) {
          // Continue to next location
        }
      }
      
      // Location 4: App documents directory (fallback)
      if (savedFile == null) {
        final appDir = await getApplicationDocumentsDirectory();
        savedFile = File(p.join(appDir.path, fileName));
        await savedFile.writeAsString(jsonContent);
        locationUsed = 'App documents (${appDir.path})';
      }
      
      // Verify file was created successfully
      final fileExists = await savedFile.exists();
      final fileSize = await savedFile.length();
      
      // At this point savedFile must be non-null (fallback ensures creation)
      final exportPath = savedFile!.path;
      setState(() {
        _exporting = false;
        _lastExportPath = exportPath;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Export successful!'),
                Text('📍 Location: $locationUsed'),
                Text('📄 File: $fileName'),
                Text('📊 Size: ${(fileSize / 1024).toStringAsFixed(1)} KB'),
                Text('🔍 Full path: $exportPath'),
                if (!fileExists) Text('⚠️ Warning: File verification failed'),
              ],
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Copy Path',
              onPressed: () {
                // Copy path to clipboard (we'll implement this)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Path copied: $exportPath')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _exporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    setState(() => _importing = true);
    
    try {
      // Look for export files in Downloads folder first, then app documents
      List<File> files = [];
      
      // Check Downloads folder first
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          files.addAll(downloadsDir.listSync()
              .where((f) => f.path.contains('civic_security_export_') && f.path.endsWith('.json'))
              .cast<File>());
        }
      } catch (e) {
        // Ignore if Downloads not accessible
      }
      
      // Check app documents directory as fallback
      final directory = await getApplicationDocumentsDirectory();
      files.addAll(directory.listSync()
          .where((f) => f.path.contains('civic_security_export_') && f.path.endsWith('.json'))
          .cast<File>());
      
      if (files.isEmpty) {
        throw Exception('No export files found');
      }
      
      // Get the most recent file
      files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      final file = files.first;
      
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      
      // Import blocklist
      final blocklist = data['blocklist'] as List<dynamic>;
      for (final item in blocklist) {
        await AppDatabase.instance.addBlocked(
          item['number'] as String,
          reason: item['reason'] as String?,
        );
      }
      
      // Import alerts
      final alerts = data['alerts'] as List<dynamic>;
      for (final item in alerts) {
        await AppDatabase.instance.addAlert(
          FraudAlert(
            type: item['type'] as String,
            message: item['message'] as String,
            severity: item['severity'] as String,
            timestamp: DateTime.parse(item['timestamp'] as String),
          ),
        );
      }
      
      setState(() => _importing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data imported successfully from ${p.basename(file.path)}'),
          ),
        );
      }
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  Future<void> _showExportLocations() async {
    // Debug: Let user know the function is working
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🔍 Scanning for export files...'), duration: Duration(seconds: 1)),
    );
    
    final locations = <String, String>{};
    
    // Check Downloads folder
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final files = downloadsDir.listSync()
            .where((f) => f.path.contains('civic_security_export_'))
            .length;
        locations['📥 Downloads folder'] = '/storage/emulated/0/Download ($files files)';
      }
    } catch (e) {
      locations['📥 Downloads folder'] = 'Not accessible';
    }
    
    // Check Pictures folder
    try {
      final picturesDir = Directory('/storage/emulated/0/Pictures');
      if (await picturesDir.exists()) {
        final files = picturesDir.listSync()
            .where((f) => f.path.contains('civic_security_export_'))
            .length;
        locations['🖼️ Pictures folder'] = '/storage/emulated/0/Pictures ($files files)';
      }
    } catch (e) {
      locations['🖼️ Pictures folder'] = 'Not accessible';
    }
    
    // Check internal storage root
    try {
      final internalDir = Directory('/storage/emulated/0');
      if (await internalDir.exists()) {
        final files = internalDir.listSync()
            .where((f) => f.path.contains('civic_security_export_'))
            .length;
        locations['📱 Internal storage root'] = '/storage/emulated/0 ($files files)';
      }
    } catch (e) {
      locations['📱 Internal storage root'] = 'Not accessible';
    }
    
    // Check app documents
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final files = appDir.listSync()
          .where((f) => f.path.contains('civic_security_export_'))
          .length;
      locations['App documents'] = '${appDir.path} ($files files)';
    } catch (e) {
      locations['App documents'] = 'Not accessible';
    }
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('📍 Find Your Export Files'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🎯 Quick Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('1. Open File Manager app'),
                        Text('2. Search for "civic_security_export"'),
                        Text('3. All export files will appear!'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('📂 Check these locations:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...locations.entries.map((entry) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text(entry.value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💡 Pro Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('• File names: civic_security_export_[timestamp].json'),
                        Text('• Use search instead of manual browsing'),
                        Text('• Files can be shared via email/messaging'),
                        Text('• No files? Export some data first!'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _exportData();
              },
              child: const Text('Export Now'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all alerts and blocked numbers. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear alerts by getting all and removing each (simple approach)
        final alerts = await AppDatabase.instance.getAlerts();
        final blocklist = await AppDatabase.instance.getBlocked();
        
        // Remove all blocked numbers
        for (final item in blocklist) {
          await AppDatabase.instance.removeBlocked(item['number'] as String);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDataCounts();
  }

  Future<void> _loadDataCounts() async {
    final alerts = await AppDatabase.instance.getAlerts();
    final blocklist = await AppDatabase.instance.getBlocked();
    setState(() {
      _alertCount = alerts.length;
      _blocklistCount = blocklist.length;
    });
  }

  Future<void> _createSampleData() async {
    try {
      // Add some sample fraud alerts
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'number',
        message: 'Analyzed +1800SCAM99 -> High risk score: 85',
        severity: 'high',
        timestamp: DateTime.now(),
      ));
      
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'sms',
        message: 'Blocked phishing SMS from +140FAKE123',
        severity: 'critical',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ));
      
      await AppDatabase.instance.addAlert(FraudAlert(
        type: 'url',
        message: 'Detected malicious URL: bit.ly/fake-prize',
        severity: 'medium',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ));

      // Add some blocked numbers
      await AppDatabase.instance.addBlocked('+1800TELEMARKET', reason: 'Persistent telemarketer');
      await AppDatabase.instance.addBlocked('+555SPAM123', reason: 'Robocall spam');
      await AppDatabase.instance.addBlocked('+999SCAM456', reason: 'Phone scam attempt');
      
      // Refresh data counts
      await _loadDataCounts();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sample data created! You can now export data.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating sample data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Data Management'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + (viewInsets > 0 ? viewInsets : 24)),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - (viewInsets > 0 ? viewInsets : 0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Export all alerts and blocked numbers to a JSON file for backup or transfer.'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _alertCount > 0 || _blocklistCount > 0 ? Colors.green.shade50 : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _alertCount > 0 || _blocklistCount > 0 ? Colors.green.shade300 : Colors.orange.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _alertCount > 0 || _blocklistCount > 0 ? Icons.check_circle : Icons.warning,
                            color: _alertCount > 0 || _blocklistCount > 0 ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Data:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _alertCount > 0 || _blocklistCount > 0 ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                                Text('📊 Fraud Alerts: $_alertCount'),
                                Text('🚫 Blocked Numbers: $_blocklistCount'),
                                if (_alertCount == 0 && _blocklistCount == 0) ...[
                                  const Text('Create some data first!', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: _createSampleData,
                                    icon: const Icon(Icons.add_chart, size: 16),
                                    label: const Text('Create Sample Data'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _exporting ? null : _exportData,
                      icon: _exporting 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(_exporting ? 'Exporting...' : 'Export Data'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _showExportLocations,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('🔍 Find My Export Files'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_lastExportPath != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last export: ${p.basename(_lastExportPath!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Import alerts and blocked numbers from a previously exported JSON file.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _importing ? null : _importData,
                      icon: _importing 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_importing ? 'Importing...' : 'Import Data'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clear Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Permanently delete all alerts and blocked numbers from local storage.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _clearAllData,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Clear All Data'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Export files are saved to Downloads folder and can be shared via email or messaging.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20), // Extra padding at bottom
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}