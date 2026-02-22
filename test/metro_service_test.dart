import 'package:flutter_test/flutter_test.dart';
import 'package:metroapp_2/services/metro_service.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetroService Tests', () {
    late MetroService metroService;
    
    setUp(() {
      metroService = MetroService();
    });

    test('calculate route simple (JSON data)', () {
      metroService.parseJsonData([
        {'Station1': 'A', 'Station2': 'B', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'B', 'Station2': 'C', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'C', 'Station2': 'D', 'Line': 'Green', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'D', 'Station2': 'E', 'Line': 'Green', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
      ]);
      
      final route = metroService.findRoute('A', 'C');
      expect(route, isNotNull);
      expect(route!.totalTime, 10);
      expect(route.segments.length, 3); // A -> B -> C
      expect(route.interchangeStations, isEmpty);
    });

    test('calculate route across lines (interchange)', () {
      metroService.parseJsonData([
        {'Station1': 'A', 'Station2': 'B', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'B', 'Station2': 'C', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'X', 'Station2': 'B', 'Line': 'Green', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'B', 'Station2': 'Y', 'Line': 'Green', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
      ]);
      
      // Path: A(Blue) -> B(Blue/Green) -> Y(Green)
      final route = metroService.findRoute('A', 'Y');
      expect(route, isNotNull);
      expect(route!.totalTime, 10);
      expect(route.segments.length, 3); // A, B, Y (start + 2 segments)
      
      // Interchange should be at B
      expect(route.interchangeStations, contains('B'));
    });
    
    test('calculate route Blue -> Yellow (via Noapara)', () {
      metroService.parseJsonData([
        {'Station1': 'Dakshineswar', 'Station2': 'Baranagar', 'Line': 'Blue', 'Time': 3, 'Fare': 5, 'Is_Operational': true},
        {'Station1': 'Baranagar', 'Station2': 'Noapara', 'Line': 'Blue', 'Time': 3, 'Fare': 5, 'Is_Operational': true},
        {'Station1': 'Noapara', 'Station2': 'Dum Dum Cantt', 'Line': 'Yellow', 'Time': 4, 'Fare': 5, 'Is_Operational': true},
        {'Station1': 'Dum Dum Cantt', 'Station2': 'Jessore Road', 'Line': 'Yellow', 'Time': 3, 'Fare': 5, 'Is_Operational': true},
      ]);
      
      final route = metroService.findRoute('Dakshineswar', 'Dum Dum Cantt');
      expect(route, isNotNull);
      // Path: Dakshineswar -> Baranagar -> Noapara -> Dum Dum Cantt
      // Time: 3 + 3 + 4 = 10
      expect(route!.totalTime, 10);
      expect(route.interchangeStations, contains('Noapara'));
    });

    test('calculate route Orange -> Yellow (via Airport)', () {
      metroService.parseJsonData([
        {'Station1': 'City Center 2', 'Station2': 'Jai Hind (Airport)', 'Line': 'Orange', 'Time': 4, 'Fare': 5, 'Is_Operational': true},
        {'Station1': 'Jessore Road', 'Station2': 'Jai Hind (Airport)', 'Line': 'Yellow', 'Time': 3, 'Fare': 5, 'Is_Operational': true},
        {'Station1': 'Jai Hind (Airport)', 'Station2': 'Birati', 'Line': 'Yellow', 'Time': 4, 'Fare': 5, 'Is_Operational': true},
      ]);
      
      final route = metroService.findRoute('City Center 2', 'Birati');
      expect(route, isNotNull);
      // Path: City Center 2 -> Airport -> Birati
      // Time: 4 + 4 = 8
      expect(route!.totalTime, 8);
      expect(route.interchangeStations, contains('Jai Hind (Airport)'));
    });

    test('non-operational edge is excluded from routing', () {
      metroService.parseJsonData([
        {'Station1': 'A', 'Station2': 'B', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': true},
        {'Station1': 'B', 'Station2': 'C', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': false}, // DISABLED
        {'Station1': 'A', 'Station2': 'D', 'Line': 'Green', 'Time': 3, 'Fare': 8, 'Is_Operational': true},
        {'Station1': 'D', 'Station2': 'C', 'Line': 'Green', 'Time': 4, 'Fare': 8, 'Is_Operational': true},
      ]);

      // Direct B->C is disabled, should route via A->D->C
      final route = metroService.findRoute('A', 'C');
      expect(route, isNotNull);
      expect(route!.totalTime, 7); // 3 + 4 via Green line
      expect(route.segments.length, 3); // A -> D -> C
    });

    test('all paths disabled returns null', () {
      metroService.parseJsonData([
        {'Station1': 'A', 'Station2': 'B', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': false},
        {'Station1': 'B', 'Station2': 'C', 'Line': 'Blue', 'Time': 5, 'Fare': 10, 'Is_Operational': false},
      ]);

      final route = metroService.findRoute('A', 'C');
      expect(route, isNull); // No route available
    });
  });
}
