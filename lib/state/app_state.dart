import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../core/uid.dart';
import '../data/database.dart';
import '../models/app_settings.dart';
import '../models/chat_models.dart';
import '../models/prompt_config.dart';
import '../services/chat_export_service.dart';
import '../services/extract_service.dart';
import '../services/image_generation_service.dart';
import '../services/llm_client.dart';
import '../services/local_http_client.dart';
import '../services/model_capabilities.dart';
import '../services/ollama_manager_service.dart';
import '../services/ollama_runtime.dart';
import '../services/prompt_builder.dart';
import '../services/vision_message_builder.dart';
import '../services/welcome_suggestions_service.dart';
import '../data/welcome_content.dart';
import '../models/welcome_suggestion.dart';

enum ToastType { info, ok, err }

class ToastMessage {
  const ToastMessage(this.text, {this.type = ToastType.info});
  final String text;
  final ToastType type;
}

class AppState extends ChangeNotifier {
  factory AppState({
    AppDatabase? database,
    LlmClient? llmClient,
    OllamaRuntime? ollamaRuntime,
    OllamaManagerService? ollamaManager,
    PromptBuilder? promptBuilder,
    ExtractService? extractService,
    ChatExportService? chatExportService,
    ImageGenerationService? imageGenerationService,
    WelcomeSuggestionsService? welcomeSuggestionsService,
  }) {
    final db = database ?? AppDatabase.instance;
    final runtime = ollamaRuntime ?? OllamaRuntime();
    return AppState._(
      database: db,
      llmClient: llmClient ?? LlmClient(runtime: runtime),
      ollamaRuntime: runtime,
      ollamaManager:
          ollamaManager ?? OllamaManagerService(runtime: runtime),
      promptBuilder: promptBuilder ?? PromptBuilder(),
      extractService: extractService ?? ExtractService(),
      chatExportService:
          chatExportService ?? ChatExportService(database: db),
      imageGenerationService:
          imageGenerationService ?? ImageGenerationService(),
      welcomeSuggestions: welcomeSuggestionsService ?? WelcomeSuggestionsService(),
    );
  }

  AppState._({
    required AppDatabase database,
    required LlmClient llmClient,
    required OllamaRuntime ollamaRuntime,
    required this.ollamaManager,
    required PromptBuilder promptBuilder,
    required ExtractService extractService,
    required ChatExportService chatExportService,
    required ImageGenerationService imageGenerationService,
    required WelcomeSuggestionsService welcomeSuggestions,
  })  : _db = database,
        _llm = llmClient,
        _runtime = ollamaRuntime,
        _promptBuilder = promptBuilder,
        _extract = extractService,
        _chatExport = chatExportService,
        _imageGen = imageGenerationService,
        _welcomeSuggestions = welcomeSuggestions;

  final AppDatabase _db;
  final LlmClient _llm;
  final OllamaRuntime _runtime;
  final OllamaManagerService ollamaManager;
  final PromptBuilder _promptBuilder;
  final ExtractService _extract;
  final ChatExportService _chatExport;
  final ImageGenerationService _imageGen;
  final WelcomeSuggestionsService _welcomeSuggestions;

  AppSettings settings = const AppSettings();
  AppLocale locale = AppLocale.en;
  AppStrings get strings => AppStrings.of(locale);
  PromptConfig promptConfig = const PromptConfig();
  String userInfo = '';
  String welcomeTitle = '';
  List<WelcomeSuggestionItem> welcomeSuggestions = [];
  bool welcomeSuggestionsRefreshing = false;
  List<Chat> chats = [];
  List<ChatMessage> messages = [];
  List<LlmModel> models = [];
  String selectedModel = '';
  String? currentChatId;
  List<AttachedFile> attachedFiles = [];
  List<AttachedImage> attachedImages = [];
  AttachedAudio? attachedAudio;
  bool isStreaming = false;
  bool isGeneratingImage = false;
  bool isDiscovering = false;
  bool ready = false;
  bool _userStopped = false;
  String? discoveredOllamaBase;
  String? editedPayloadJson;
  ToastMessage? toast;
  final Set<String> stoppedMessageIds = {};
  http.Client? _streamClient;
  StreamSubscription<dynamic>? _streamSub;

  Timer? _refreshTimer;

