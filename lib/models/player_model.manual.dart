part of 'player_model.dart';

class PlayerTypeAdapter extends TypeAdapter<PlayerType> {
  @override
  final int typeId = 4;

  @override
  PlayerType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return PlayerType.human;
      case 1: return PlayerType.bot;
      default: return PlayerType.human;
    }
  }

  @override
  void write(BinaryWriter writer, PlayerType obj) {
    switch (obj) {
      case PlayerType.human: writer.writeByte(0); break;
      case PlayerType.bot: writer.writeByte(1); break;
    }
  }
}

class PlayerModelAdapter extends TypeAdapter<PlayerModel> {
  @override
  final int typeId = 5;

  @override
  PlayerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PlayerModel(
      id: fields[0] as String,
      nickname: fields[1] as String,
      type: fields[2] as PlayerType,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nickname)
      ..writeByte(2)
      ..write(obj.type);
  }
}
