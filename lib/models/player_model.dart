import 'package:hive/hive.dart';

part 'player_model.manual.dart';

@HiveType(typeId: 4)
enum PlayerType {
  @HiveField(0) human,
  @HiveField(1) bot,
}

@HiveType(typeId: 5)
class PlayerModel {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nickname;

  @HiveField(2)
  final PlayerType type;

  const PlayerModel({
    required this.id,
    required this.nickname,
    required this.type,
  });
}
