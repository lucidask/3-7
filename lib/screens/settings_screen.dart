import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: settings.localeCode,
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'ht', child: Text('Kreyòl Ayisyen')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v != null) controller.setLocale(v);
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Tutorial completed'),
                const SizedBox(width: 12),
                Switch(
                  value: settings.tutorialDone,
                  onChanged: (val) => controller.setTutorialDone(val),
                ),
              ],
            ),
            // --- Conditions de victoire ---
            const SizedBox(height: 24),
            const Text('Conditions de victoire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text('Points'),
                const Spacer(),
                IconButton(
                  onPressed: () => controller.setScoreTarget(settings.scoreTarget - 1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Moins',
                ),
                Text('${settings.scoreTarget}', style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => controller.setScoreTarget(settings.scoreTarget + 1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Plus',
                ),
              ],
            ),
            Row(
              children: [
                const Text('Séquences'),
                const Spacer(),
                IconButton(
                  onPressed: () => controller.setSequencesTarget(settings.sequencesTarget - 1),
                  icon: const Icon(Icons.remove),
                  tooltip: 'Moins',
                ),
                Text('${settings.sequencesTarget}', style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: () => controller.setSequencesTarget(settings.sequencesTarget + 1),
                  icon: const Icon(Icons.add),
                  tooltip: 'Plus',
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Step 4: Settings stored in Hive.'),
          ],
        ),
      ),
    );
  }
}
