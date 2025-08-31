import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

Future<void> safeBack(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
    return;
  }
  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
  );
}
