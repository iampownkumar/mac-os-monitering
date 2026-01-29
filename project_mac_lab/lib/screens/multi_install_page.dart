import 'dart:async';
import 'package:flutter/material.dart';
import '../services/brew_services.dart';

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
  final TextEditingController pkgController = TextEditingController();
  String type = "cask";
  bool running = false;
  String terminal = "";

  final Map<String, StreamSubscription<String>> streams = {};

  void append(String text) {
    setState(() => terminal += text);
  }

  Future<void> startInstall() async {
    if (selected.isEmpty || pkgController.text.trim().isEmpty) return;

    setState(() {
      terminal = "";
      running = true;
    });

    for (final mac in selected) {
      final id = mac.split("-")[1];

      final stream = await BrewService.installStream(
        macId: id,
        type: type,
        name: pkgController.text.trim(),
      );

      final sub = stream.listen(
        (line) => append(line),
        onDone: () {
          append("\n[$mac] Stream closed\n");
          streams.remove(mac);
          if (streams.isEmpty) {
            setState(() => running = false);
          }
        },
        onError: (e) => append("\n[$mac] ERROR: $e\n"),
      );

      streams[mac] = sub;
    }
  }

  Future<void> stopAll() async {
    for (final mac in selected) {
      final id = mac.split("-")[1];
      await BrewService.stopInstall(id);
    }

    for (final sub in streams.values) {
      await sub.cancel();
    }

    streams.clear();
    setState(() => running = false);
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
                return FilterChip(
                  label: Text(m),
                  selected: selected.contains(m),
                  onSelected: (v) {
                    setState(() {
                      v ? selected.add(m) : selected.remove(m);
                    });
                  },
                  selectedColor: Colors.blueAccent,
                  checkmarkColor: Colors.white,
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

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_download),
                  label: const Text("Install Selected"),
                  onPressed: running ? null : startInstall,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text("Stop All"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: running ? stopAll : null,
                ),
              ],
            ),

            const SizedBox(height: 10),
            if (running) const LinearProgressIndicator(),

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
