import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class BlocklistScreen extends StatefulWidget {
  const BlocklistScreen({super.key});

  @override
  State<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends State<BlocklistScreen> {
  final _numberController = TextEditingController();
  final _reasonController = TextEditingController();
  List<Map<String, dynamic>> _blockedNumbers = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    NotificationService().init(context);
  }

  @override
  void initState() {
    super.initState();
    _loadBlockedNumbers();
  }

  Future<void> _loadBlockedNumbers() async {
    setState(() => _loading = true);
    try {
      final numbers = await AppDatabase.instance.getBlocked();
      setState(() {
        _blockedNumbers = numbers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading blocklist: $e')),
        );
      }
    }
  }

  Future<void> _addNumber() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    try {
      await AppDatabase.instance.addBlocked(
        number, 
        reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
      );
      // Show notification for block
      await NotificationService().showNotification(
        title: 'Number Blocked (App Only)',
        body: 'Blocked $number in Civic App.\nTo block at system level, tap the settings button.',
      );
      
      _numberController.clear();
      _reasonController.clear();
      _loadBlockedNumbers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $number to blocklist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding number: $e')),
        );
      }
    }
  }

  Future<void> _removeNumber(String number) async {
    try {
      await AppDatabase.instance.removeBlocked(number);
      _loadBlockedNumbers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $number from blocklist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing number: $e')),
        );
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Number to Blocklist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addNumber();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blocked Numbers',
          style: TextStyle(
            color: Color(0xFF006400),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Open System Blocklist Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // Open system call blocking settings (best effort)
              const url = 'package:com.android.contacts';
              // Try to open the system's call blocking settings
              final intentUri = Uri.parse('content://com.android.contacts/blocked');
              if (await canLaunchUrl(intentUri)) {
                await launchUrl(intentUri);
              } else {
                // Fallback: open phone app settings
                await launchUrl(Uri.parse('package:com.android.phone'));
              }
            },
          ),
          IconButton(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedNumbers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.block, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No blocked numbers yet'),
                      SizedBox(height: 8),
                      Text('Tap + to add a number to blocklist'),
                      SizedBox(height: 8),
                      Text(
                        'Note: Blocking here is app-only.\nTo block at the system level, use the settings button.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _blockedNumbers.length,
                  itemBuilder: (context, index) {
                    final item = _blockedNumbers[index];
                    final number = item['number'] as String;
                    final reason = item['reason'] as String?;
                    final createdAt = DateTime.fromMillisecondsSinceEpoch(
                      item['created_at'] as int,
                    );

                    return ListTile(
                      leading: const Icon(Icons.block, color: Colors.red),
                      title: Text(number),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (reason != null) Text('Reason: $reason'),
                          Text('Added: ${createdAt.toString().split('.')[0]}'),
                        ],
                      ),
                      trailing: IconButton(
                        onPressed: () => _removeNumber(number),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}