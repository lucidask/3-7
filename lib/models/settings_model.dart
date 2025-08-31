import 'package:hive/hive.dart';

part 'settings_model.manual.dart';

@HiveType(typeId: 6)
class SettingsModel {
  @HiveField(0)
  final String localeCode; // 'fr', 'ht', 'en'

  @HiveField(1)
  final bool tutorialDone;

  // 👇 AJOUT
  @HiveField(2)
  final int scoreTarget;      // défaut 21

  @HiveField(3)
  final int sequencesTarget;  // défaut 4

  const SettingsModel({
    required this.localeCode,
    required this.tutorialDone,
    this.scoreTarget = 21,        // 👈 défaut
    this.sequencesTarget = 4,     // 👈 défaut
  });

  SettingsModel copyWith({
    String? localeCode,
    bool? tutorialDone,
    int? scoreTarget,         // 👈 ajout
    int? sequencesTarget,     // 👈 ajout
  }) {
    return SettingsModel(
      localeCode: localeCode ?? this.localeCode,
      tutorialDone: tutorialDone ?? this.tutorialDone,
      scoreTarget: scoreTarget ?? this.scoreTarget,
      sequencesTarget: sequencesTarget ?? this.sequencesTarget,
    );
  }
}

