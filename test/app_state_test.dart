import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/data/database.dart';
import 'package:mindgrid/models/app_settings.dart';
import 'package:mindgrid/models/chat_models.dart';
import 'package:mindgrid/services/extract_service.dart';
import 'package:mindgrid/services/llm_client.dart';
import 'package:mindgrid/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/fake_llm_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeLlmClient llm;
  AppState? activeState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.test();
    await db.initInMemory();
    llm = FakeLlmClient();
  });

  tearDown(() async {
    activeState?.dispose();
    activeState = null;
    await db.db.close();
  });

  Future<AppState> createState({
    FakeLlmClient? client,
    AppSettings? settings,
  }) async {
    final baseSettings = (settings ?? const AppSettings(selectedModel: 'test-model'))
        .copyWith(autoExtract: false);
    final state = AppState(
      database: db,
      llmClient: client ?? llm,
      extractService: ExtractService(),
    );
    await db.saveSettings(baseSettings);
    await state.init();
    state.settings = baseSettings;
    state.selectedModel = baseSettings.selectedModel;
    activeState = state;
    return state;
  }

  group('AppState end-to-end flows', () {
    test('sendMessage streams assistant reply and persists to DB', () async {
      final state = await createState();
      llm.models = [const LlmModel('test-model')];
      llm.chunks = [
        const StreamChunk(content: 'پاسخ '),
        const StreamChunk(content: 'پاسخ کامل'),
      ];

      await state.sendMessage('سلام');

      expect(state.messages.length, 2);
      expect(state.messages.first.role, 'user');
      expect(state.messages.last.content, 'پاسخ کامل');
      expect(state.isStreaming, isFalse);

      final stored = await db.getMessagesByChatId(state.currentChatId!);
      expect(stored.length, 2);
      expect(stored.last.content, 'پاسخ کامل');

      final chats = await db.getAllChats();
      expect(chats, hasLength(1));
      expect(chats.first.title, 'سلام');
    });

    test('stopStreaming keeps partial assistant text in DB', () async {
      llm = FakeLlmClient(
        chunks: [
          const StreamChunk(content: 'نیمه'),
          const StreamChunk(content: 'نیمه کار'),
        ],
        delay: const Duration(milliseconds: 150),
      );
      final state = await createState(client: llm);

      final sendFuture = state.sendMessage('توقف');
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await state.stopStreaming();
      await sendFuture;

      expect(state.messages.last.content, 'نیمه');
      expect(state.stoppedMessageIds, contains(state.messages.last.id));

      final stored = await db.getMessagesByChatId(state.currentChatId!);
      expect(stored.last.content, 'نیمه');
    });

    test('retryMessage removes old assistant message from DB', () async {
      final state = await createState();
      await state.sendMessage('اول');
      final oldAssistantId = state.messages.last.id;

      llm.chunks = [const StreamChunk(content: 'دوم')];
      await state.retryMessage(oldAssistantId);

      expect(state.messages.length, 2);
      expect(state.messages.last.content, 'دوم');

      final stored = await db.getMessagesByChatId(state.currentChatId!);
      expect(stored.length, 2);
      expect(stored.any((m) => m.id == oldAssistantId), isFalse);
    });

    test('persistOllamaBase normalizes localhost to IPv4', () async {
      llm = FakeLlmClient(
        models: [const LlmModel('llama3')],
      );
      final state = await createState(
        client: llm,
        settings: const AppSettings(
          provider: LlmProvider.ollama,
          ollamaUrl: 'http://localhost:11434',
          selectedModel: 'llama3',
        ),
      );

      await state.persistOllamaBase('http://localhost:11434');

      expect(state.settings.ollamaUrl, 'http://127.0.0.1:11434');
      final saved = await db.getSetting('ollamaUrl');
      expect(saved, 'http://127.0.0.1:11434');
    });

    test('stream error saves error message to DB', () async {
      llm = FakeLlmClient(streamError: Exception('اتصال قطع شد'));
      final state = await createState(client: llm);

      await state.sendMessage('خطا');

      expect(state.messages.last.content, contains('اتصال قطع شد'));
      final stored = await db.getMessagesByChatId(state.currentChatId!);
      expect(stored.last.content, contains('اتصال قطع شد'));
    });
  });
}
