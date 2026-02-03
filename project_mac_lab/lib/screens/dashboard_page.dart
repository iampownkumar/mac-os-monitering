import 'dart:async';
import 'package:flutter/material.dart';
import '../services/brew_services.dart';
import 'package:http/http.dart' as http;

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

  final Set<String> selected = {};

  Map<String, bool> status = {};
  bool loading = false;

  // ✅ STATUS COUNTERS
  int onlineCount = 0;
  int offlineCount = 0;

  int countdown = 20;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startRefresh();
  }

  void startRefresh() {
    countdown = 20;
    timer?.cancel();

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => countdown--);

      if (countdown == 0) {
        t.cancel();
        fetchStatus();
      }
    });

    fetchStatus();
  }

  // ========================
  // FETCH STATUS
  // ========================
  Future<void> fetchStatus() async {
    setState(() => loading = true);

    try {
      status = await BrewService.fetchStatus();

      // ✅ COUNT ONLINE / OFFLINE
      onlineCount = status.values.where((v) => v).length;
      offlineCount = status.values.where((v) => !v).length;
    } catch (_) {}

    setState(() => loading = false);
  }

  // ========================
  // CONFIRM DIALOG
  // ========================
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

  // ========================
  // REBOOT
  // ========================
  Future<void> rebootSelected() async {
    await confirmAndRun(
      "Reboot Selected",
      "Reboot ${selected.length} machines?\n\n${selected.join(", ")}",
      () async {
        for (final mac in selected) {
          await http.post(Uri.parse("http://admin-pc.local:8000/reboot/$mac"));
        }

        selected.clear();
        fetchStatus();
      },
    );
  }

  // ========================
  // SHUTDOWN
  // ========================
  Future<void> shutdownSelected() async {
    await confirmAndRun(
      "Shutdown Selected",
      "Shutdown ${selected.length} machines?\n\n${selected.join(", ")}",
      () async {
        for (final mac in selected) {
          await http.post(
            Uri.parse("http://admin-pc.local:8000/shutdown/$mac"),
          );
        }

        selected.clear();
        fetchStatus();
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  // ========================
  // STATUS BOX UI
  // ========================
  Widget _statusBox(String label, int count, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  // ========================
  // UI
  // ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mac Lab Dashboard"),
        actions: [
          Row(
            children: [
              const Text("Select All"),
              Checkbox(
                value: selected.length == machines.length,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      selected.addAll(machines);
                    } else {
                      selected.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: startRefresh,
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),

          // ========================
          // STATUS SUMMARY BAR
          // ========================
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statusBox("ONLINE", onlineCount, Colors.green),
                _statusBox("OFFLINE", offlineCount, Colors.red),
                _statusBox("TOTAL", machines.length, Colors.blue),
              ],
            ),
          ),

          // ========================
          // GRID
          // ========================
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: machines.length,
              itemBuilder: (context, i) {
                final name = machines[i];
                final online = status[name] ?? false;
                final isSelected = selected.contains(name);
                final gap = (i % 6 == 2) ? 18.0 : 6.0;

                return Padding(
                  padding: EdgeInsets.only(right: gap),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected ? selected.remove(name) : selected.add(name);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: online
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(color: Colors.blueAccent, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.blueAccent.withOpacity(0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ========================
          // GLOBAL CONTROLS
          // ========================
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    disabledBackgroundColor: Colors.orange.withOpacity(0.3),
                  ),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text("Reboot ALL"),
                  onPressed: selected.isNotEmpty
                      ? null
                      : () => confirmAndRun(
                          "Reboot Lab",
                          "Reboot ALL Macs?",
                          () => http.post(
                            Uri.parse("http://admin-pc.local:8000/reboot-all"),
                          ),
                        ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withOpacity(0.3),
                  ),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text("Shutdown ALL"),
                  onPressed: selected.isNotEmpty
                      ? null
                      : () => confirmAndRun(
                          "Shutdown Lab",
                          "Shutdown ALL Macs?",
                          () => http.post(
                            Uri.parse(
                              "http://admin-pc.local:8000/shutdown-all",
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),

          // ========================
          // SELECTED CONTROLS
          // ========================
          if (selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.restart_alt),
                    label: Text("Reboot (${selected.length})"),
                    onPressed: rebootSelected,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.power_settings_new),
                    label: Text("Shutdown (${selected.length})"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: shutdownSelected,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text("Clear"),
                    onPressed: () => setState(() => selected.clear()),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
