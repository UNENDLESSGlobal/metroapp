import 'package:flutter_test/flutter_test.dart';
import 'package:metroapp_2/services/metro_service.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MetroService Tests', () {
    late MetroService metroService;
    
    setUp(() {
      metroService = MetroService();
    });

    test('calculate route simple', () {
      const String csvData = '''Station1,Station2,Line,Time,Fare
A,B,Blue,5,10
B,C,Blue,5,10
C,D,Green,5,10
D,E,Green,5,10''';
      
      metroService.parseCsv(csvData);
      
      final route = metroService.findRoute('A', 'C');
      expect(route, isNotNull);
      expect(route!.totalTime, 10);
      expect(route.segments.length, 3); // A -> B -> C
      expect(route.interchangeStations, isEmpty);
    });

    test('calculate route across lines (interchange)', () {
       // Mock data representing two lines meeting at 'B'
       const String blueLineChunk = '''Station1,Station2,Line,Time,Fare
A,B,Blue,5,10
B,C,Blue,5,10''';
       
       const String greenLineChunk = '''Station1,Station2,Line,Time,Fare
X,B,Green,5,10
B,Y,Green,5,10''';
      
      // Simulate loading multiple files by calling parseCsv twice
      metroService.parseCsv(blueLineChunk);
      metroService.parseCsv(greenLineChunk);
      
      // Path: A(Blue) -> B(Blue/Green) -> Y(Green)
      // Total nodes: 3
      // Total time: 5 (A->B) + 5 (B->Y) = 10
      
      final route = metroService.findRoute('A', 'Y');
      expect(route, isNotNull);
      expect(route!.totalTime, 10);
      expect(route.segments.length, 3); // A, B, Y (start + 2 segments)
      
      // Interchange should be at B
      expect(route.interchangeStations, contains('B'));
    });
    
    test('calculate route Blue -> Yellow (via Noapara)', () {
       const String blueLineChunk = '''Station1,Station2,Line,Time,Fare
Dakshineswar,Baranagar,Blue,3,5
Baranagar,Noapara,Blue,3,5''';
       
       const String yellowLineChunk = '''Station1,Station2,Line,Time,Fare
Noapara,Dum Dum Cantt,Yellow,4,5
Dum Dum Cantt,Jessore Road,Yellow,3,5''';
      
      metroService.parseCsv(blueLineChunk);
      metroService.parseCsv(yellowLineChunk);
      
      final route = metroService.findRoute('Dakshineswar', 'Dum Dum Cantt');
      expect(route, isNotNull);
      // Path: Dakshineswar -> Baranagar -> Noapara -> Dum Dum Cantt
      // Time: 3 + 3 + 4 = 10
      expect(route!.totalTime, 10);
      expect(route.interchangeStations, contains('Noapara'));
    });

    test('calculate route Orange -> Yellow (via Airport)', () {
       const String orangeLineChunk = '''Station1,Station2,Line,Time,Fare
City Center 2,Jai Hind (Airport),Orange,4,5''';
       
       const String yellowLineChunk = '''Station1,Station2,Line,Time,Fare
Jessore Road,Jai Hind (Airport),Yellow,3,5
Jai Hind (Airport),Birati,Yellow,4,5''';
      
      metroService.parseCsv(orangeLineChunk);
      metroService.parseCsv(yellowLineChunk);
      
      final route = metroService.findRoute('City Center 2', 'Birati');
      expect(route, isNotNull);
      // Path: City Center 2 -> Airport -> Birati
      // Time: 4 + 4 = 8
      expect(route!.totalTime, 8);
      expect(route.interchangeStations, contains('Jai Hind (Airport)'));
    });
  });
}