  bool get isOllama => settings.provider == LlmProvider.ollama;
  bool get canThink => isOllama;
  bool get hasPayloadOverride => editedPayloadJson != null;
  LlmModel? get _selectedLlmModel {
    for (final model in models) {
      if (model.name == selectedModel) return model;
    }
    return null;
  }

  bool get selectedModelSupportsVision => ModelCapabilities.supportsVision(
        selectedModel,
        capabilities: _selectedLlmModel?.capabilities ?? const [],
      );
  bool get selectedModelSupportsAudio => ModelCapabilities.supportsAudio(
        selectedModel,
        capabilities: _selectedLlmModel?.capabilities ?? const [],
      );

  static const _onlineImageGenDefaults = [
    'gpt-image-1',
    'dall-e-3',
    'dall-e-2',
  ];

  List<LlmModel> get imageGenModels {
    final seen = <String>{};
    final result = <LlmModel>[];
    for (final m in models) {
      if (ModelCapabilities.supportsImageGeneration(
            m.name,
            capabilities: m.capabilities,
            outputModalities: m.outputModalities,
          ) &&
          seen.add(m.name)) {
        result.add(m);
      }
    }
    if (!isOllama && settings.provider == LlmProvider.openai) {
      for (final name in _onlineImageGenDefaults) {
        if (seen.add(name)) result.add(LlmModel(name));
      }
    }
    return result;
  }

  LlmModel? _imageModelInfo(String model) {
    for (final m in models) {
      if (m.name == model) return m;
    }
    for (final m in imageGenModels) {
      if (m.name == model) return m;
    }
    return null;
  }

