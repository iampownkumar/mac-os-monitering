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
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchStatus(); // first load
  }

  Future<void> fetchStatus() async {
    setState(() => loading = true);

    try {
      final res = await http.get(
        Uri.parse("http://admin-pc.local:8000/status"),
      );
      final decoded = jsonDecode(res.body);
      final Map<String, dynamic> data = decoded["machines"];

      final Map<String, bool> newStatus = {};
      data.forEach((k, v) => newStatus[k] = v == true);

      setState(() => status = newStatus);
    } catch (e) {
      debugPrint("Status fetch error: $e");
    }

    setState(() => loading = false);
  }

  Future<void> confirm(
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
      appBar: AppBar(
        title: const Text("Mac Lab Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: "Refresh (Parallel SSH)",
            onPressed: fetchStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: machines.length,
              itemBuilder: (context, i) {
                final name = machines[i];
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
                                Uri.parse(
                                  "http://admin-pc.local:8000/reboot/$name",
                                ),
                              );
                              Navigator.pop(context);
                            },
                          ),
                          TextButton(
                            child: const Text("Shutdown"),
                            onPressed: () async {
                              await http.post(
                                Uri.parse(
                                  "http://admin-pc.local:8000/shutdown/$name",
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  onPressed: () => confirm(
                    "Reboot Lab",
                    "Reboot ALL Macs?",
                    () => http.post(
                      Uri.parse("http://admin-pc.local:8000/reboot-all"),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text("Shutdown ALL"),
                  onPressed: () => confirm(
                    "Shutdown Lab",
                    "Shutdown ALL Macs?",
                    () => http.post(
                      Uri.parse("http://admin-pc.local:8000/shutdown-all"),
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
