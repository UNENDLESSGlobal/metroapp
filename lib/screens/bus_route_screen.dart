import 'package:flutter/material.dart';
import '../models/bus_model.dart';
import '../services/bus_service.dart';
import 'bus_tracking_screen.dart';

class BusRouteScreen extends StatefulWidget {
  const BusRouteScreen({super.key});

  @override
  State<BusRouteScreen> createState() => _BusRouteScreenState();
}

class _BusRouteScreenState extends State<BusRouteScreen> {
  final BusService _busService = BusService();
  bool _isLoading = true;
  List<String> _stopNames = [];
  
  // Selection
  String? _fromStop;
  String? _toStop;
  
  // Results
  List<BusRoute> _foundRoutes = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadBusData();
  }

  Future<void> _loadBusData() async {
    await _busService.loadData();
    setState(() {
      _stopNames = _busService.getAllStopNames();
      _isLoading = false;
    });
  }

  void _searchRoutes() {
    if (_fromStop == null || _toStop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both source and destination')),
      );
      return;
    }
    
    setState(() {
      _foundRoutes = _busService.findRoutes(_fromStop!, _toStop!);
      _hasSearched = true;
    });
  }
  
  void _swapStops() {
    setState(() {
      final temp = _fromStop;
      _fromStop = _toStop;
      _toStop = temp;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Routes'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchSection(),
                Expanded(child: _buildResultsList()),
              ],
            ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           // From field
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return _stopNames.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: (String selection) {
              setState(() => _fromStop = selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_fromStop != null && controller.text != _fromStop) {
                  controller.text = _fromStop!;
              }
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'From',
                  prefixIcon: const Icon(Icons.my_location),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          // Swap button
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: _swapStops,
              icon: const Icon(Icons.swap_vert_circle, size: 32),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 4),

          // To field
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
               if (textEditingValue.text == '') {
                return const Iterable<String>.empty();
              }
              return _stopNames.where((String option) {
                return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
             onSelected: (String selection) {
              setState(() => _toStop = selection);
            },
             fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
               if (_toStop != null && controller.text != _toStop) {
                  controller.text = _toStop!;
              }
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'To',
                  prefixIcon: const Icon(Icons.location_on),
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          ElevatedButton(
            onPressed: _searchRoutes,
            style: ElevatedButton.styleFrom(
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Find Routes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAllRoutes() {
    final allRoutes = _busService.getAllUniqueRoutes();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('All Available Buses', style: Theme.of(context).textTheme.headlineSmall),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: allRoutes.length,
                itemBuilder: (context, index) {
                    final route = allRoutes[index];
                    return ListTile(
                        leading: const Icon(Icons.directions_bus, color: Colors.blue),
                        title: Text('Bus ${route.routeNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(route.busType),
                    );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    List<Widget> children = [];

    // 1. Initial State or Empty State
    if (!_hasSearched) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Enter stops to find bus routes',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else if (_foundRoutes.isEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bus_alert, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No direct routes found.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      // 2. Results List
      children.addAll(_foundRoutes.map((route) {
        final isAC = route.busType.toUpperCase().contains('AC') && !route.busType.toUpperCase().contains('NON-AC');
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
               Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => BusTrackingScreen(route: route, destinationStop: _toStop!),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                   Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isAC ? Colors.blue.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus, 
                      color: isAC ? Colors.blue : Colors.orange,
                      size: 28,
                    ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Bus ${route.routeNo}', 
                           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           route.busType,
                           style: TextStyle(
                             color: isAC ? Colors.blue : Colors.orange.shade800,
                             fontWeight: FontWeight.w600,
                             fontSize: 12
                           ),
                         ),
                       ],
                     ),
                   ),
                   const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      }));
    }

    // 3. "View All Buses" Card (Always visible at the bottom)
    if (!_hasSearched) {
      children.add(
        Card(
          margin: const EdgeInsets.only(top: 10, bottom: 20),
          elevation: 2,
          color: Colors.grey.shade100,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _showAllRoutes,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'View All Buses',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}
