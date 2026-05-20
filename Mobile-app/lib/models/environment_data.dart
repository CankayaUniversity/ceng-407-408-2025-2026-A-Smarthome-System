/// Represents a single sensor reading row from the `sensor_readings` table.
///
/// Columns: id, device_id, sensor_type, numeric_value, unit, recorded_at
class SensorReading {
  final String id;
  final String? deviceId;
  final String sensorType; // temperature, humidity, smoke, soil_moisture (legacy: water)
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

  String get normalizedType =>
      sensorType == 'water' ? 'soil_moisture' : sensorType;

  bool get isAlert {
    switch (normalizedType) {
      case 'smoke':
        return value > 0;
      case 'soil_moisture':
        // 1 = dry soil (needs watering), 0 = moist
        return value >= 0.5;
      default:
        return false;
    }
  }

  String get displayLabel {
    if (normalizedType == 'soil_moisture') {
      return value >= 0.5 ? 'Dry' : 'Moist';
    }
    return value.toStringAsFixed(1);
  }

  @override
  String toString() => 'SensorReading($sensorType: $value$unit at $recordedAt)';
}
