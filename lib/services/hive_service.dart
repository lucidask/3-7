import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/card_model.dart';
import '../models/player_model.dart';
import '../models/settings_model.dart';

class HiveService {
  static const settingsBoxName = 'settingsBox';
  static const savedGamesBoxName = 'savedGamesBox';

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(SuitAdapter().typeId)) {
      Hive.registerAdapter(SuitAdapter());
    }
    if (!Hive.isAdapterRegistered(RankAdapter().typeId)) {
      Hive.registerAdapter(RankAdapter());
    }
    if (!Hive.isAdapterRegistered(CardModelAdapter().typeId)) {
      Hive.registerAdapter(CardModelAdapter());
    }
    if (!Hive.isAdapterRegistered(PlayerTypeAdapter().typeId)) {
      Hive.registerAdapter(PlayerTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(PlayerModelAdapter().typeId)) {
      Hive.registerAdapter(PlayerModelAdapter());
    }
    if (!Hive.isAdapterRegistered(SettingsModelAdapter().typeId)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }

    await Hive.openBox<SettingsModel>(settingsBoxName);
    await Hive.openBox<Map>(savedGamesBoxName);
  }

  static Box<SettingsModel> get settingsBox => Hive.box<SettingsModel>(settingsBoxName);
  static Box<Map> get savedGamesBox => Hive.box<Map>(savedGamesBoxName);
}
