import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_seven/theme/card_back_theme.dart';
import 'services/hive_service.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();
  runApp(const ProviderScope(child: ThreeSevenApp()));
}

class ThreeSevenApp extends StatelessWidget {
  const ThreeSevenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3-7',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        extensions: const [
          // Couleurs du dos des cartes (thème clair)
          CardBackTheme(
            gradientColors: [Color(0xFF1B2245), Color(0xFF2F3A77)],
            borderColor: Colors.white24,
          ),
        ],
      ),
      // (optionnel) thème sombre cohérent
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        extensions: const [
          CardBackTheme(
            gradientColors: [Color(0xFF141A33), Color(0xFF232E5C)],
            borderColor: Color(0x40FFFFFF),
          ),
        ],
      ),
      themeMode: ThemeMode.system, // utilise clair/sombre selon le système
      home: const HomeScreen(),
    );
  }
}
