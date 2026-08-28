// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      newCardsPerDay: fields[0] == null ? 20 : (fields[0] as num).toInt(),
      lastActivationDate: fields[1] as DateTime?,
      activatedCountToday: fields[2] == null ? 0 : (fields[2] as num).toInt(),
      ttsVoiceName: fields[3] as String?,
      ttsVoiceLocale: fields[4] as String?,
      ttsRate: fields[5] == null ? 0.45 : (fields[5] as num).toDouble(),
      themeMode: fields[6] == null
          ? AppThemeMode.system
          : fields[6] as AppThemeMode,
      lastBackupAt: fields[7] as DateTime?,
      installPromptDismissedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.newCardsPerDay)
      ..writeByte(1)
      ..write(obj.lastActivationDate)
      ..writeByte(2)
      ..write(obj.activatedCountToday)
      ..writeByte(3)
      ..write(obj.ttsVoiceName)
      ..writeByte(4)
      ..write(obj.ttsVoiceLocale)
      ..writeByte(5)
      ..write(obj.ttsRate)
      ..writeByte(6)
      ..write(obj.themeMode)
      ..writeByte(7)
      ..write(obj.lastBackupAt)
      ..writeByte(8)
      ..write(obj.installPromptDismissedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppThemeModeAdapter extends TypeAdapter<AppThemeMode> {
  @override
  final typeId = 4;

  @override
  AppThemeMode read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AppThemeMode.system;
      case 1:
        return AppThemeMode.light;
      case 2:
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }

  @override
  void write(BinaryWriter writer, AppThemeMode obj) {
    switch (obj) {
      case AppThemeMode.system:
        writer.writeByte(0);
      case AppThemeMode.light:
        writer.writeByte(1);
      case AppThemeMode.dark:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppThemeModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
