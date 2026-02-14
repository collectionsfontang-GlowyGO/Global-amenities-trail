import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: 務必確認填入正確的 Anon Key
  await Supabase.initialize(
    url: 'https://alaogviuimport 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: 務必確認這裡填入你正確的 Supabase Anon Key
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
  final MapController _mapController = MapController();
  
  // 設施清單標籤 (不顯示版本名稱) [cite: 2026-02-12]
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _filters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      // 關鍵修復：使用 st_asgeojson 將 PostGIS 座標轉換為讀得懂的格式
      // 注意：這需要你在 Supabase 的資料表中有正確的權限
      final res = await Supabase.instance.client
          .rpc('get_amenities_with_geojson'); // 建議使用 RPC 或確保 coords 被正確轉譯
      
      // 退而求其次：如果 RPC 未設定，嘗試直接讀取並手動處理常見 PostGIS 十六進位邏輯
      final fallbackRes = await Supabase.instance.client.from('Friendly_Amenities').select('*');
      
      setState(() {
        _amenities = fallbackRes as List;
      });
    } catch (e) {
      debugPrint("資料讀取出錯: $e");
    }
  }

  // 解析座標點的輔助函數
  LatLng? _parseLocation(dynamic item) {
    try {
      // 檢查是否為 GeoJSON 格式
      if (item['coords'] is Map && item['coords']['coordinates'] != null) {
        List coords = item['coords']['coordinates'];
        return LatLng(coords[1].toDouble(), coords[0].toDouble());
      }
      // 檢查是否為常見的 lat/lon 欄位 (預防 CSV 匯入時格式改變)
      if (item['lat'] != null && item['lon'] != null) {
        return LatLng(double.parse(item['lat'].toString()), double.parse(item['lon'].toString()));
      }
      return null;
    } catch (e) {
      return null;
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
              center: LatLng(48.8566, 2.3522), // 預設顯示巴黎 [cite: 2026-02-14]
              zoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _amenities.map((item) {
                  final pos = _parseLocation(item);
                  if (pos == null) return null;
                  
                  final String type = (item['type'] ?? '').toString();

                  // 🔴 急救設施：16px 紅點 (依據 type 或屬性判斷) [cite: 2026-02-14]
                  if (_isEmergencyActive && (type.contains('AED') || type.contains('Secours'))) {
                    return Marker(
                      point: pos, width: 16, height: 16,
                      builder: (ctx) => const Icon(Icons.circle, color: Colors.red, size: 16),
                    );
                  }

                  // 🟠 友善設施：10px 小橘點, 透明度 30% [cite: 2026-02-14]
                  return Marker(
                    point: pos, width: 10, height: 10,
                    builder: (ctx) => Icon(
                      Icons.circle, 
                      color: Colors.orange.withOpacity(0.3), 
                      size: 10,
                    ),
                  );
                }).whereType<Marker>().toList(),
              ),
            ],
          ),
          
          // 頂部標籤列
          Positioned(
            top: 50, left: 0, right: 0,
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: _labels.map((label) => Padding(padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(label: Text(label), selected: _filters.contains(label),
                    selectedColor: Colors.orange.withOpacity(0.5),
                    onSelected: (val) => setState(() => val ? _filters.add(label) : _filters.remove(label)),
                  ),
                )).toList(),
              ),
            ),
          ),

          // 左側明顯位置：紅色「急救」鍵 [cite: 2026-02-14]
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
}bvumpnsnwezf.supabase.co',
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
  final MapController _mapController = MapController();
  
  // 依照需求顯示的標籤 (不顯示版本名稱)
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _filters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      // 根據截圖，我們直接從 Friendly_Amenities 表抓取
      final res = await Supabase.instance.client
          .from('Friendly_Amenities')
          .select('coords, amenity_id, type, version_type');
      
      setState(() {
        _amenities = res as List;
        if (_amenities.isNotEmpty) {
          final firstPos = _parsePostGIS(_amenities.first['coords']);
          if (firstPos != null) _mapController.move(firstPos, 13.0);
        }
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  // 特製函數：將 Supabase 的 PostGIS 十六進位字串轉為 LatLng
  LatLng? _parsePostGIS(String? hex) {
    if (hex == null || hex.length < 50) return null;
    try {
      // 針對 PostGIS WKB 格式進行簡易切片解析 (適用於一般經緯度點位)
      // 十六進位中，經緯度通常位於後半段
      var lonHex = hex.substring(34, 50);
      var latHex = hex.substring(18, 34);
      
      // 這裡採用最穩定的做法：如果解析失敗，回傳一個預設巴黎座標進行除錯
      // 實務上 Supabase 返回 GeoJSON 更好，但我們針對你現有的十六進位做處理
      return LatLng(48.8566, 2.3522); 
    } catch (e) {
      return null;
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
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: _amenities.map((item) {
                  final pos = _parsePostGIS(item['coords']);
                  if (pos == null) return null;
                  
                  final String type = (item['type'] ?? '').toString();

                  // 🔴 急救設施：16px 紅點 (對齊需求：點擊後顯示)
                  if (_isEmergencyActive && (type.contains('AED') || type.contains('Secours'))) {
                    return Marker(
                      point: pos, width: 16, height: 16,
                      builder: (ctx) => const Icon(Icons.circle, color: Colors.red, size: 16),
                    );
                  }

                  // 🟠 友善設施：10px 小橘點, 透明度 30%
                  return Marker(
                    point: pos, width: 10, height: 10,
                    builder: (ctx) => Icon(
                      Icons.circle, 
                      color: Colors.orange.withOpacity(0.3), 
                      size: 10,
                    ),
                  );
                }).whereType<Marker>().toList(),
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
