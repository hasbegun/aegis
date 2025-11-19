// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanHistoryItemAdapter extends TypeAdapter<ScanHistoryItem> {
  @override
  final int typeId = 1;

  @override
  ScanHistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanHistoryItem(
      scanId: fields[0] as String,
      targetType: fields[1] as String,
      targetName: fields[2] as String,
      probes: (fields[3] as List).cast<String>(),
      passed: fields[4] as int,
      failed: fields[5] as int,
      passRate: fields[6] as double,
      status: fields[7] as String,
      createdAt: fields[8] as DateTime,
      completedAt: fields[9] as DateTime?,
      duration: fields[10] as double?,
      generations: fields[11] as int,
      evalThreshold: fields[12] as double,
      fullResults: (fields[13] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, ScanHistoryItem obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.scanId)
      ..writeByte(1)
      ..write(obj.targetType)
      ..writeByte(2)
      ..write(obj.targetName)
      ..writeByte(3)
      ..write(obj.probes)
      ..writeByte(4)
      ..write(obj.passed)
      ..writeByte(5)
      ..write(obj.failed)
      ..writeByte(6)
      ..write(obj.passRate)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.duration)
      ..writeByte(11)
      ..write(obj.generations)
      ..writeByte(12)
      ..write(obj.evalThreshold)
      ..writeByte(13)
      ..write(obj.fullResults);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanHistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScanHistoryItem _$ScanHistoryItemFromJson(Map<String, dynamic> json) =>
    ScanHistoryItem(
      scanId: json['scanId'] as String,
      targetType: json['targetType'] as String,
      targetName: json['targetName'] as String,
      probes:
          (json['probes'] as List<dynamic>).map((e) => e as String).toList(),
      passed: (json['passed'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      passRate: (json['passRate'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      duration: (json['duration'] as num?)?.toDouble(),
      generations: (json['generations'] as num).toInt(),
      evalThreshold: (json['evalThreshold'] as num).toDouble(),
      fullResults: json['fullResults'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$ScanHistoryItemToJson(ScanHistoryItem instance) =>
    <String, dynamic>{
      'scanId': instance.scanId,
      'targetType': instance.targetType,
      'targetName': instance.targetName,
      'probes': instance.probes,
      'passed': instance.passed,
      'failed': instance.failed,
      'passRate': instance.passRate,
      'status': instance.status,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'duration': instance.duration,
      'generations': instance.generations,
      'evalThreshold': instance.evalThreshold,
      'fullResults': instance.fullResults,
    };
