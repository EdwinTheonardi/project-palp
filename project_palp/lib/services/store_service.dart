import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreService {
  static Future<Map<String, dynamic>?> fetchStoreFromFirebase(String storeCode) async {
    print("🔍 Mencari store dengan code: $storeCode");

    final snapshot = await FirebaseFirestore.instance
        .collection('stores')
        .where('code', isEqualTo: storeCode)
        .limit(1)
        .get();

    print("🔍 Snapshot ditemukan: ${snapshot.docs.length} dokumen.");

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      print("🔥 Data ditemukan: ${doc.data()}");
      return doc.data();
    } else {
      print("❌ Store dengan code $storeCode tidak ditemukan.");
      return null;
    }
  }

  static Future<void> saveStore(String storeCode, String storeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeCode', storeCode);
    await prefs.setString('storeName', storeName);
    print("💾 Store berhasil disimpan ke local storage.");
  }

  static Future<void> initStore(String storeCode) async {
    final data = await fetchStoreFromFirebase(storeCode);
    if (data != null) {
      await saveStore(storeCode, data['name']);
    } else {
      throw Exception('Store tidak ditemukan di Firebase');
    }
  }

  static Future<String?> getStoreCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('storeCode');
  }

  static Future<String?> getStoreName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('storeName');
  }

  static Future<void> loadStoreFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    String? storeCode = prefs.getString('storeCode');
    String? storeName = prefs.getString('storeName');

    if (storeCode != null && storeName != null) {
      print("💾 Data dari local storage - Code: $storeCode, Name: $storeName");
    } else {
      print("❌ Tidak ada data store di local storage.");
    }
  }

  static Future<void> clearStore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('storeCode');
    await prefs.remove('storeName');
    print("🚪 Store logout: data dihapus dari local storage.");
  }
}
