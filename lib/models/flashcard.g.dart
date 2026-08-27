// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final typeId = 0;

  @override
  Flashcard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Flashcard(
      id: fields[0] as String,
      word: fields[1] as String,
      phonetic: fields[2] as String,
      meaning: fields[3] as String,
      exampleSentence: fields[4] as String,
      imagePath: fields[5] as String?,
      audioPath: fields[6] as String?,
      boxNumber: (fields[7] as num).toInt(),
      nextReviewDate: fields[8] as DateTime,
      isActive: fields[9] as bool,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
      reviewCount: fields[12] == null ? 0 : (fields[12] as num).toInt(),
      lapseCount: fields[13] == null ? 0 : (fields[13] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Flashcard obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.word)
      ..writeByte(2)
      ..write(obj.phonetic)
      ..writeByte(3)
      ..write(obj.meaning)
      ..writeByte(4)
      ..write(obj.exampleSentence)
      ..writeByte(5)
      ..write(obj.imagePath)
      ..writeByte(6)
      ..write(obj.audioPath)
      ..writeByte(7)
      ..write(obj.boxNumber)
      ..writeByte(8)
      ..write(obj.nextReviewDate)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt)
      ..writeByte(12)
      ..write(obj.reviewCount)
      ..writeByte(13)
      ..write(obj.lapseCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
