// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'committee.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommitteeAdapter extends TypeAdapter<Committee> {
  @override
  final int typeId = 0;

  @override
  Committee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Committee(
      id: fields[0] as String,
      code: fields[1] as String,
      name: fields[2] as String,
      hostId: fields[3] as String,
      contributionAmount: fields[4] as double,
      frequency: fields[5] as String,
      startDate: fields[6] as DateTime,
      totalMembers: fields[7] as int,
      createdAt: fields[8] as DateTime,
      isActive: fields[9] as bool,
      paymentIntervalDays: fields[10] as int,
      isArchived: fields[11] as bool,
      archivedAt: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Committee obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.code)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.hostId)
      ..writeByte(4)
      ..write(obj.contributionAmount)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.totalMembers)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.paymentIntervalDays)
      ..writeByte(11)
      ..write(obj.isArchived)
      ..writeByte(12)
      ..write(obj.archivedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommitteeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
