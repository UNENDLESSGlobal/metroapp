
class BusStop {
  final String name;
  final double latitude;
  final double longitude;

  BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() => '$name ($latitude, $longitude)';
}

class BusRoute {
  final String routeNo;
  final String busType;
  final List<BusStop> stops;

  BusRoute({
    required this.routeNo,
    required this.busType,
    required this.stops,
  });
}
