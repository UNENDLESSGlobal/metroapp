import 'transport_mode.dart';

/// Model representing a trip
class Trip {
  final String id;
  final TransportMode transportMode;
  final String city;
  final String startStation;
  final String endStation;
  final DateTime date;
  final double? fare;
  final int? durationMinutes;

  Trip({
    required this.id,
    required this.transportMode,
    required this.city,
    required this.startStation,
    required this.endStation,
    required this.date,
    this.fare,
    this.durationMinutes,
  });

  /// Create a Trip from CSV row
  factory Trip.fromCsvRow(List<dynamic> row) {
    return Trip(
      id: row[0].toString(),
      transportMode: TransportMode.fromString(row[1].toString()),
      city: row[2].toString(),
      startStation: row[3].toString(),
      endStation: row[4].toString(),
      date: DateTime.parse(row[5].toString()),
      fare: row.length > 6 && row[6] != null && row[6].toString().isNotEmpty
          ? double.tryParse(row[6].toString())
          : null,
      durationMinutes: row.length > 7 && row[7] != null && row[7].toString().isNotEmpty
          ? int.tryParse(row[7].toString())
          : null,
    );
  }

  /// Convert Trip to CSV row
  List<dynamic> toCsvRow() {
    return [
      id,
      transportMode.name,
      city,
      startStation,
      endStation,
      date.toIso8601String(),
      fare?.toString() ?? '',
      durationMinutes?.toString() ?? '',
    ];
  }

  /// CSV header row
  static List<String> get csvHeader => [
        'id',
        'transport_mode',
        'city',
        'start_station',
        'end_station',
        'date',
        'fare',
        'duration_minutes',
      ];

  /// Create a copy with updated fields
  Trip copyWith({
    String? id,
    TransportMode? transportMode,
    String? city,
    String? startStation,
    String? endStation,
    DateTime? date,
    double? fare,
    int? durationMinutes,
  }) {
    return Trip(
      id: id ?? this.id,
      transportMode: transportMode ?? this.transportMode,
      city: city ?? this.city,
      startStation: startStation ?? this.startStation,
      endStation: endStation ?? this.endStation,
      date: date ?? this.date,
      fare: fare ?? this.fare,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  /// Generate a unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Format the date for display
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format fare for display
  String get formattedFare {
    if (fare == null) return '-';
    return '₹${fare!.toStringAsFixed(2)}';
  }

  /// Format duration for display
  String get formattedDuration {
    if (durationMinutes == null) return '-';
    if (durationMinutes! < 60) return '${durationMinutes}min';
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    return '${hours}h ${minutes}min';
  }

  @override
  String toString() {
    return 'Trip(id: $id, mode: ${transportMode.displayName}, $startStation → $endStation)';
  }
}
