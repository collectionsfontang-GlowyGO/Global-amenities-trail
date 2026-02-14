import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE', // 務必填入你的真實 Key
  );
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: GlobalMap()));
}

class GlobalMap extends StatefulWidget {
  const GlobalMap({super.key});
  @override
  State<GlobalMap> createState() => _GlobalMapState();
}

class _GlobalMapState extends State<GlobalMap> {
  List<dynamic> _amenities = [];
  bool _isEmergencyActive = true;
  bool _showSearchButton = false; 
  LatLng _lastSearchPos = LatLng(48.8566, 2.3522); 
  final MapController _mapController = MapController();
  
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _activeFilters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetchNearby(48.8566, 2.3522, 13.0); 
  }

  Future<void> _fetchNearby(double lat, double lon, double zoom) async {
    setState(() {
      _showSearchButton = false;
      _lastSearchPos = LatLng(lat, lon);
    });

    try {
      double radiusKm = (20 - zoom) * 2.5; 
      if (radiusKm < 1) radiusKm = 1;
      double offset = radiusKm / 111.0;
      
      final res = await Supabase.instance.client
          .from('Friendly_Amenities')
          .select('*')
          .gte('lat', lat - offset)
          .lte('lat', lat + offset)
          .gte('lon', lon - offset)
          .lte('lon', lon + offset)
          .limit(400); 

      setState(() => _amenities = res as List);
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 標籤過濾邏輯：確保只有選中標籤的 Marker 會顯示 [cite: 2026-02-14]
    final filteredMarkers = _amenities.where((item) {
      final type = item['type']?.toString() ?? '';
      return _activeFilters.any((filter) => type.contains(filter));
    }).map((item) {
      final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
      final type = item['type'] ?? '設施';
      final bool isEmergency = type.contains('AED') || type.contains('Secours');

      if (!_isEmergencyActive && isEmergency) return null;

      return Marker(
        point: LatLng(lat, lon),
        width: isEmergency ? 16 : 10,
        height: isEmergency ? 16 : 10,
        builder: (ctx) => GestureDetector(
          onTap: () => _showDetail(type, lat, lon),
          child: Icon(
            Icons.circle, 
            color: isEmergency ? Colors.red : Colors.orange.withOpacity(0.3), 
            size: isEmergency ? 16 : 10
          ),
        ),
      );
    }).whereType<Marker>().toList();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: LatLng(48.8566, 2.3522),
              zoom: 13,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  double dist = const Distance().as(LengthUnit.Meter, _lastSearchPos, pos.center!);
                  if (dist > 1000) setState(() => _showSearchButton = true);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(markers: filteredMarkers),
            ],
          ),
          
          // 頂部標籤列：徹底移除 Checkmark (✓)
          Positioned(
            top: 50, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _labels.map((label) {
                  bool isSelected = _activeFilters.contains(label);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      showCheckmark: false, // 這裡強制設為 false，徹底移除勾選符號
                      selectedColor: Colors.orange.withOpacity(0.7),
                      backgroundColor: Colors.white.withOpacity(0.9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: StadiumBorder(side: BorderSide(
                        color: isSelected ? Colors.orange : Colors.transparent,
                      )),
                      onSelected: (val) {
                        setState(() {
                          if (val) _activeFilters.add(label);
                          else _activeFilters.remove(label);
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 視覺化搜尋按鈕 [cite: 2026-02-14]
          if (_showSearchButton)
            Positioned(
              top: 110, left: MediaQuery.of(context).size.width / 2 - 80,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.location_searching, size: 18),
                label: const Text("搜尋此區域？"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: Colors.blueAccent, 
                  shape: const StadiumBorder(),
                  elevation: 6,
                ),
                onPressed: () => _fetchNearby(_mapController.center.latitude, _mapController.center.longitude, _mapController.zoom),
              ),
            ),

          // 左側紅色「急救」按鈕 [cite: 2026-02-14]
          Positioned(
            left: 20, top: MediaQuery.of(context).size.height * 0.4,
            child: FloatingActionButton(
              onPressed: () => setState(() => _isEmergencyActive = !_isEmergencyActive),
              backgroundColor: _isEmergencyActive ? Colors.red : Colors.grey,
              child: const Icon(Icons.emergency, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(String type, double lat, double lon) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }, 
                child: const Text("導航到此處 (免費跳轉) [cite: 2026-02-12]"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
