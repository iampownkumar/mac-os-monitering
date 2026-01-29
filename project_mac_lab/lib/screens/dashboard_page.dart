import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/brew_services.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> machines = List.generate(
    33,
    (i) => 'mac-${(i + 1).toString().padLeft(3, '0')}',
  );

  Map<String, bool> status = {};
  bool loading = false;

  int countdown = 20;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startRefresh();
  }

  void startRefresh() {
    timer?.cancel();
    countdown = 20;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => countdown--);

      if (countdown == 0) {
        t.cancel();
        fetchStatus();
      }
    });

    fetchStatus();
  }

  Future<void> fetchStatus() async {
    if (!mounted) return;
    setState(() => loading = true);
    try {
      status = await BrewService.fetchStatus();
    } catch (_) {}
    if (!mounted) return;
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
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mac Lab Dashboard"),
        actions: [
          Center(child: Text("Refresh in $countdown s   ")),
          IconButton(icon: const Icon(Icons.refresh), onPressed: startRefresh),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: machines.length,
              itemBuilder: (context, i) {
                final name = machines[i];
                final online = status[name] ?? false;

                final extraGap = (i % 6 == 2) ? 18.0 : 6.0;

                return Padding(
                  padding: EdgeInsets.only(right: extraGap),
                  child: Container(
                    decoration: BoxDecoration(
                      color: online
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
                    "Reboot ALL Macs now?",
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
                    "Shutdown ALL Macs now?",
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
