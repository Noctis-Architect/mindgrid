import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'strings_en.dart';
import 'strings_fa.dart';

abstract class AppStrings {
  static AppStrings of(AppLocale locale) => switch (locale) {
        AppLocale.fa => StringsFa(),
        AppLocale.en => StringsEn(),
      };

  String get appName;
  String get loading;
  String get language;
  String get languageEn;
  String get languageFa;

  // Sidebar
  String get newChat;
  String get close;
  String get conversations;
  String get noConversationsYet;
  String get delete;
  String get cancel;
  String get deleteConversation;
  String get deleteConversationConfirm;
  String get imageGeneration;
  String get backupExport;
  String get ollamaManager;
  String get promptEngineering;
  String get userProfile;
  String get settings;
  String get today;
  String get yesterday;

  // Top bar
  String get clearConversation;
  String get clearConversationConfirm;
  String get clear;
  String get contextWindow;

  // Welcome
  String get welcomeTitle;
  String get welcomeSubtitle;
  String get welcomeSuggestionsRefreshing;
  List<({String label, IconData icon, String prompt})> get welcomeSuggestions;

  // Chat input
  String get inputHintOllama;
  String get inputHint;
  String get attachFile;
  String get attachImage;
  String get attachImageNeedsVision;
  String get stopRecording;
  String get recordAudio;
  String get recordAudioNeedsModel;
  String get recordingProgress;
  String audioFileLabel(String duration);
  String get processAudioFile;
  String get disclaimer;
  String fileTooLarge(String name);
  String fileTooLargeMax(String name);
  String readImageFailed(String name);
  String get selectVisionModel;
  String get imageOnlyPrompt;
  String dropFileError(String name);
  String get audioNotSupported;
  String get selectAudioModel;
  String get audioSaved;

  // Messages
  String get stopped;
  String get showThinking;
  String get hideThinking;
  String get copy;
  String get copied;
  String get retry;
  String get share;
  String get edit;
  String get otherModel;
  String get me;
  String get expand;
  String get collapse;

  String lineCount(int n);

  // Model selector
  String get selectModel;
  String get noModelsFound;
  String get search;
  String get noModelSelected;

  // Settings
  String get settingsTitle;
  String get tabGeneral;
  String get tabApi;
  String get tabAutoExtract;
  String get tabAdvanced;
  String get saveSettings;
  String get creativity;
  String get maxOutputTokens;
  String get contextMessageCount;
  String get streaming;
  String get streamingSubtitle;
  String get thinkingMode;
  String get thinkingModeOllama;
  String get thinkingModeOllamaOnly;
  String get provider;
  String get ollamaUrl;
  String get searching;
  String get discoverOllama;
  String get baseUrl;
  String get apiKeys;
  String get savedKey;
  String get newKey;
  String get keyName;
  String get deleteKey;
  String get apiKey;
  String get manualModelName;
  String get requestTimeout;
  String get customHeaders;
  String get autoExtractDescription;
  String get autoExtract;
  String get autoExtractSubtitle;
  String get extractProvider;
  String get extractModel;
  String get sameChatModel;
  String get extractModelManual;
  String get extractionPrompt;
  String get advancedWarning;
  String get clearAllData;
  String get clearAllDataConfirm;
  String get deleteApiKey;
  String deleteApiKeyConfirm(String name);
  String get apiKeyDeleted;

  // User profile
  String get clearProfile;
  String get clearProfileConfirm;
  String get profileInfo;
  String get profileHint;
  String get profileDescription;
  String get unsavedChanges;
  String get saveProfile;

  // Backup
  String get backupRestore;
  String get exportSection;
  String get exportAllChats;
  String get exportAllChatsSubtitle;
  String get exportCurrentChat;
  String get exportCurrentChatSubtitle;
  String get importSection;
  String get importMerge;
  String get importMergeSubtitle;
  String get importReplace;
  String get importReplaceSubtitle;
  String get replaceAllChats;
  String get replaceAllChatsConfirm;
  String get replace;
  String savedConversations(int count);
  String get processing;

  // Prompt panel
  String get presetRoles;
  String get presetApplied;
  String get save;
  String get systemPromptLabel;
  String get systemPromptHint;
  String get variables;
  String get add;
  String get key;
  String get value;
  String get injectUserProfile;
  String get injectUserProfileSubtitle;
  String get conversationHistory;
  String get dateTime;
  String get fullPayload;
  String get customPayloadApplied;
  String get apply;
  String get reset;
  String get jsonCopied;

  // Image generation
  String get imageGenTitle;
  String get imageGenDescription;
  String get prompt;
  String get promptHint;
  String get generating;
  String get generateImage;
  String get result;
  String get saveImage;
  String get help;
  String get imageGenNoModels;
  String get refreshModels;
  String get imageModel;
  String get referenceImage;
  String get selectReferenceImage;
  String get enterPromptOrImage;
  String get noImageModelSelected;
  String get imageTooLarge;
  String get saveNotSupportedWeb;
  String get useSaveButton;
  String get imageSaved;

