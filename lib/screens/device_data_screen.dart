import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:call_log/call_log.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceDataScreen extends StatefulWidget {
  const DeviceDataScreen({Key? key}) : super(key: key);

  @override
  State<DeviceDataScreen> createState() => _DeviceDataScreenState();
}

class _DeviceDataScreenState extends State<DeviceDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<CallLogEntry> _callLogs = [];
  List<SmsMessage> _smsMessages = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_filterContacts);
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
      _filteredContacts = contacts;
      _callLogs = callLogs.toList();
      _smsMessages = sms;
      _loading = false;
    });
  }

  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
          return name.contains(query) || phone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Remove any non-digit characters except + from phone number
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to make phone call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        // Contacts List
        Expanded(
          child: _filteredContacts.isEmpty
              ? Center(
                  child: Text(
                    _contacts.isEmpty ? 'No contacts found' : 'No matching contacts',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : 'No phone number',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: contact.phones.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.phone, color: Colors.green),
                              tooltip: 'Call ${contact.displayName}',
                              onPressed: () {
                                _makePhoneCall(contact.phones.first.number);
                              },
                            )
                          : null,
                      onTap: contact.phones.isNotEmpty
                          ? () => _makePhoneCall(contact.phones.first.number)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
