// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameStateAdapter extends TypeAdapter<GameState> {
  @override
  final int typeId = 0;

  @override
  GameState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameState(
      isLeft: fields[0] as bool,
      leftName: fields[1] as String,
      leftIP: fields[2] as String,
      leftPort: fields[3] as int,
      rightName: fields[4] as String,
      rightIP: fields[5] as String,
      rightPort: fields[6] as int,
      board: (fields[7] as List)
          .map((dynamic e) => (e as List).cast<String>())
          .toList(),
      bag: fields[8] as BagModel,
      leftLetters: (fields[9] as List).cast<String>(),
      rightLetters: (fields[10] as List).cast<String>(),
      leftScore: fields[11] as int,
      rightScore: fields[12] as int,
      lettersPlacedThisTurn: (fields[13] as List).cast<PlacedLetter>(),
    );
  }

  @override
  void write(BinaryWriter writer, GameState obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.isLeft)
      ..writeByte(1)
      ..write(obj.leftName)
      ..writeByte(2)
      ..write(obj.leftIP)
      ..writeByte(3)
      ..write(obj.leftPort)
      ..writeByte(4)
      ..write(obj.rightName)
      ..writeByte(5)
      ..write(obj.rightIP)
      ..writeByte(6)
      ..write(obj.rightPort)
      ..writeByte(7)
      ..write(obj.board)
      ..writeByte(8)
      ..write(obj.bag)
      ..writeByte(9)
      ..write(obj.leftLetters)
      ..writeByte(10)
      ..write(obj.rightLetters)
      ..writeByte(11)
      ..write(obj.leftScore)
      ..writeByte(12)
      ..write(obj.rightScore)
      ..writeByte(13)
      ..write(obj.lettersPlacedThisTurn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
