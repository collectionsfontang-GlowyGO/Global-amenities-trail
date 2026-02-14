import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE', 
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
  bool _isEmergencyActive = false; 
  bool _showSearchButton = false; 
  LatLng _lastSearchPos = LatLng(48.8566, 2.3522); 
  final MapController _mapController = MapController();
  Timer? _debounce; 

  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  
  // 核心 1：預設不選取任何設施，地圖保持空白
  final Set<String> _activeFilters = {};

  Future<void> _fetchNearby(double lat, double lon) async {
    if (!mounted) return;
    setState(() {
      _showSearchButton = false;
      _lastSearchPos = LatLng(lat, lon);
    });

    try {
      // 搜尋視野中心 5km 內的所有設施
      const double offset = 5.0 / 111.0; 
      final res = await Supabase.instance.client
          .from('Friendly_Amenities')
          .select('*')
          .gte('lat', lat - offset)
          .lte('lat', lat + offset)
          .gte('lon', lon - offset)
          .lte('lon', lon + offset);

      if (mounted) setState(() => _amenities = res as List);
    } catch (e) {
      debugPrint("資料讀取錯誤: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    // 初始不執行搜尋，確保地圖預設為空
  }

  @override
  Widget build(BuildContext context) {
    // 過濾 Marker：實心橘點，移除光暈 [cite: 2026-02-14]
    final filteredMarkers = _amenities.where((item) {
      final type = item['type']?.toString() ?? '';
      final bool isEmergency = type.contains('AED') || type.contains('Secours');
      bool matchesFilter = _activeFilters.any((filter) => type.contains(filter));
      if (isEmergency) return _isEmergencyActive;
      return matchesFilter;
    }).map((item) {
      final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
      final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
      final type = item['type'] ?? '設施';
      final bool isEmergency = type.contains('AED') || type.contains('Secours');

      return Marker(
        point: LatLng(lat, lon),
        width: 12, height: 12,
        builder: (ctx) => GestureDetector(
          onTap: () => _showDetail(type, lat, lon),
          child: Container(
            decoration: BoxDecoration(
              color: isEmergency ? Colors.red : Colors.orange, 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      );
    }).toList();

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
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    double dist = const Distance().as(LengthUnit.Meter, _lastSearchPos, pos.center!);
                    if (dist > 800 && (_activeFilters.isNotEmpty || _isEmergencyActive)) {
                      setState(() => _showSearchButton = true);
                    }
                  });
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
          
          // 核心 2：自定義標籤列 - 絕無勾選框 (NO CHECKMARK)
          Positioned(
            top: 50, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _labels.map((label) {
                  bool isSelected = _activeFilters.contains(label);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _activeFilters.remove(label);
                        } else {
                          _activeFilters.add(label);
                          // 第一次啟用標籤時抓取 5km 資料 [cite: 2026-02-14]
                          if (_amenities.isEmpty) _fetchNearby(_mapController.center.latitude, _mapController.center.longitude);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                        border: Border.all(color: isSelected ? Colors.orange : Colors.transparent),
                      ),
                      child: Text(
                        label, 
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          if (_showSearchButton)
            Positioned(
              top: 110, left: MediaQuery.of(context).size.width / 2 - 80,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("搜尋此區域"),
                style: ElevatedButton.styleFrom(
                  shape: const StadiumBorder(), 
                  backgroundColor: Colors.white, 
                  foregroundColor: Colors.orange,
                  elevation: 5,
                ),
                onPressed: () => _fetchNearby(_mapController.center.latitude, _mapController.center.longitude),
              ),
            ),

          // 左側紅色「急救」按鈕 [cite: 2026-02-14]
          Positioned(
            left: 20, top: MediaQuery.of(context).size.height * 0.4,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isEmergencyActive = !_isEmergencyActive;
                  if (_isEmergencyActive && _amenities.isEmpty) {
                    _fetchNearby(_mapController.center.latitude, _mapController.center.longitude);
                  }
                });
              },
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
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () async {
                  final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }, 
                child: const Text("免費導航到此 [cite: 2026-02-12]"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
