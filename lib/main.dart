import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE', // 請填入你的真實 Key
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
  bool _showSearchButton = false; // 是否顯示「搜尋此區域」按鈕
  LatLng? _lastSearchPos; // 上次搜尋的位置
  final MapController _mapController = MapController();
  
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _activeFilters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetchNearby(48.8566, 2.3522, 13.0); 
  }

  // 根據縮放級別動態調整搜尋半徑 (Thrifty 邏輯)
  Future<void> _fetchNearby(double lat, double lon, double zoom) async {
    setState(() => _showSearchButton = false);
    _lastSearchPos = LatLng(lat, lon);

    try {
      // 縮放層級愈小（看愈遠），搜尋半徑愈大。
      // Zoom 13 約 5km, Zoom 11 約 15km
      double radiusKm = (20 - zoom) * 2.5; 
      if (radiusKm < 2) radiusKm = 2;
      double offset = radiusKm / 111.0;
      
      final res = await Supabase.instance.client
          .from('Friendly_Amenities')
          .select('*')
          .filter('lat', 'not.is', null)
          .gte('lat', lat - offset)
          .lte('lat', lat + offset)
          .gte('lon', lon - offset)
          .lte('lon', lon + offset);

      setState(() => _amenities = res as List);
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  // 如果位移超過一定距離，顯示「搜尋此區域」按鈕
                  double dist = const Distance().as(LengthUnit.Meter, _lastSearchPos!, pos.center!);
                  if (dist > 1000 || (pos.zoom! - _mapController.zoom).abs() > 0.5) {
                    setState(() => _showSearchButton = true);
                  }
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _amenities.where((item) {
                  final type = item['type']?.toString() ?? '';
                  return _activeFilters.any((f) => type.contains(f));
                }).map((item) {
                  final lat = double.parse(item['lat'].toString());
                  final lon = double.parse(item['lon'].toString());
                  final type = item['type'] ?? '設施';
                  final bool isEmergency = type.contains('AED') || type.contains('Secours');

                  return Marker(
                    point: LatLng(lat, lon),
                    width: isEmergency ? 16 : 10, height: 16,
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showDetail(type, lat, lon),
                      child: Icon(Icons.circle, color: isEmergency ? Colors.red : Colors.orange.withOpacity(0.3), size: isEmergency ? 16 : 10),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // 頂部標籤列
          Positioned(
            top: 50, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _labels.map((label) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: _activeFilters.contains(label),
                    selectedColor: Colors.orange.withOpacity(0.5),
                    onSelected: (val) => setState(() {
                      val ? _activeFilters.add(label) : _activeFilters.remove(label);
                    }),
                  ),
                )).toList(),
              ),
            ),
          ),

          // 核心優化：詢問「搜尋此區域？」按鈕
          if (_showSearchButton)
            Positioned(
              top: 110, left: MediaQuery.of(context).size.width / 2 - 80,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search, size: 18),
                label: const Text("搜尋此區域？", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueAccent,
                  shape: StadiumBorder(),
                  elevation: 4,
                ),
                onPressed: () => _fetchNearby(
                  _mapController.center.latitude, 
                  _mapController.center.longitude, 
                  _mapController.zoom
                ),
              ),
            ),

          // 左側紅色「急救」鍵 [cite: 2026-02-14]
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () async {
                final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                if (await canLaunchUrl(url)) await launchUrl(url);
              }, 
              child: const Text("開始導航 (完全免費) [cite: 2026-02-12]")
            ),
          ],
        ),
      ),
    );
  }
}
