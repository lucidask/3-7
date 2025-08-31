part of 'settings_model.dart';

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 6;

  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return SettingsModel(
      localeCode: fields[0] as String,
      tutorialDone: fields[1] as bool,
      scoreTarget: (fields.containsKey(2) ? fields[2] as int : 21),
      sequencesTarget: (fields.containsKey(3) ? fields[3] as int : 4),
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(4)     // 👈 total de champs
      ..writeByte(0)
      ..write(obj.localeCode)
      ..writeByte(1)
      ..write(obj.tutorialDone)
      ..writeByte(2)
      ..write(obj.scoreTarget)
      ..writeByte(3)
      ..write(obj.sequencesTarget);
  }
}

