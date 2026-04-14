/// Represents a single sensor reading row from the `sensor_readings` table.
///
/// Columns: id, device_id, sensor_type, numeric_value, unit, recorded_at
class SensorReading {
  final String id;
  final String? deviceId;
  final String sensorType; // temperature, humidity, smoke, water
  final double value;
  final String unit; // C, %, status, ppm
  final DateTime recordedAt;

  const SensorReading({
    required this.id,
    this.deviceId,
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.recordedAt,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString(),
      sensorType: json['sensor_type']?.toString() ?? '',
      value: (json['numeric_value'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString() ?? '',
      recordedAt:
          DateTime.tryParse(json['recorded_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  bool get isAlert {
    switch (sensorType) {
      case 'smoke':
        return value > 0;
      case 'water':
        // water 1 = wet (good), 0 = dry (needs watering)
        return value == 0;
      default:
        return false;
    }
  }

  @override
  String toString() =>
      'SensorReading($sensorType: $value$unit at $recordedAt)';
}
