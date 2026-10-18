import 'dart:typed_data';

/// Synthetic protocol data, never captured sensor/health measurements.
List<int> environmentPacket({
  int temperature = 23456,
  int humidity = 56789,
  int age = 0,
  int sequence = 1,
  int status = 0,
}) {
  final data = ByteData(20)
    ..setUint8(0, 1)
    ..setUint8(1, status)
    ..setUint32(2, sequence, Endian.little)
    ..setUint32(6, age, Endian.little)
    ..setInt32(10, temperature, Endian.little)
    ..setInt32(14, humidity, Endian.little);
  return data.buffer.asUint8List().toList();
}
