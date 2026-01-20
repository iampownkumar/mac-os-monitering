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
      debugShowCheckedModeBanner: false,
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
        Uri.parse('http://127.0.0.1:8000/status'),
      );
      final decoded = jsonDecode(response.body);
      String raw = decoded['raw'];

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

      setState(() => status = newStatus);
    } catch (e) {
      debugPrint('Status error: $e');
    }
  }

  Future<void> confirmAndRun(
    String title,
    String msg,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (ok == true) await action();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mac Lab Dashboard')),

      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.2,
              ),
              itemCount: machines.length,
              itemBuilder: (context, index) {
                final name = machines[index];
                final online = status[name] ?? false;

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(name),
                        content: Text(online ? "ONLINE" : "OFFLINE"),
                        actions: [
                          TextButton(
                            child: const Text("Reboot"),
                            onPressed: () async {
                              await http.post(
                                Uri.parse("http://127.0.0.1:8000/reboot/$name"),
                              );
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text("Shutdown"),
                            onPressed: () async {
                              await http.post(
                                Uri.parse(
                                  "http://127.0.0.1:8000/shutdown/$name",
                                ),
                              );
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text("Close"),
                            onPressed: () => Navigator.pop(context),
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
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("Reboot ALL"),
                  onPressed: () => confirmAndRun(
                    "Reboot Lab",
                    "Reboot ALL machines?",
                    () => http.post(
                      Uri.parse("http://127.0.0.1:8000/reboot-all"),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text("Shutdown ALL"),
                  onPressed: () => confirmAndRun(
                    "Shutdown Lab",
                    "Shutdown ALL machines?",
                    () => http.post(
                      Uri.parse("http://127.0.0.1:8000/shutdown-all"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
