part of 'card_model.dart';

class SuitAdapter extends TypeAdapter<Suit> {
  @override
  final int typeId = 1;

  @override
  Suit read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return Suit.clubs;
      case 1: return Suit.diamonds;
      case 2: return Suit.hearts;
      case 3: return Suit.spades;
      default: return Suit.clubs;
    }
  }

  @override
  void write(BinaryWriter writer, Suit obj) {
    switch (obj) {
      case Suit.clubs: writer.writeByte(0); break;
      case Suit.diamonds: writer.writeByte(1); break;
      case Suit.hearts: writer.writeByte(2); break;
      case Suit.spades: writer.writeByte(3); break;
    }
  }
}

class RankAdapter extends TypeAdapter<Rank> {
  @override
  final int typeId = 2;

  @override
  Rank read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return Rank.seven;
      case 1: return Rank.eight;
      case 2: return Rank.jack;
      case 3: return Rank.queen;
      case 4: return Rank.king;
      case 5: return Rank.ace;
      case 6: return Rank.nine;
      case 7: return Rank.ten;
      default: return Rank.seven;
    }
  }

  @override
  void write(BinaryWriter writer, Rank obj) {
    switch (obj) {
      case Rank.seven: writer.writeByte(0); break;
      case Rank.eight: writer.writeByte(1); break;
      case Rank.jack: writer.writeByte(2); break;
      case Rank.queen: writer.writeByte(3); break;
      case Rank.king: writer.writeByte(4); break;
      case Rank.ace: writer.writeByte(5); break;
      case Rank.nine: writer.writeByte(6); break;
      case Rank.ten: writer.writeByte(7); break;
    }
  }
}

class CardModelAdapter extends TypeAdapter<CardModel> {
  @override
  final int typeId = 3;

  @override
  CardModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CardModel(
      suit: fields[0] as Suit,
      rank: fields[1] as Rank,
      id: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CardModel obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.suit)
      ..writeByte(1)
      ..write(obj.rank)
      ..writeByte(2)
      ..write(obj.id);
  }
}
