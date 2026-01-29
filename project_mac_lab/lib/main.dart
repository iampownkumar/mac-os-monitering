import 'package:flutter/material.dart';
import 'screens/dashboard_page.dart';
import 'screens/multi_install_page.dart';

void main() {
  runApp(const MacLabApp());
}

class MacLabApp extends StatelessWidget {
  const MacLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mac Lab Control',
      theme: ThemeData.dark(useMaterial3: true),
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
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.computer), label: "Lab"),
          NavigationDestination(icon: Icon(Icons.download), label: "Software"),
        ],
      ),
    );
  }
}
