import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MacLabApp());
}

class MacLabApp extends StatelessWidget {
  const MacLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mac Lab Control',
      theme: ThemeData.dark(),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final List<String> machines = List.generate(
    33,
    (i) => 'mac-${(i + 1).toString().padLeft(3, '0')}',
  );

  Map<String, bool> status = {};
  Timer? refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchStatus();
    refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => fetchStatus(),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchStatus() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8000/status'),
      );

      final decoded = jsonDecode(response.body);
      String raw = decoded['raw'];

      // Strip ANSI color codes from Fish output
      raw = raw.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

      final Map<String, bool> newStatus = {};

      for (var line in raw.split('\n')) {
        if (line.contains('mac-')) {
          final parts = line.split(':');
          if (parts.length >= 2) {
            final name = parts[0].trim();
            final isOnline = parts[1].contains('ONLINE');
            newStatus[name] = isOnline;
          }
        }
      }

      setState(() {
        status = newStatus;
      });
    } catch (e) {
      debugPrint('Error fetching status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mac Lab Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchStatus),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.2,
        ),
        itemCount: machines.length,
        itemBuilder: (context, index) {
          String name = machines[index];
          bool online = status[name] ?? false;

          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(name),
                  content: Text(online ? "Status: ONLINE" : "Status: OFFLINE"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: online ? Colors.green[700] : Colors.red[700],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