  Future<void> init() async {
    await _db.init();
    locale = await _db.getLocale();
    notifyListeners();
    settings = await _db.getAllSettings();
    if (settings.provider == LlmProvider.ollama) {
      final normalized = OllamaRuntime.normalizeOllamaBase(settings.ollamaUrl);
      if (normalized != settings.ollamaUrl) {
        settings = settings.copyWith(ollamaUrl: normalized);
        await _db.setSetting('ollamaUrl', normalized);
      }
    }
    promptConfig = await _db.loadPromptConfig();
    userInfo = await _db.getUserInfo();
    selectedModel = settings.selectedModel;
    chats = await _db.getAllChats();
    await fetchModels(silent: true);
    if (chats.isNotEmpty) {
      await loadChat(chats.first.id);
    }
    welcomeTitle = pickRandomWelcomeTitle();
    welcomeSuggestions =
        await _welcomeSuggestions.loadCachedOrDefaults(strings);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => fetchModels(silent: true, scanNetwork: false),
    );
    ready = true;
    notifyListeners();
    unawaited(_maybeRefreshWelcomeSuggestions());
  }

  Future<void> _maybeRefreshWelcomeSuggestions() async {
    if (welcomeSuggestionsRefreshing) return;
    welcomeSuggestionsRefreshing = true;
    try {
      final recentMessages = await _db.getRecentUserMessages();
      final modelNames = models.map((m) => m.name).toList();
      final refreshed = await _welcomeSuggestions.refreshIfNeeded(
        settings: settings,
        selectedModel: selectedModel,
        availableModels: modelNames,
        userInfo: userInfo,
        recentUserMessages: recentMessages,
        strings: strings,
      );
      if (refreshed != null && refreshed.isNotEmpty) {
        welcomeSuggestions = refreshed;
        notifyListeners();
      }
    } catch (_) {
      // Keep existing suggestions on any failure.
    } finally {
      welcomeSuggestionsRefreshing = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _streamSub?.cancel();
    _streamClient?.close();
    super.dispose();
  }

  Future<void> setLocale(AppLocale value) async {
    locale = value;
    await _db.setLocale(value);
    notifyListeners();
  }

  void showToast(String text, {ToastType type = ToastType.info}) {
    toast = ToastMessage(text, type: type);
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toast?.text == text) {
        toast = null;
        notifyListeners();
      }
    });
  }

  Future<void> fetchModels({bool silent = false, bool scanNetwork = true}) async {
    if (isOllama && scanNetwork) {
      isDiscovering = true;
      notifyListeners();
    }
    try {
      final result = await _llm.fetchModels(settings, scanNetwork: scanNetwork);
      models = result.models;
      if (isOllama &&
          result.resolvedOllamaBase != null &&
          result.models.isNotEmpty) {
        final resolved = OllamaRuntime.normalizeOllamaBase(result.resolvedOllamaBase!);
        final primary = OllamaRuntime.normalizeOllamaBase(settings.ollamaUrl);
        if (resolved != primary) {
          await persistOllamaBase(resolved);
        }
      }
      if (models.isNotEmpty) {
        final saved = settings.selectedModel;
        if (selectedModel.isEmpty ||
            !models.any((m) => m.name == selectedModel)) {
          selectedModel = models.any((m) => m.name == saved)
              ? saved
              : models.first.name;
          settings = settings.copyWith(selectedModel: selectedModel);
          await _db.setSetting('selectedModel', selectedModel);
        }
        if (!silent) showToast(strings.modelsLoaded(models.length), type: ToastType.ok);
      } else if (!silent) {
        showToast(strings.noModelFound, type: ToastType.err);
      }
    } catch (e) {
      if (!silent) {
        showToast(strings.error(e.toString()), type: ToastType.err);
      }
    } finally {
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> selectModel(String name) async {
    selectedModel = name;
    settings = settings.copyWith(selectedModel: name);
    await _db.setSetting('selectedModel', name);
    notifyListeners();
  }

  Future<void> toggleThink() async {
    if (!isOllama) return;
    settings = settings.copyWith(thinkEnabled: !settings.thinkEnabled);
    await _db.setSetting('thinkEnabled', settings.thinkEnabled);
    notifyListeners();
  }

  Future<void> newChat() async {
    currentChatId = null;
    messages = [];
    notifyListeners();
  }

  Future<void> loadChat(String id) async {
    final chat = await _db.getChat(id);
    if (chat == null) return;
    currentChatId = id;
    messages = await _db.getMessagesByChatId(id);
    if (chat.model.isNotEmpty) {
      selectedModel = chat.model;
    }
    notifyListeners();
  }

  Future<void> deleteChat(String id) async {
    await _db.deleteChat(id);
    chats = await _db.getAllChats();
    if (currentChatId == id) {
      currentChatId = null;
      messages = [];
    }
    notifyListeners();
  }

  Future<void> clearCurrentChat() async {
    if (currentChatId == null) return;
    await _db.clearMessages(currentChatId!);
    messages = [];
    notifyListeners();
  }

  void addAttachedFile(AttachedFile file) {
    attachedFiles = [...attachedFiles, file];
    notifyListeners();
  }

  void removeAttachedFile(int index) {
    attachedFiles = [...attachedFiles]..removeAt(index);
    notifyListeners();
  }

  void addAttachedImage(AttachedImage image) {
    attachedImages = [...attachedImages, image];
    notifyListeners();
  }

  void removeAttachedImage(int index) {
    attachedImages = [...attachedImages]..removeAt(index);
    notifyListeners();
  }

  void setAttachedAudio(AttachedAudio? audio) {
    attachedAudio = audio;
    notifyListeners();
  }

  void clearAttachedAudio() {
    attachedAudio = null;
    notifyListeners();
  }

  bool _messagesContainAudio(Iterable<ChatMessage> msgs) {
    return msgs.any(
      (m) => m.images.any((i) => i.mimeType.startsWith('audio/')),
    );
  }

  static final _fileSplitPattern = RegExp(r'\n\n--- (?:file|فایل|File):');

  String buildMessageContent(String text) {
    if (attachedFiles.isEmpty) return text;
    final parts = [text];
    for (final f in attachedFiles) {
      final ext = f.name.contains('.') ? f.name.split('.').last : 'txt';
      final content = f.content.length > 4000
          ? f.content.substring(0, 4000)
          : f.content;
      parts.add('\n\n--- file:${f.name} ---\n```$ext\n$content\n```');
    }
    return parts.join();
  }

  List<Map<String, dynamic>> apiMessagesFor(List<ChatMessage> msgs) {
    return msgs
        .map(
          (m) => VisionMessageBuilder.buildApiMessage(
            m,
            isOllama: isOllama,
            thinkEnabled: settings.thinkEnabled,
          ),
        )
        .toList();
  }

  Map<String, dynamic> buildPayload({
    List<ChatMessage>? forMessages,
    PromptConfig? config,
  }) {
    return _promptBuilder.buildPayload(
      config: config ?? promptConfig,
      userInfo: userInfo,
      chatMessages: forMessages ?? messages,
      settings: settings,
      model: selectedModel,
      strings: strings,
    );
  }

  Map<String, dynamic> previewPayload({PromptConfig? config}) {
    final payload = buildPayload(
      config: config,
      forMessages: messages.length > 6
          ? messages.sublist(messages.length - 6)
          : messages,
    );
    final base = _llm.baseUrl(settings);
    final endpoint = isOllama ? '$base/api/chat' : '$base/chat/completions';
    return {'_endpoint': endpoint, ...payload};
  }

  Future<void> ensureChat() async {
    if (currentChatId != null) return;
    final id = newId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final chat = Chat(
      id: id,
      title: strings.newChatTitle,
      model: selectedModel,
      createdAt: now,
      updatedAt: now,
    );
    await _db.createChat(chat);
    currentChatId = id;
    chats = await _db.getAllChats();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty &&
        attachedFiles.isEmpty &&
        attachedImages.isEmpty &&
        attachedAudio == null) {
      return;
    }
    if (isStreaming) return;
    if (selectedModel.isEmpty) {
      showToast(strings.noModelSelectedToast, type: ToastType.err);
      return;
    }
    if (attachedImages.isNotEmpty && !selectedModelSupportsVision) {
      showToast(strings.modelNoVision, type: ToastType.err);
      return;
    }
    if (attachedAudio != null && !selectedModelSupportsAudio) {
      showToast(strings.modelNoAudio, type: ToastType.err);
      return;
    }

    await ensureChat();
    var effectiveText = trimmed;
    if (effectiveText.isEmpty && attachedImages.isNotEmpty) {
      effectiveText = strings.imageOnlyPrompt;
    }
    final content = buildMessageContent(effectiveText);
    final msgImages = [
      ...attachedImages.map((i) => i.toMessageImage()),
      if (attachedAudio != null) attachedAudio!.toMessageImage(),
    ];
    final userMsg = ChatMessage(
      id: newId(),
      chatId: currentChatId!,
      role: 'user',
      content: content,
      files: attachedFiles.map((f) => MessageFile(name: f.name)).toList(),
      images: msgImages,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    messages = [...messages, userMsg];
    await _db.addMessage(userMsg);

    final chat = await _db.getChat(currentChatId!);
    if (chat != null) {
      final updated = chat.copyWith(
        title: chat.title == strings.newChatTitle || chat.title == 'New chat'
            ? (trimmed.isNotEmpty
                ? trimmed.substring(0, trimmed.length.clamp(0, 55))
                : strings.chatTitleFallback)
            : chat.title,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _db.updateChat(updated);
      chats = await _db.getAllChats();
    }

    attachedFiles = [];
    attachedImages = [];
    attachedAudio = null;
    notifyListeners();

    await _streamResponse(
      userText: trimmed,
      disableThink: _messagesContainAudio(messages),
    );
  }

  Future<void> stopStreaming() async {
    if (!isStreaming) return;
    _userStopped = true;
    isStreaming = false;
    _streamSub?.cancel();
    _streamClient?.close();
    _streamSub = null;
    _streamClient = null;
    notifyListeners();
  }

  Future<void> _streamResponse({
    required String userText,
    String? retryMessageId,
    String? overrideModel,
    bool disableThink = false,
  }) async {
    _userStopped = false;
    isStreaming = true;
    notifyListeners();

    final model = overrideModel ?? selectedModel;
    final aiId = newId();
    var aiMsg = ChatMessage(
      id: aiId,
      chatId: currentChatId!,
      role: 'assistant',
      content: '',
      model: model,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    messages = [...messages, aiMsg];
    notifyListeners();

    final apiMsgs = apiMessagesFor(
      messages.where((m) => m.id != aiId).toList(),
    );
    final payload = buildPayload();

    _streamClient = isOllama
        ? createClientForBase(settings.ollamaUrl)
        : http.Client();
    var wasStopped = false;
    var savedToDb = false;

    Future<void> persistAssistantMessage() async {
      if (savedToDb) return;
      savedToDb = true;

      final idx = messages.indexWhere((m) => m.id == aiId);
      if (idx == -1) return;

      final hasContent =
          aiMsg.content.isNotEmpty || (aiMsg.thinking?.isNotEmpty ?? false);
      if (!hasContent) {
        if (wasStopped || _userStopped) {
          messages = [...messages]..removeAt(idx);
          notifyListeners();
        }
        return;
      }

      if (wasStopped || _userStopped) {
        stoppedMessageIds.add(aiId);
      }

      await _db.addMessage(aiMsg);
      final chat = await _db.getChat(currentChatId!);
      if (chat != null) {
        await _db.updateChat(
          chat.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch),
        );
        chats = await _db.getAllChats();
      }
    }

    try {
      final stream = _llm.streamChat(
        settings: settings,
        payload: payload,
        editedPayloadJson: editedPayloadJson,
        apiMessages: apiMsgs,
        injectHistory: promptConfig.injectHistory,
        client: _streamClient,
        disableThink: disableThink,
        onOllamaBaseResolved: (base) => persistOllamaBase(base),
      );

      await for (final chunk in stream) {
        if (_userStopped) {
          wasStopped = true;
          break;
        }
        aiMsg = aiMsg.copyWith(
          content: chunk.content,
          thinking: chunk.thinking.isNotEmpty ? chunk.thinking : null,
        );
        final idx = messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          messages = [...messages]..[idx] = aiMsg;
          notifyListeners();
        }
      }

      if (_userStopped) {
        wasStopped = true;
      }

      await persistAssistantMessage();

      if (!_userStopped &&
          userText.isNotEmpty &&
          aiMsg.content.isNotEmpty) {
        final merged = await _extract.extractAndMerge(
          settings: settings,
          selectedModel: selectedModel,
          userInfo: userInfo,
          userMsg: userText,
          aiMsg: aiMsg.content,
          strings: strings,
        );
        if (merged != null) {
          userInfo = merged;
          await _db.setUserInfo(userInfo);
          showToast(strings.profileUpdated, type: ToastType.ok);
        }
      }
    } catch (e) {
      if (_userStopped) {
        wasStopped = true;
        final idx = messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          messages = [...messages]..[idx] = aiMsg;
        }
      } else {
        aiMsg = aiMsg.copyWith(
          content: aiMsg.content.isEmpty ? '⚠️ $e' : aiMsg.content,
        );
        final idx = messages.indexWhere((m) => m.id == aiId);
        if (idx != -1) {
          messages = [...messages]..[idx] = aiMsg;
        }
        await persistAssistantMessage();
        showToast(strings.error(e.toString()), type: ToastType.err);
      }
    } finally {
      if ((wasStopped || _userStopped) && !savedToDb) {
        await persistAssistantMessage();
      }
      isStreaming = false;
      _streamClient?.close();
      _streamClient = null;
      _streamSub = null;
      notifyListeners();
      if (wasStopped || _userStopped) {
        showToast(strings.stopped, type: ToastType.info);
      }
    }
  }

  Future<void> retryMessage(String messageId, {String? model}) async {
    if (isStreaming) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1 || messages[idx].role != 'assistant') return;

    final prevModel = selectedModel;
    if (model != null) {
      selectedModel = model;
      notifyListeners();
    }

    messages = [...messages]..removeAt(idx);
    await _db.deleteMessage(messageId);
    notifyListeners();

    final userIdx = idx - 1;
    final userText = userIdx >= 0 && messages[userIdx].isUser
        ? messages[userIdx].content.split(_fileSplitPattern).first.trim()
        : '';

    await _streamResponse(
      userText: userText,
      retryMessageId: messageId,
      overrideModel: model ?? selectedModel,
    );

    if (model != null && messages.last.content.isEmpty) {
      selectedModel = prevModel;
      notifyListeners();
    }
  }

  void loadMessageToInput(String messageId, void Function(String) setInput) {
    final msg = messages.firstWhere((m) => m.id == messageId);
    final clean = msg.content.split(_fileSplitPattern).first.trim();
    setInput(clean);
    showToast(strings.messageLoaded, type: ToastType.ok);
  }

  Future<ImageGenerationResult> generateImage({
    required String model,
    required String prompt,
    AttachedImage? sourceImage,
  }) async {
    if (model.isEmpty) {
      throw Exception(strings.imageModelNotSelected);
    }
    final modelInfo = _imageModelInfo(model);
    if (modelInfo == null &&
        !ModelCapabilities.supportsImageGeneration(model)) {
      throw Exception(strings.imageModelNotSuitable);
    }

    isGeneratingImage = true;
    notifyListeners();
    try {
      final result = await _imageGen.generate(
        settings: settings,
        model: model,
        prompt: prompt,
        strings: strings,
        sourceImageBase64: sourceImage?.base64,
        outputModalities: modelInfo?.outputModalities ?? const [],
      );
      showToast(strings.imageSaved, type: ToastType.ok);
      return result;
    } finally {
      isGeneratingImage = false;
      notifyListeners();
    }
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    var next = newSettings;
    if (newSettings.provider == LlmProvider.ollama) {
      next = newSettings.copyWith(
        ollamaUrl: OllamaRuntime.normalizeOllamaBase(newSettings.ollamaUrl),
      );
    }
    settings = next.copyWith(selectedModel: selectedModel);
    await _db.saveSettings(settings);
    notifyListeners();
    await fetchModels(silent: false, scanNetwork: isOllama);
    showToast(strings.settingsSaved, type: ToastType.ok);
  }

  Future<void> saveUserInfo(String value) async {
    userInfo = value.trim();
    await _db.setUserInfo(userInfo);
    notifyListeners();
    showToast(strings.profileSaved, type: ToastType.ok);
  }

  Future<void> savePromptConfig(PromptConfig config) async {
    promptConfig = config;
    await _db.savePromptConfig(config);
    notifyListeners();
    showToast(strings.promptSaved, type: ToastType.ok);
  }

  void setEditedPayload(String? json) {
    editedPayloadJson = json;
    notifyListeners();
  }

  Future<void> persistOllamaBase(String base) async {
    final normalized = OllamaRuntime.normalizeOllamaBase(base);
    settings = settings.copyWith(ollamaUrl: normalized);
    discoveredOllamaBase = normalized;
    _runtime.rememberReachableBase(normalized);
    await _db.setSetting('ollamaUrl', normalized);
    notifyListeners();
  }

  Future<void> clearAllData() async {
    await _db.clearAll();
    settings = const AppSettings();
    promptConfig = const PromptConfig();
    userInfo = '';
    chats = [];
    messages = [];
    currentChatId = null;
    selectedModel = '';
    models = [];
    editedPayloadJson = null;
    notifyListeners();
  }

  Future<void> exportAllChats() async {
    final result = await _chatExport.exportAll(strings);
    showToast(
      result.message ?? (result.success ? strings.saved : strings.genericError),
      type: result.success ? ToastType.ok : ToastType.err,
    );
  }

  Future<void> exportCurrentChat() async {
    if (currentChatId == null) {
      showToast(strings.noOpenChat, type: ToastType.err);
      return;
    }
    final title = chatTitle();
    final result =
        await _chatExport.exportChat(currentChatId!, strings, title: title);
    showToast(
      result.message ?? (result.success ? strings.saved : strings.genericError),
      type: result.success ? ToastType.ok : ToastType.err,
    );
  }

  Future<void> importChats({required bool merge}) async {
    final result = await _chatExport.importFromFile(strings, merge: merge);
    if (result.success) {
      chats = await _db.getAllChats();
      if (!merge) {
        final currentExists =
            currentChatId != null && chats.any((c) => c.id == currentChatId);
        if (!currentExists) {
          currentChatId = chats.isNotEmpty ? chats.first.id : null;
          messages = [];
        }
        if (currentChatId != null) {
          await loadChat(currentChatId!);
        }
      } else if (chats.isNotEmpty && currentChatId == null) {
        await loadChat(chats.first.id);
      }
      notifyListeners();
    }
    showToast(
      result.message ?? (result.success ? strings.imported : strings.genericError),
      type: result.success ? ToastType.ok : ToastType.err,
    );
  }

  String chatTitle() {
    if (currentChatId == null) return strings.appName;
    final chat = chats.where((c) => c.id == currentChatId).firstOrNull;
    return chat?.title ?? strings.appName;
  }

  int contextSentCount() {
    final ctx = settings.contextWindow;
    return messages.length > ctx ? ctx : messages.length;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
