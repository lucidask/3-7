import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/settings_model.dart';
import '../services/hive_service.dart';

final settingsProvider = StateNotifierProvider<SettingsController, SettingsModel>((ref) {
  final box = HiveService.settingsBox;
  final current = box.get(
    'app',
    defaultValue: const SettingsModel(localeCode: 'fr', tutorialDone: false, scoreTarget: 21, sequencesTarget: 4),
  )!;
  return SettingsController(box, current);
});

class SettingsController extends StateNotifier<SettingsModel> {
  final Box<SettingsModel> _box;
  SettingsController(this._box, SettingsModel initial) : super(initial);

  // existants
  Future<void> setLocale(String code) async {
    state = state.copyWith(localeCode: code);
    await _box.put('app', state);
  }

  Future<void> setTutorialDone(bool done) async {
    state = state.copyWith(tutorialDone: done);
    await _box.put('app', state);
  }

  // 👇 AJOUT
  int get scoreTarget => state.scoreTarget;
  int get sequencesTarget => state.sequencesTarget;

  Future<void> setScoreTarget(int v) async {
    final val = v < 1 ? 1 : v;
    state = state.copyWith(scoreTarget: val);
    await _box.put('app', state);
  }

  Future<void> setSequencesTarget(int v) async {
    final val = v < 1 ? 1 : v;
    state = state.copyWith(sequencesTarget: val);
    await _box.put('app', state);
  }
}
