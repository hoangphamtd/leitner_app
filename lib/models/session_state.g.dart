// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionStateAdapter extends TypeAdapter<SessionState> {
  @override
  final typeId = 3;

  @override
  SessionState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionState(
      queueCardIds: (fields[0] as List).cast<String>(),
      failedCardIds: (fields[1] as List).cast<String>(),
      completedCardIds: (fields[2] as List).cast<String>(),
      initialCount: (fields[3] as num).toInt(),
      correctAnswers: (fields[4] as num).toInt(),
      wrongAnswers: (fields[5] as num).toInt(),
      startedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SessionState obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.queueCardIds)
      ..writeByte(1)
      ..write(obj.failedCardIds)
      ..writeByte(2)
      ..write(obj.completedCardIds)
      ..writeByte(3)
      ..write(obj.initialCount)
      ..writeByte(4)
      ..write(obj.correctAnswers)
      ..writeByte(5)
      ..write(obj.wrongAnswers)
      ..writeByte(6)
      ..write(obj.startedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
