import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/platform_file_picker.dart';
import '../data/database.dart';
import '../l10n/app_strings.dart';
import '../models/chat_export.dart';
import '../models/chat_models.dart';

class ChatExportResult {
  const ChatExportResult({required this.success, this.message, this.path});

  final bool success;
  final String? message;
  final String? path;
}

class ChatImportResult {
  const ChatImportResult({
    required this.success,
    this.message,
    this.importedChats = 0,
    this.importedMessages = 0,
  });

  final bool success;
  final String? message;
  final int importedChats;
  final int importedMessages;
}

class ChatExportService {
  ChatExportService({AppDatabase? database})
      : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;

  Future<ChatExportBundle> buildBundle({String? chatId, required AppStrings s}) async {
    final entries = <ChatExportEntry>[];

    if (chatId != null) {
      final chat = await _db.getChat(chatId);
      if (chat == null) {
        throw StateError(s.chatNotFound);
      }
      final messages = await _db.getMessagesByChatId(chatId);
      entries.add(ChatExportEntry(chat: chat, messages: messages));
    } else {
      final chats = await _db.getAllChats();
      for (final chat in chats) {
        final messages = await _db.getMessagesByChatId(chat.id);
        entries.add(ChatExportEntry(chat: chat, messages: messages));
      }
    }

    return ChatExportBundle(
      version: ChatExportBundle.currentVersion,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      chats: entries,
    );
  }

  String encodeBundle(ChatExportBundle bundle) {
    return const JsonEncoder.withIndent('  ').convert(bundle.toJson());
  }

  ChatExportBundle decodeBundle(String jsonStr, AppStrings s) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) {
      throw FormatException(s.invalidFileFormat);
    }
    return ChatExportBundle.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<ChatExportResult> saveToFile({
    required ChatExportBundle bundle,
    required AppStrings s,
    String? suggestedName,
  }) async {
    if (kIsWeb) {
      return ChatExportResult(
        success: false,
        message: s.saveFileWebUnsupported,
      );
    }

    final name = suggestedName ??
        'mindgrid-backup-${DateTime.now().millisecondsSinceEpoch}.json';

    final path = await PlatformFilePicker.saveFile(
      dialogTitle: s.saveBackup,
      fileName: name,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (path == null) {
      return ChatExportResult(success: false, message: s.cancelled);
    }

    final file = File(path.endsWith('.json') ? path : '$path.json');
    await file.writeAsString(encodeBundle(bundle), flush: true);

    return ChatExportResult(
      success: true,
      message: s.chatsSaved(bundle.chats.length),
      path: file.path,
    );
  }

  Future<ChatExportResult> exportAll(AppStrings s) async {
    final bundle = await buildBundle(s: s);
    if (bundle.chats.isEmpty) {
      return ChatExportResult(success: false, message: s.noChatsToExport);
    }
    return saveToFile(
      bundle: bundle,
      s: s,
      suggestedName:
          'mindgrid-all-${DateTime.now().millisecondsSinceEpoch}.json',
    );
  }

  Future<ChatExportResult> exportChat(
    String chatId,
    AppStrings s, {
    String? title,
  }) async {
    final bundle = await buildBundle(chatId: chatId, s: s);
    final raw = (title ?? 'chat').replaceAll(RegExp(r'[^\w\-]+'), '_');
    final safeTitle = raw.length > 30 ? raw.substring(0, 30) : raw;
    return saveToFile(
      bundle: bundle,
      s: s,
      suggestedName: 'mindgrid-$safeTitle.json',
    );
  }

  Future<ChatImportResult> importFromFile(
    AppStrings s, {
    bool merge = true,
  }) async {
    if (kIsWeb) {
      return ChatImportResult(
        success: false,
        message: s.importFileWebUnsupported,
      );
    }

    final result = await PlatformFilePicker.pickFiles(
      dialogTitle: s.selectBackupFile,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ChatImportResult(success: false, message: s.cancelled);
    }

    final file = result.files.first;
    String? content;
    if (file.bytes != null) {
      content = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      content = await File(file.path!).readAsString();
    }

    if (content == null || content.isEmpty) {
      return ChatImportResult(success: false, message: s.emptyOrInvalidFile);
    }

    return importFromJson(content, s, merge: merge);
  }

  Future<ChatImportResult> importFromJson(
    String jsonStr,
    AppStrings s, {
    bool merge = true,
  }) async {
    ChatExportBundle bundle;
    try {
      bundle = decodeBundle(jsonStr, s);
    } catch (e) {
      return ChatImportResult(
        success: false,
        message: s.jsonReadError(e.toString()),
      );
    }

    if (bundle.chats.isEmpty) {
      return ChatImportResult(success: false, message: s.backupHasNoChats);
    }

    if (!merge) {
      await _db.clearAllChatsOnly();
    }

    var chatCount = 0;
    var msgCount = 0;

    try {
      await _db.db.transaction((txn) async {
        for (final entry in bundle.chats) {
          var chat = entry.chat;
          if (merge) {
            final existing = await _db.getChat(chat.id);
            if (existing != null) {
              chat = Chat(
                id: '${chat.id}_import_${DateTime.now().microsecondsSinceEpoch}',
                title: chat.title,
                model: chat.model,
                createdAt: chat.createdAt,
                updatedAt: chat.updatedAt,
              );
            }
          }

          await txn.insert('chats', chat.toMap());
          chatCount++;

          for (final msg in entry.messages) {
            var message = msg.chatId == entry.chat.id
                ? msg.copyWithChatId(chat.id)
                : msg;
            if (merge) {
              message = message.copyWithImportId(
                '${message.id}_imp_${DateTime.now().microsecondsSinceEpoch}',
              );
            }
            final map = message.toMap();
            map['files'] =
                jsonEncode(message.files.map((f) => f.toMap()).toList());
            map['images'] =
                jsonEncode(message.images.map((i) => i.toMap()).toList());
            await txn.insert('messages', map);
            msgCount++;
          }
        }
      });
    } catch (e) {
      return ChatImportResult(
        success: false,
        message: s.jsonReadError(e.toString()),
      );
    }

    return ChatImportResult(
      success: true,
      message: s.chatsImported(chatCount, msgCount),
      importedChats: chatCount,
      importedMessages: msgCount,
    );
  }
}

extension _ChatMessageImport on ChatMessage {
  ChatMessage copyWithChatId(String newChatId) {
    return ChatMessage(
      id: id,
      chatId: newChatId,
      role: role,
      content: content,
      thinking: thinking,
      model: model,
      files: files,
      images: images,
      createdAt: createdAt,
    );
  }

  ChatMessage copyWithImportId(String newId) {
    return ChatMessage(
      id: newId,
      chatId: chatId,
      role: role,
      content: content,
      thinking: thinking,
      model: model,
      files: files,
      images: images,
      createdAt: createdAt,
    );
  }
}
