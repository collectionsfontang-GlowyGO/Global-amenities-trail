import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://alaogviubvumpnsnwezf.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYW9ndml1YnZ1bXBuc253ZXpmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODQxODgsImV4cCI6MjA4NjQ2MDE4OH0.gBJnCOSb3NHCUtREsf8iE6tyb5FfHza8OOQ4m3Ai-fE, // 請確保使用你截圖中的完整 Key
  );
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: GlobalMap()));
}

class GlobalMap extends StatefulWidget {
  const GlobalMap({super.key});
  @override
  State<GlobalMap> createState() => _GlobalMapState();
}

class _GlobalMapState extends State<GlobalMap> {
  List<dynamic> _allData = []; // 原始全量資料
  List<dynamic> _displayData = []; // 過濾後顯示的資料
  bool _isEmergencyActive = true;
  final MapController _mapController = MapController();
  final PopupController _popupController = PopupController();

  // 標籤篩選清單
  final List<String> _labels = ['垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'];
  final Set<String> _activeFilters = {'垃圾桶', '廁所', '飲水機', '坡道', '行動裝置充電', 'wifi熱點', '熱水', '尿布台', '行人椅'};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.from('Friendly_Amenities').select('*');
      setState(() {
        _allData = res as List;
        _applyFilter();
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  // 實作標籤篩選邏輯
  void _applyFilter() {
    setState(() {
      _displayData = _allData.where((item) {
        final String type = item['type']?.toString() ?? '';
        // 簡單邏輯：如果標籤被選中，且資料 type 包含該關鍵字
        if (_activeFilters.isEmpty) return false;
        return _activeFilters.any((f) => type.contains(f)) || type.isEmpty;
      }).toList();
    });
  }

  // 免費導航策略：調用原生地圖 [cite: 2026-02-12]
  void _launchNavigation(double lat, double lon) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
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
              onTap: (_, __) => _popupController.hideAllPopups(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // 使用 MarkerClusterLayer 解決 Zapp! 跑不動的問題
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  anchor: AnchorPos.align(AnchorAlign.center),
                  fitBoundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(50)),
                  markers: _displayData.map((item) {
                    final double lat = double.parse(item['lat'].toString());
                    final double lon = double.parse(item['lon'].toString());
                    final String type = item['type'] ?? '設施';
                    final bool isEmergency = type.contains('AED') || type.contains('Secours');

                    return Marker(
                      point: LatLng(lat, lon),
                      width: isEmergency ? 16 : 10,
                      height: isEmergency ? 16 : 10,
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          // 點擊橘點彈出詳細資訊與導航按鈕
                          showModalBottomSheet(
                            context: context,
                            builder: (builder) => Container(
                              height: 150,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Text(type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () => _launchNavigation(lat, lon),
                                    child: const Text("開始導航 (免費)"),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.circle,
                          color: isEmergency ? Colors.red : Colors.orange.withOpacity(0.3),
                          size: isEmergency ? 16 : 10,
                        ),
                      ),
                    );
                  }).whereType<Marker>().toList(),
                  builder: (context, markers) => Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.orange),
                    child: Center(child: Text(markers.length.toString(), style: const TextStyle(color: Colors.white))),
                  ),
                ),
              ),
            ],
          ),
          
          // 頂部標籤列：實作點擊篩選 [cite: 2026-02-14]
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
                    onSelected: (selected) {
                      setState(() {
                        selected ? _activeFilters.add(label) : _activeFilters.remove(label);
                        _applyFilter();
                      });
                    },
                  ),
                )).toList(),
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
}
