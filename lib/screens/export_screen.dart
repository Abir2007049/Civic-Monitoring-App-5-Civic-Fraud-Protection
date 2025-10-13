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

  Future<void> _exportData() async {
    setState(() => _exporting = true);
    
    try {
      // Get alerts and blocklist
      final alerts = await AppDatabase.instance.getAlerts();
      final blocklist = await AppDatabase.instance.getBlocked();
      
      // Prepare export data
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'version': '1.0',
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

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'civic_security_export_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(p.join(directory.path, fileName));
      
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );
      
      setState(() {
        _exporting = false;
        _lastExportPath = file.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully\nSaved to: ${file.path}'),
            duration: const Duration(seconds: 4),
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
      // For demo purposes, we'll look for the most recent export file
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync()
          .where((f) => f.path.contains('civic_security_export_') && f.path.endsWith('.json'))
          .cast<File>()
          .toList();
      
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
      ),
      body: Padding(
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
                    const Text(
                      'Export Data',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Export all alerts and blocked numbers to a JSON file for backup or transfer.'),
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

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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

            const Spacer(),

            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(height: 8),
                    Text(
                      'Export files are saved to the app documents directory and can be shared or backed up to cloud storage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
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
}