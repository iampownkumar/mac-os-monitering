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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index = 0;

  final pages = const [DashboardPage(), SoftwarePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.computer), label: "Lab"),
          BottomNavigationBarItem(
            icon: Icon(Icons.download),
            label: "Software",
          ),
        ],
      ),
    );
  }
}

/* =========================
   DASHBOARD (FULL GRID)
   ========================= */

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
    fetchStatus();
  }

  Future<void> fetchStatus() async {
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse("http://admin-pc.local:8000/status"),
      );
      final decoded = jsonDecode(res.body);
      final Map<String, dynamic> data = decoded["machines"];
      setState(() {
        status = data.map((k, v) => MapEntry(k, v == true));
      });
    } catch (_) {}
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
          IconButton(icon: const Icon(Icons.flash_on), onPressed: fetchStatus),
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
              ),
              itemCount: machines.length,
              itemBuilder: (context, i) {
                final name = machines[i];
                final online = status[name] ?? false;

                return Container(
                  decoration: BoxDecoration(
                    color: online ? Colors.green[700] : Colors.red[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(child: Text(name)),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/* =========================
   SOFTWARE INSTALLER UI
   ========================= */

class SoftwarePage extends StatefulWidget {
  const SoftwarePage({super.key});

  @override
  State<SoftwarePage> createState() => _SoftwarePageState();
}

class _SoftwarePageState extends State<SoftwarePage> {
  final TextEditingController appController = TextEditingController();
  String type = "cask";
  bool loading = false;
  String output = "";

  Future<void> install() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse("http://admin-pc.local:8000/brew/install/23"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"type": type, "name": appController.text}),
      );
      setState(() => output = res.body);
    } catch (e) {
      setState(() => output = e.toString());
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Install Software (mac-023)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: appController,
              decoration: const InputDecoration(
                hintText: "firefox, iterm2, vscode",
              ),
            ),
            DropdownButton<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: "cask", child: Text("Cask (GUI)")),
                DropdownMenuItem(
                  value: "formula",
                  child: Text("Formula (CLI)"),
                ),
              ],
              onChanged: (v) => setState(() => type = v!),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download),
              label: const Text("Install"),
              onPressed: loading ? null : install,
            ),
            if (loading) const LinearProgressIndicator(),
            Expanded(child: SingleChildScrollView(child: Text(output))),
          ],
        ),
      ),
    );
  }
}
