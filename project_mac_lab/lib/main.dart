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
  final pages = const [DashboardPage(), MultiInstallPage()];

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
   DASHBOARD
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
      setState(() => status = data.map((k, v) => MapEntry(k, v == true)));
    } catch (_) {}
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mac Lab Dashboard"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchStatus),
        ],
      ),
      body: Column(
        children: [
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
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
                  child: Center(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
   MULTI INSTALLER
   ========================= */

class MultiInstallPage extends StatefulWidget {
  const MultiInstallPage({super.key});

  @override
  State<MultiInstallPage> createState() => _MultiInstallPageState();
}

class _MultiInstallPageState extends State<MultiInstallPage> {
  final List<String> machines = List.generate(
    33,
    (i) => "mac-${(i + 1).toString().padLeft(3, '0')}",
  );

  final Set<String> selected = {};
  final Set<String> running = {};
  final TextEditingController pkgController = TextEditingController();
  String type = "cask";
  String terminal = "";
  final Map<String, StreamSubscription> streams = {};

  void append(String text) {
    setState(() => terminal += text);
  }

  Future<void> startInstall() async {
    if (selected.isEmpty || pkgController.text.trim().isEmpty) return;

    setState(() => terminal = "");

    for (final mac in selected) {
      final id = mac.split("-")[1];
      final uri = Uri.parse(
        "http://admin-pc.local:8000/brew/install/$id/stream"
        "?type=$type&name=${pkgController.text.trim()}",
      );

      running.add(mac);
      setState(() {});

      final req = http.Request("GET", uri);
      final res = await req.send();

      final sub = res.stream
          .transform(utf8.decoder)
          .listen(
            (line) => append(line),
            onDone: () {
              append("\n[$mac] Stream closed\n");
              running.remove(mac);
              setState(() {});
            },
            onError: (e) {
              append("\n[$mac] ERROR: $e\n");
              running.remove(mac);
              setState(() {});
            },
          );

      streams[mac] = sub;
    }
  }

  Future<void> stopAll() async {
    for (final mac in running.toList()) {
      final id = mac.split("-")[1];
      await http.post(Uri.parse("http://admin-pc.local:8000/brew/stop/$id"));
      streams[mac]?.cancel();
    }

    running.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Multi Software Install")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: machines.map((m) {
                final active = selected.contains(m);
                return FilterChip(
                  label: Text(m),
                  selected: active,
                  onSelected: (v) {
                    setState(() {
                      v ? selected.add(m) : selected.remove(m);
                    });
                  },
                  selectedColor: Colors.blueAccent,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: pkgController,
              decoration: const InputDecoration(
                labelText: "Package name",
                hintText: "iterm2, firefox, htop, python",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text("Type: "),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: "cask", child: Text("Cask (GUI)")),
                    DropdownMenuItem(value: "formula", child: Text("Formula")),
                  ],
                  onChanged: (v) => setState(() => type = v!),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: const Text("Install Selected"),
                  onPressed: running.isNotEmpty ? null : startInstall,
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop All"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: running.isEmpty ? null : stopAll,
                ),
              ],
            ),

            const SizedBox(height: 10),
            if (running.isNotEmpty) const LinearProgressIndicator(),

            const SizedBox(height: 10),
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.all(8),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    terminal,
                    style: const TextStyle(
                      fontFamily: "monospace",
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
