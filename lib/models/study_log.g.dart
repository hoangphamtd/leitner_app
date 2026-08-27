// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'study_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudyLogAdapter extends TypeAdapter<StudyLog> {
  @override
  final typeId = 1;

  @override
  StudyLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudyLog(
      id: fields[0] as String,
      cardId: fields[1] as String,
      answeredAt: fields[2] as DateTime,
      isCorrect: fields[3] as bool,
      boxBefore: (fields[4] as num).toInt(),
      boxAfter: (fields[5] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, StudyLog obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.cardId)
      ..writeByte(2)
      ..write(obj.answeredAt)
      ..writeByte(3)
      ..write(obj.isCorrect)
      ..writeByte(4)
      ..write(obj.boxBefore)
      ..writeByte(5)
      ..write(obj.boxAfter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudyLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
