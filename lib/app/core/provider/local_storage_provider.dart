import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorage {
  static final provider = Provider<LocalStorage>((ref) => LocalStorage());

  final String boxName;

  LocalStorage({this.boxName = "lms"});

  Future<String?> getString(String key) async {
    if (!isInitialized) {
      await initialize();
    }

    String? value = box!.get(key);
    return value?.toString();
  }

  Future<void> setString(String key, String? value) async {
    if (!isInitialized) {
      await initialize();
    }

    await box!.put(key, value);
  }

  Box? box;

  bool isInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final dir = await getApplicationSupportDirectory();
      Hive.init("${dir.path}1");
    }

    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    box = Hive.box(boxName);
    isInitialized = true;
  }
}
