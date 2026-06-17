import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_settings.dart';
import '../models/chat_models.dart';
import '../models/prompt_config.dart';
import '../l10n/app_locale.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  @visibleForTesting
  factory AppDatabase.test() => AppDatabase._();

  Database? _db;
  static bool _ffiInitialized = false;

  static Future<void> _ensureFfi() async {
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      if (!_ffiInitialized) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        _ffiInitialized = true;
      }
    }
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE chats (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        model TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        chatId TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        thinking TEXT,
        model TEXT,
        files TEXT,
        images TEXT,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE user_info (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_messages_chat ON messages(chatId, createdAt)',
    );
    await db.execute(
      'CREATE INDEX idx_chats_updated ON chats(updatedAt DESC)',
    );
  }

  Future<void> init() async {
    if (_db != null) return;

    await _ensureFfi();

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'mindgrid.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN images TEXT');
        }
      },
    );
  }

  @visibleForTesting
  Future<void> initInMemory() async {
    if (_db != null) return;
    await _ensureFfi();
    _db = await openDatabase(
      '${inMemoryDatabasePath}_${DateTime.now().microsecondsSinceEpoch}',
      version: 2,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN images TEXT');
        }
      },
    );
  }

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Database not initialized');
    }
    return database;
  }

  Future<void> createChat(Chat chat) async {
    await db.insert('chats', chat.toMap());
  }

  Future<void> updateChat(Chat chat) async {
    await db.update('chats', chat.toMap(), where: 'id = ?', whereArgs: [chat.id]);
  }

  Future<Chat?> getChat(String id) async {
    final rows = await db.query('chats', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Chat.fromMap(rows.first);
  }

  Future<List<Chat>> getAllChats() async {
    final rows = await db.query('chats', orderBy: 'updatedAt DESC');
    return rows.map((r) => Chat.fromMap(r)).toList();
  }

  Future<void> deleteChat(String id) async {
    await db.delete('chats', where: 'id = ?', whereArgs: [id]);
    await db.delete('messages', where: 'chatId = ?', whereArgs: [id]);
  }

  Future<void> addMessage(ChatMessage message) async {
    final map = message.toMap();
    map['files'] = jsonEncode(message.files.map((f) => f.toMap()).toList());
    map['images'] = jsonEncode(message.images.map((i) => i.toMap()).toList());
    await db.insert('messages', map);
  }

  Future<List<String>> getRecentUserMessages({int limit = 20}) async {
    final rows = await db.query(
      'messages',
      columns: ['content'],
      where: "role = 'user'",
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows
        .map((r) => (r['content'] as String? ?? '').trim())
        .where((c) => c.isNotEmpty)
        .toList()
        .reversed
        .toList();
  }

  Future<List<ChatMessage>> getMessagesByChatId(String chatId) async {
    final rows = await db.query(
      'messages',
      where: 'chatId = ?',
      whereArgs: [chatId],
      orderBy: 'createdAt ASC',
    );
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final filesRaw = map['files'] as String?;
      if (filesRaw != null && filesRaw.isNotEmpty) {
        final decoded = jsonDecode(filesRaw);
        map['files'] = decoded;
      } else {
        map['files'] = [];
      }
      final imagesRaw = map['images'] as String?;
      if (imagesRaw != null && imagesRaw.isNotEmpty) {
        final decoded = jsonDecode(imagesRaw);
        map['images'] = decoded;
      } else {
        map['images'] = [];
      }
      return ChatMessage.fromMap(map);
    }).toList();
  }

  Future<void> clearMessages(String chatId) async {
    await db.delete('messages', where: 'chatId = ?', whereArgs: [chatId]);
  }

  Future<void> deleteMessage(String id) async {
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMessage(ChatMessage message) async {
    final map = message.toMap();
    map['files'] = jsonEncode(message.files.map((f) => f.toMap()).toList());
    map['images'] = jsonEncode(message.images.map((i) => i.toMap()).toList());
    await db.update('messages', map, where: 'id = ?', whereArgs: [message.id]);
  }

  Future<String> getUserInfo() async {
    final rows = await db.query(
      'user_info',
      where: 'key = ?',
      whereArgs: ['profile'],
    );
    if (rows.isEmpty) return '';
    return rows.first['value'] as String? ?? '';
  }

  Future<void> setUserInfo(String value) async {
    await db.insert(
      'user_info',
      {'key': 'profile', 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSetting(String key, Object? value) async {
    await db.insert(
      'settings',
      {'key': key, 'value': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Object?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['value'] as String);
  }

  Future<AppSettings> getAllSettings() async {
    final defaults = AppSettings().toMap();
    final result = <String, dynamic>{};
    for (final key in defaults.keys) {
      final val = await getSetting(key);
      result[key] = val ?? defaults[key];
    }
    return AppSettings.fromMap(result);
  }

  Future<void> saveSettings(AppSettings settings) async {
    for (final entry in settings.toMap().entries) {
      await setSetting(entry.key, entry.value);
    }
  }

  Future<void> clearAllChatsOnly() async {
    await db.delete('chats');
    await db.delete('messages');
  }

  Future<void> clearAll() async {
    await clearAllChatsOnly();
    await db.delete('settings');
    await db.delete('user_info');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('prompt_cfg');
  }

  Future<PromptConfig> loadPromptConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('prompt_cfg');
    if (raw == null) return const PromptConfig();
    try {
      return PromptConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const PromptConfig();
    }
  }

  Future<void> savePromptConfig(PromptConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('prompt_cfg', jsonEncode(config.toJson()));
  }

  Future<AppLocale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLocale.fromCode(prefs.getString('app_locale'));
  }

  Future<void> setLocale(AppLocale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.code);
  }
}
