Future<void> _fetch() async {
    try {
      final res = await Supabase.instance.client.from('Friendly_Amenities').select('*');
      setState(() {
        _amenities = res as List;
      });
    } catch (e) {
      debugPrint("Supabase 連線失敗，請檢查 Key 或 Table 名稱: $e");
    }
  }

  // 渲染標記邏輯
  Marker _buildMarker(dynamic item) {
    // 對齊 CSV 欄位：lat, lon
    final double lat = double.tryParse(item['lat'].toString()) ?? 0.0;
    final double lon = double.tryParse(item['lon'].toString()) ?? 0.0;
    final String amenityType = item['amenity'] ?? '';
    final String emergencyType = item['emergency'] ?? '';

    // 🔴 急救設施 (16px 紅點)
    if (emergencyType.isNotEmpty) {
      return Marker(
        point: LatLng(lat, lon), width: 16, height: 16,
        builder: (ctx) => const Icon(Icons.circle, color: Colors.red, size: 16),
      );
    }

    // 🟡 友善設施 (10px 小黃點)
    return Marker(
      point: LatLng(lat, lon), width: 10, height: 10,
      builder: (ctx) => const Icon(Icons.circle, color: Colors.amber, size: 10),
    );
  }

// 渲染標記邏輯
  Marker _buildMarker(dynamic item) {
    final double lat = double.tryParse(item['lat'].toString()) ?? 0.0;
    final double lon = double.tryParse(item['lon'].toString()) ?? 0.0;
    final String emergencyType = item['emergency'] ?? '';

    // 🔴 急救設施：維持 16px 不透明紅點，確保危急時易於辨識
    if (emergencyType.isNotEmpty) {
      return Marker(
        point: LatLng(lat, lon), width: 16, height: 16,
        builder: (ctx) => const Icon(Icons.circle, color: Colors.red, size: 16),
      );
    }

    // 🟠 友善設施：改為 10px 小橘點，透明度 0.3
    return Marker(
      point: LatLng(lat, lon), width: 10, height: 10,
      builder: (ctx) => Icon(
        Icons.circle, 
        color: Colors.orange.withOpacity(0.3), // 橘色且 30% 透明度
        size: 10,
      ),
    );
  }
