import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 請務必確認這裡已填入你正確的 Supabase URL 與 Anon Key
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE', 
  );
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, 
    home: GlobalMap(),
  ));
}

class GlobalMap extends StatefulWidget {
  const GlobalMap({super.key});
  @override
  State<GlobalMap> createState() => _GlobalMapState();
}

class _GlobalMapState extends State<GlobalMap> {
  List<dynamic> _amenities = [];
  bool _isEmergencyActive = true; 
  
  // 設施清單與預設過濾（包含普及、育兒、銀髮設施）
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _filters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.from('Friendly_Amenities').select('*');
      setState(() => _amenities = res as List);
    } catch (e) {
      debugPrint("Supabase Fetch Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: LatLng(48.8566, 2.3522), // 預設中心：巴黎
              zoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _amenities.map((item) {
                  // 解析座標 (對齊 CSV 欄位 lat, lon)
                  final double lat = double.tryParse(item['lat'].toString()) ?? 0.0;
                  final double lon = double.tryParse(item['lon'].toString()) ?? 0.0;
                  final pos = LatLng(lat, lon);
                  
                  final String name = item['name'] ?? '';
                  final String amenity = item['amenity'] ?? '';
                  final String emergency = item['emergency'] ?? '';

                  // 🔴 急救設施：16px 不透明紅點 (AED, 滅火器, 消防栓)
                  if (_isEmergencyActive && (emergency.isNotEmpty || name.contains('AED'))) {
                    return Marker(
                      point: pos, width: 16, height: 16,
                      builder: (ctx) => const Icon(Icons.circle, color: Colors.red, size: 16),
                    );
                  }

                  // 🟠 友善設施：10px 小橘點, 透明度 30% (符合最新指令)
                  return Marker(
                    point: pos, width: 10, height: 10,
                    builder: (ctx) => Icon(
                      Icons.circle, 
                      color: Colors.orange.withOpacity(0.3), 
                      size: 10,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          
          // 頂部標籤列 (隱藏版本名稱，僅顯示設施)
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
                    selected: _filters.contains(label),
                    selectedColor: Colors.orange.withOpacity(0.5),
                    onSelected: (val) => setState(() => val ? _filters.add(label) : _filters.remove(label)),
                  ),
                )).toList(),
              ),
            ),
          ),

          // 左側明顯位置：紅色「急救」按鈕
          Positioned(
            left: 20, 
            top: MediaQuery.of(context).size.height * 0.4,
            child: FloatingActionButton.extended(
              onPressed: () => setState(() => _isEmergencyActive = !_isEmergencyActive),
              backgroundColor: _isEmergencyActive ? Colors.red : Colors.grey,
              icon: const Icon(Icons.emergency, color: Colors.white),
              label: const Text("急救", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
