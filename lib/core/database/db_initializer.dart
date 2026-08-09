import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 将 assets/cet4.db 复制到应用文档目录（首次启动时）
class DatabaseInitializer {
  static const String _assetDbName = 'assets/cet4.db';
  static const String _dbFileName = 'cet4_user.db';

  static Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// 初始化词库：如果文档目录没有，则从 assets 复制
  static Future<void> initialize() async {
    final dbPath = await databasePath;
    final file = File(dbPath);

    if (await file.exists()) return;

    try {
      final data = await rootBundle.load(_assetDbName);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw Exception('词库文件复制失败，请重试: $e');
    }
  }
}