  // Ollama manager
  String get ollamaManagerTitle;
  String get refresh;
  String get library;
  String get installed;
  String get hardwareGuide;
  String get searchModels;
  String get installOnLinux;
  String get installLinuxDescription;
  String get installOllama;
  String get startSystemdService;
  String get manualCommands;
  String get installOnWindows;
  String get installWindowsSteps;
  String get downloadFromGitHub;
  String get ollamaNotAvailable;
  String get ollamaNotAvailableDescription;
  String get noModelsInstalled;
  String get loadingModels;
  String get deleteModel;
  String deleteModelConfirm(String name);
  String modelRemoved(String name);
  String modelInstalled(String name);
  String get failedToOpenLink;
  String error(String e);
  String get running;
  String get stoppedStatus;
  String get notInstalled;
  String get unsupported;
  String get ollamaRunning;
  String get ollamaRunningSubtitle;
  String get ollamaStopped;
  String get ollamaStoppedSubtitle;
  String get ollamaNotInstalled;
  String get ollamaNotInstalledSubtitle;
  String get platformNotSupported;
  String get platformNotSupportedSubtitle;
  String get expandVariants;
  String variantsInfo(int variants, int installed);
  String get audio;
  String get vision;
  String get noVariantsFound;
  String get install;

  // Ollama hardware guide
  String get hwHowToChoose;
  String get hwHowToChooseText;
  String get hwSpeed;
  String get hwSpeedText;
  String get hwQuantization;
  String get hwQuantizationText;
  String get hwTable;
  String get hwPracticalTips;
  String get hwRecommendedModel;
  String get hwApproxSpeed;
  String get hwVramApprox;
  String get hwPracticalTipsBody;
  List<({String ram, String vram, String models, String speed, String note})>
      get hwTiers;

  // Toasts & state
  String get genericError;
  String get invalidCustomHeadersJson;
  String modelsLoaded(int count);
  String get noModelFound;
  String get noModelSelectedToast;
  String get modelNoVision;
  String get modelNoAudio;
  String get thinkingOn;
  String get thinkingOff;
  String get profileUpdated;
  String get messageLoaded;
  String get imageModelNotSelected;
  String get imageModelNotSuitable;
  String get settingsSaved;
  String get profileSaved;
  String get promptSaved;
  String get saved;
  String get imported;
  String get noOpenChat;
  String get newChatTitle;
  String get chatTitleFallback;

  // Export service
  String get chatNotFound;
  String get invalidFileFormat;
  String get saveFileWebUnsupported;
  String get saveBackup;
  String get cancelled;
  String chatsSaved(int count);
  String get noChatsToExport;
  String get importFileWebUnsupported;
  String get selectBackupFile;
  String get emptyOrInvalidFile;
  String jsonReadError(String e);
  String get backupHasNoChats;
  String chatsImported(int chats, int messages);

  // Ollama manager service
  String get installLinuxOnly;
  String get downloadingOllama;
  String installFailed(int code);
  String get installComplete;
  String get installDoneApiUnavailable;
  String get enablingOllamaService;
  String get ollamaServiceEnabled;
  String get serviceEnableFailed;
  String get localRunWebUnsupported;
  String get ollamaCommandNotFound;
  String get runningOllamaServe;
  String get processStartedWait;

  // Ollama pull status
  String get pullingManifest;
  String get downloadingLayers;
  String get verifyingChecksum;
  String get installSuccess;
  String get downloading;

  // Ollama download manager
  String get downloadingTab;
  String get noActiveDownloads;
  String get downloadPaused;
  String get pauseDownload;
  String get resumeDownload;
  String get cancelDownload;
  String get downloadQueued;
  String get etaRemaining;
  String etaSeconds(int seconds);
  String etaMinutesSeconds(int minutes, int seconds);
  String etaHoursMinutes(int hours, int minutes);
  String get noModelsInstalledHint;

  // Audio recorder
  String get audioRecordUnsupported;
  String get microphoneDenied;
  String get audioFileNotSaved;
  String get audioFileNotFound;
  String get audioRecordEmpty;

  // Image generation service
  String get promptOrImageRequired;
  String get noImageReturned;
  String get imageDownloadFailed;
  String get imageFormatUnsupported;

  // Extract service field labels
  Map<String, String> get extractFieldLabels;

  // Prompt builder
  String dateTimeLabel(String dt);
  String userInfoLabel(String info);

  // Prompt presets
  List<({String label, String text})> get promptPresets;

  // File attachment in message
  String fileAttachment(String name);
}
