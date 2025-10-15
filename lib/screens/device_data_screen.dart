import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';
import 'package:telephony/telephony.dart';

class DeviceDataScreen extends StatefulWidget {
  const DeviceDataScreen({Key? key}) : super(key: key);

  @override
  State<DeviceDataScreen> createState() => _DeviceDataScreenState();
}

class _DeviceDataScreenState extends State<DeviceDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Contact> _contacts = [];
  List<CallLogEntry> _callLogs = [];
  List<SmsMessage> _smsMessages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    await [
      Permission.contacts,
      Permission.sms,
      Permission.phone,
    ].request();
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final callLogs = await CallLog.get();
    final telephony = Telephony.instance;
    final sms = await telephony.getInboxSms(columns: [SmsColumn.ADDRESS, SmsColumn.BODY]);
    setState(() {
      _contacts = contacts;
      _callLogs = callLogs.toList();
      _smsMessages = sms;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Device Data',
          style: TextStyle(
            color: Color(0xFF006400),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.phone), text: 'Calls'),
            Tab(icon: Icon(Icons.sms), text: 'SMS'),
            Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCallLogs(),
                _buildSmsMessages(),
                _buildContacts(),
              ],
            ),
    );
  }

  Widget _buildCallLogs() {
    if (_callLogs.isEmpty) {
      return const Center(child: Text('No call logs found'));
    }
    return ListView.builder(
      itemCount: _callLogs.length,
      itemBuilder: (context, index) {
        final entry = _callLogs[index];
        return ListTile(
          leading: const Icon(Icons.phone),
          title: Text(entry.name ?? entry.number ?? 'Unknown'),
          subtitle: Text('Type: 	${entry.callType} | Duration: ${entry.duration}s'),
          trailing: Text(entry.timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(entry.timestamp!).toLocal().toString().substring(0, 16)
              : ''),
        );
      },
    );
  }

  Widget _buildSmsMessages() {
    if (_smsMessages.isEmpty) {
      return const Center(child: Text('No SMS messages found'));
    }
    return ListView.builder(
      itemCount: _smsMessages.length,
      itemBuilder: (context, index) {
        final sms = _smsMessages[index];
        return ListTile(
          leading: const Icon(Icons.sms),
          title: Text(sms.address ?? 'Unknown'),
          subtitle: Text(sms.body ?? ''),
        );
      },
    );
  }

  Widget _buildContacts() {
    if (_contacts.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }
    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(contact.displayName),
          subtitle: Text(contact.phones.isNotEmpty ? contact.phones.first.number : ''),
        );
      },
    );
  }
}
