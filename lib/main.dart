import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 Supabase
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE', // 請更換為你的真實 Key
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
  // 依照身分排序標籤，但隱藏版本名稱
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _filters = {'垃圾桶', '廁所', '飲水機', '坡道'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await Supabase.instance.client.from('Friendly_Amenities').select('*');
    setState(() => _amenities = res as List);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(center: LatLng(48.8566, 2.3522), zoom: 13),
            children: [
              TileLayer(urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'),
              MarkerLayer(
                markers: _amenities.map((item) {
                  final coords = item['coords']['coordinates'];
                  final pos = LatLng(coords[1].toDouble(), coords[0].toDouble());
                  String name = item['name'] ?? '';
                  
                  // 急救設施：紅點 (16px)
                  if (_isEmergencyActive && (name.contains('AED') || name.contains('滅火器') || name.contains('消防栓'))) {
                    return Marker(point: pos, width: 16, height: 16, child: const Icon(Icons.circle, color: Colors.red, size: 16));
                  }
                  // 友善設施：小黃點 (10px)
                  if (_filters.contains(name)) {
                    return Marker(point: pos, width: 10, height: 10, child: const Icon(Icons.circle, color: Colors.amber, size: 10));
                  }
                  return null;
                }).whereType<Marker>().toList(),
              ),
            ],
          ),
          // 頂部排序標籤列
          Positioned(
            top: 50, left: 0, right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _labels.map((name) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(name),
                    selected: _filters.contains(name),
                    onSelected: (val) => setState(() => val ? _filters.add(name) : _filters.remove(name)),
                  ),
                )).toList(),
              ),
            ),
          ),
          // 左側急救鍵
          Positioned(
            left: 20, top: MediaQuery.of(context).size.height * 0.4,
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
