import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'utils/app_colors.dart';
import 'services/data_service.dart';
import 'views/home_screen.dart';
import 'views/map_screen.dart';
import 'views/report_screen.dart';
import 'views/safe_route_screen.dart';
import 'views/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FloodWatchApp());
}

class FloodWatchApp extends StatelessWidget {
  const FloodWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DataService()..fetchAreasFromApi(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: AppColors.primary,
          scaffoldBackgroundColor: const Color(0xFFF7F8FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.8,
          ),
        ),
        home: const RootNav(),
      ),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  late final List<Widget> _pages = [
  const HomeScreen(),
  const MapScreen(),
  const ReportScreen(),
  const SafeRouteScreen(),
  const SettingsScreen(),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label:        'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label:        'Map',
          ),
          NavigationDestination(
            icon:         Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label:        'Report',
          ),
          NavigationDestination(
            icon:         Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route),
            label:        'Safe Route',
          ),
          NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label:        'Settings',
          ),
        ],
      ),
    );
  }
}
