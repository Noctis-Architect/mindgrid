import 'package:flutter/material.dart';

import 'app_strings.dart';

class StringsEn extends AppStrings {
  @override
  String get appName => 'MindGrid';
  @override
  String get loading => 'Loading…';
  @override
  String get language => 'Language';
  @override
  String get languageEn => 'English';
  @override
  String get languageFa => 'فارسی';

  @override
  String get newChat => 'New chat';
  @override
  String get close => 'Close';
  @override
  String get conversations => 'Conversations';
  @override
  String get noConversationsYet => 'No conversations yet';
  @override
  String get delete => 'Delete';
  @override
  String get cancel => 'Cancel';
  @override
  String get deleteConversation => 'Delete conversation';
  @override
  String get deleteConversationConfirm =>
      'This conversation will be permanently deleted. Continue?';
  @override
  String get imageGeneration => 'Image generation';
  @override
  String get backupExport => 'Backup / Export';
  @override
  String get ollamaManager => 'Ollama Manager';
  @override
  String get promptEngineering => 'Prompt Engineering';
  @override
  String get userProfile => 'User Profile';
  @override
  String get settings => 'Settings';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';

  @override
  String get clearConversation => 'Clear conversation';
  @override
  String get clearConversationConfirm =>
      'All messages in this conversation will be cleared. Continue?';
  @override
  String get clear => 'Clear';
  @override
  String get contextWindow => 'Context window';

  @override
  String get welcomeTitle => 'How can I help you?';
  @override
  String get welcomeSubtitle =>
      'Start with a suggestion below or ask anything';
  @override
  String get welcomeSuggestionsRefreshing => 'Personalizing suggestions…';
  @override
  List<({String label, IconData icon, String prompt})> get welcomeSuggestions => [
        (
          label: 'Transformers',
          icon: Icons.psychology_outlined,
          prompt: 'Explain how transformers work in machine learning',
        ),
        (
          label: 'JSON parser',
          icon: Icons.code_rounded,
          prompt: 'Write a Python function that parses JSON and handles errors',
        ),
        (
          label: 'REST vs GraphQL',
          icon: Icons.compare_arrows_rounded,
          prompt: 'What are the key differences between REST and GraphQL?',
        ),
        (
          label: 'Code review',
          icon: Icons.rate_review_outlined,
          prompt: 'Review my code and suggest improvements',
        ),
      ];

  @override
  String get inputHintOllama =>
      'Write a message to Ollama… (Shift+Enter for new line)';
  @override
  String get inputHint => 'Write a message… (Shift+Enter for new line)';
  @override
  String get attachFile => 'Attach file';
  @override
  String get attachImage => 'Attach image';
  @override
  String get attachImageNeedsVision => 'Attach image (requires vision model)';
  @override
  String get stopRecording => 'Stop recording';
  @override
  String get recordAudio => 'Record audio';
  @override
  String get recordAudioNeedsModel =>
      'Requires audio model (e.g. gemma4)';
  @override
  String get recordingProgress => 'Recording…';
  @override
  String audioFileLabel(String duration) =>
      duration.isNotEmpty ? 'Audio · $duration' : 'Audio file';
  @override
  String get processAudioFile => 'Process this audio file.';
  @override
  String get disclaimer =>
      'MindGrid can make mistakes. Verify important information.';
  @override
  String fileTooLarge(String name) => '$name is too large';
  @override
  String fileTooLargeMax(String name) => '$name is too large (max 10MB)';
  @override
  String readImageFailed(String name) => '$name: failed to read image';
  @override
  String get selectVisionModel =>
      'Select a vision model to send images';
  @override
  String get imageOnlyPrompt => 'Describe this image.';
  @override
  String dropFileError(String name) =>
      '$name: text files or images only (with vision model)';
  @override
  String get audioNotSupported =>
      'Audio recording is not supported on this platform';
  @override
  String get selectAudioModel =>
      'Select an audio model (e.g. gemma4) to record';
  @override
  String get audioSaved => '✓ Audio recording saved';

  @override
  String get stopped => 'Stopped';
  @override
  String get showThinking => 'Show thinking process';
  @override
  String get hideThinking => 'Hide thinking';
  @override
  String get copy => 'Copy';
  @override
  String get copied => 'Copied';
  @override
  String get retry => 'Retry';
  @override
  String get share => 'Share';
  @override
  String get edit => 'Edit';
  @override
  String get otherModel => 'Other model';
  @override
  String get me => 'Me';
  @override
  String get expand => 'Expand';
  @override
  String get collapse => 'Collapse';
  @override
  String lineCount(int n) => '$n lines';

  @override
  String get selectModel => 'Select model';
  @override
  String get noModelsFound => 'No models found';
  @override
  String get search => 'Search…';
  @override
  String get noModelSelected => 'No model selected';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get tabGeneral => 'General';
  @override
  String get tabApi => 'API / Provider';
  @override
  String get tabAutoExtract => 'Auto-extract';
  @override
  String get tabAdvanced => 'Advanced';
  @override
  String get saveSettings => 'Save settings';
  @override
  String get creativity => 'Creativity (Temperature)';
  @override
  String get maxOutputTokens => 'Max output tokens';
  @override
  String get contextMessageCount => 'Messages in context';
  @override
  String get streaming => 'Streaming';
  @override
  String get streamingSubtitle => 'Show responses live as they stream';
  @override
  String get thinkingMode => 'Thinking mode';
  @override
  String get thinkingModeOllama =>
      'Enable model thinking (Ollama think API)';
  @override
  String get thinkingModeOllamaOnly =>
      'Only available for local Ollama provider';
  @override
  String get provider => 'Provider';
  @override
  String get ollamaUrl => 'Ollama URL';
  @override
  String get searching => 'Searching…';
  @override
  String get discoverOllama => 'Discover Ollama on network';
  @override
  String get baseUrl => 'Base URL';
  @override
  String get apiKeys => 'API Keys';
  @override
  String get savedKey => 'Saved key';
  @override
  String get newKey => '— New key —';
  @override
  String get keyName => 'Key name';
  @override
  String get deleteKey => 'Delete key';
  @override
  String get apiKey => 'API Key';
  @override
  String get manualModelName => 'Model name (manual)';
  @override
  String get requestTimeout => 'Request Timeout (ms)';
  @override
  String get customHeaders => 'Custom Headers (JSON)';
  @override
  String get autoExtractDescription =>
      'After each message, AI identifies important information and saves it to the user profile.';
  @override
  String get autoExtract => 'Auto-extract';
  @override
  String get autoExtractSubtitle =>
      'Identify and save important user information';
  @override
  String get extractProvider => 'Extract provider';
  @override
  String get extractModel => 'Extract model';
  @override
  String get sameChatModel => 'Same as chat model';
  @override
  String get extractModelManual => 'Or enter model name';
  @override
  String get extractionPrompt => 'Extraction Prompt';
  @override
  String get advancedWarning =>
      'Actions in this section are irreversible.';
  @override
  String get clearAllData => 'Clear all data';
  @override
  String get clearAllDataConfirm =>
      'All conversations and settings will be deleted. Continue?';
  @override
  String get deleteApiKey => 'Delete API key';
  @override
  String deleteApiKeyConfirm(String name) => 'Delete key "$name"?';
  @override
  String get apiKeyDeleted => 'Key deleted';

  @override
  String get clearProfile => 'Clear Profile';
  @override
  String get clearProfileConfirm => 'Remove all saved profile info?';
  @override
  String get profileInfo => 'Profile Info';
  @override
  String get profileHint =>
      "e.g. I'm a Python developer working on web apps…";
  @override
  String get profileDescription =>
      'This info is injected into every conversation as context for the model.';
  @override
  String get unsavedChanges => 'Unsaved changes';
  @override
  String get saveProfile => 'Save Profile';

  @override
  String get backupRestore => 'Backup & Restore';
  @override
  String get exportSection => 'Export';
  @override
  String get exportAllChats => 'Export all chats';
  @override
  String get exportAllChatsSubtitle =>
      'Save all conversations to a JSON file';
  @override
  String get exportCurrentChat => 'Export current chat';
  @override
  String get exportCurrentChatSubtitle =>
      'Save only the currently active conversation';
  @override
  String get importSection => 'Import';
  @override
  String get importMerge => 'Import (merge)';
  @override
  String get importMergeSubtitle =>
      'Add chats from file alongside existing conversations';
  @override
  String get importReplace => 'Import (replace)';
  @override
  String get importReplaceSubtitle =>
      'Delete all current chats and replace with file';
  @override
  String get replaceAllChats => 'Replace all chats';
  @override
  String get replaceAllChatsConfirm =>
      'All current chats will be permanently deleted and replaced with the imported file. Continue?';
  @override
  String get replace => 'Replace';
  @override
  String savedConversations(int count) =>
      '$count saved conversation${count != 1 ? 's' : ''}';
  @override
  String get processing => 'Processing…';

  @override
  String get presetRoles => 'PRESET ROLES';
  @override
  String get presetApplied => 'Preset applied';
  @override
  String get save => 'Save';
  @override
  String get systemPromptLabel =>
      'system — Sent at start of every conversation';
  @override
  String get systemPromptHint => 'You are a helpful assistant…';
  @override
  String get variables => 'Variables {{key}}';
  @override
  String get add => '+ Add';
  @override
  String get key => 'key';
  @override
  String get value => 'value';
  @override
  String get injectUserProfile => 'User profile';
  @override
  String get injectUserProfileSubtitle =>
      'Inject user info into system prompt';
  @override
  String get conversationHistory => 'Conversation history';
  @override
  String get dateTime => 'Date & time';
  @override
  String get fullPayload => 'Full Payload (OpenAI format)';
  @override
  String get customPayloadApplied => 'Custom payload applied ✓';
  @override
  String get apply => '✓ Apply';
  @override
  String get reset => '↺ Reset';
  @override
  String get jsonCopied => 'JSON copied ✓';

  @override
  String get imageGenTitle => 'Image generation';
  @override
  String get imageGenDescription =>
      'With an image model, generate images from a prompt or reference image (+ optional prompt).';
  @override
  String get prompt => 'Prompt';
  @override
  String get promptHint => 'e.g. an astronaut cat on the moon…';
  @override
  String get generating => 'Generating…';
  @override
  String get generateImage => 'Generate image';
  @override
  String get result => 'Result';
  @override
  String get saveImage => 'Save';
  @override
  String get help => 'Help';
  @override
  String get imageGenNoModels =>
      'No image model found.\nFor Ollama, install flux or stable-diffusion models.\nFor online APIs (OpenAI, etc.), enter your API key in Settings.';
  @override
  String get refreshModels => 'Refresh models';
  @override
  String get imageModel => 'Image model';
  @override
  String get referenceImage => 'Reference image (optional)';
  @override
  String get selectReferenceImage => 'Select reference image';
  @override
  String get enterPromptOrImage => 'Enter a prompt or reference image';
  @override
  String get noImageModelSelected => 'No image model selected';
  @override
  String get imageTooLarge => 'Image is too large (max 10MB)';
  @override
  String get saveNotSupportedWeb =>
      'Saving files is not supported on web';
  @override
  String get useSaveButton => 'Use the save button';
  @override
  String get imageSaved => 'Saved ✓';

  @override
  String get ollamaManagerTitle => 'Ollama Manager';
  @override
  String get refresh => 'Refresh';
  @override
  String get library => 'Library';
  @override
  String get installed => 'Installed';
  @override
  String get hardwareGuide => 'Hardware Guide';
  @override
  String get searchModels => 'Search models, params, or quant…';
  @override
  String get installOnLinux => 'Install on Linux';
  @override
  String get installLinuxDescription =>
      'Ollama will be installed automatically. Requires administrator access (sudo/pkexec). '
      'After installation, the systemd service is enabled so Ollama runs in the background.';
  @override
  String get installOllama => 'Install Ollama';
  @override
  String get startSystemdService => 'Start systemd service';
  @override
  String get manualCommands => 'Manual commands';
  @override
  String get installOnWindows => 'Install on Windows';
  @override
  String get installWindowsSteps =>
      '1. Download OllamaSetup.exe from GitHub.\n'
      '2. Run the installer and follow the steps.\n'
      '3. After installation, Ollama runs automatically in the system tray.\n'
      '4. Come back here and press the refresh button.';
  @override
  String get downloadFromGitHub => 'Download from GitHub';
  @override
  String get ollamaNotAvailable => 'Ollama not available';
  @override
  String get ollamaNotAvailableDescription =>
      'To use Ollama, install and run it on your system or network, '
      'then configure the Ollama URL in Settings.';
  @override
  String get noModelsInstalled =>
      'No models installed — browse the Library tab to install one';
  @override
  String get loadingModels => 'Loading…';
  @override
  String get deleteModel => 'Delete model';
  @override
  String deleteModelConfirm(String name) => 'Remove "$name" from Ollama?';
  @override
  String modelRemoved(String name) => '✓ $name removed';
  @override
  String modelInstalled(String name) => '✓ $name installed';
  @override
  String get failedToOpenLink => 'Failed to open link';
  @override
  String error(String e) => 'Error: $e';
  @override
  String get running => 'Running';
  @override
  String get stoppedStatus => 'Stopped';
  @override
  String get notInstalled => 'Not installed';
  @override
  String get unsupported => 'Unsupported';
  @override
  String get ollamaRunning => 'Ollama is running';
  @override
  String get ollamaRunningSubtitle =>
      'You can install and manage models.';
  @override
  String get ollamaStopped => 'Ollama is installed but not running';
  @override
  String get ollamaStoppedSubtitle => 'Start the service to continue.';
  @override
  String get ollamaNotInstalled => 'Ollama is not installed';
  @override
  String get ollamaNotInstalledSubtitle =>
      'Install Ollama to get started.';
  @override
  String get platformNotSupported => 'Platform not supported';
  @override
  String get platformNotSupportedSubtitle =>
      'Local installation is unavailable on this platform.';
  @override
  String get expandVariants => 'Expand to see variants';
  @override
  String variantsInfo(int variants, int installed) =>
      '$variants variant · $installed installed';
  @override
  String get audio => 'audio';
  @override
  String get vision => 'vision';
  @override
  String get noVariantsFound => 'No variants found';
  @override
  String get install => 'Install';

  @override
  String get hwHowToChoose => 'How to choose the right model?';
  @override
  String get hwHowToChooseText =>
      'Model size (e.g. 7B = 7 billion parameters) and quantization type (Q4, Q8, FP16) '
      'determine how much RAM/VRAM is needed. Q4 uses about half the memory of FP16 '
      'with minimal quality loss. For everyday chat, Q4_K_M is recommended.';
  @override
  String get hwSpeed => 'Speed (tokens per second)';
  @override
  String get hwSpeedText =>
      'On GPU typically 30–100 tok/s; on CPU 5–30 tok/s. '
      'If responses are slow: try a smaller model, Q4, or less context (e.g. 4096).';
  @override
  String get hwQuantization => 'Quantization';
  @override
  String get hwQuantizationText =>
      'In model name: llama3.2:3b = default, :3b-instruct-q4_K_M = Q4';
  @override
  String get hwTable => 'Hardware table';
  @override
  String get hwPracticalTips => 'Practical tips';
  @override
  String get hwRecommendedModel => 'Recommended model';
  @override
  String get hwApproxSpeed => 'Approx. speed';
  @override
  String get hwVramApprox => 'Approx. VRAM';
  @override
  String get hwPracticalTipsBody =>
      '• Context window in Settings: each 1K tokens ≈ 0.5–1 GB extra VRAM\n'
      '• System RAM: keep at least 8 GB free beyond VRAM for OS and Ollama\n'
      '• Linux: use ollama ps to see actual usage\n'
      '• If OOM: try a smaller model or lower num_ctx in Modelfile';
  @override
  List<({String ram, String vram, String models, String speed, String note})>
      get hwTiers => [
            (
              ram: '8 GB',
              vram: '—',
              models: 'llama3.2:1b, phi3:mini',
              speed: '5–15 tok/s',
              note: 'Good for testing and light chat.',
            ),
            (
              ram: '16 GB',
              vram: '6 GB',
              models: 'llama3.2:3b, mistral:7b-q4',
              speed: '8–25 tok/s',
              note: 'Solid for daily use.',
            ),
            (
              ram: '32 GB',
              vram: '8 GB',
              models: 'llama3.1:8b-q4, gemma2:9b',
              speed: '30–50 tok/s',
              note: 'Comfortable for most tasks.',
            ),
            (
              ram: '32 GB',
              vram: '12 GB',
              models: 'llama3.1:8b, qwen2.5:14b-q4',
              speed: '40–70 tok/s',
              note: 'Good balance of speed and quality.',
            ),
            (
              ram: '64 GB',
              vram: '16 GB',
              models: 'llama3.1:70b-q4, qwen2.5:32b',
              speed: '35–60 tok/s',
              note: 'Large models with GPU.',
            ),
            (
              ram: '64 GB+',
              vram: '24 GB',
              models: 'llama3.1:70b, mixtral:8x7b-q4',
              speed: '25–55 tok/s',
              note: 'High-end local inference.',
            ),
            (
              ram: '128 GB+',
              vram: '48 GB+',
              models: '70B+ FP16, multi-GPU',
              speed: '20–80 tok/s',
              note: 'Workstation / server setup.',
            ),
          ];

  @override
  String get genericError => 'Error';
  @override
  String get invalidCustomHeadersJson =>
      'Custom Headers: invalid JSON format';
  @override
  String modelsLoaded(int count) => '✓ $count models';
  @override
  String get noModelFound => 'No models found';
  @override
  String get noModelSelectedToast => 'No model selected';
  @override
  String get modelNoVision =>
      'Selected model does not support images';
  @override
  String get modelNoAudio =>
      'Selected model does not support audio input';
  @override
  String get thinkingOn => 'Thinking enabled';
  @override
  String get thinkingOff => 'Thinking disabled';
  @override
  String get profileUpdated => '✦ Profile updated';
  @override
  String get messageLoaded => 'Message loaded into input';
  @override
  String get imageModelNotSelected => 'No image model selected';
  @override
  String get imageModelNotSuitable =>
      'Selected model is not suitable for image generation';
  @override
  String get settingsSaved => 'Settings saved ✓';
  @override
  String get profileSaved => 'Profile saved ✓';
  @override
  String get promptSaved => 'Prompt saved ✓';
  @override
  String get saved => 'Saved';
  @override
  String get imported => 'Imported';
  @override
  String get noOpenChat => 'No chat is open';
  @override
  String get newChatTitle => 'New chat';
  @override
  String get chatTitleFallback => 'Chat';

  @override
  String get chatNotFound => 'Chat not found';
  @override
  String get invalidFileFormat => 'Invalid file format';
  @override
  String get saveFileWebUnsupported =>
      'Saving files is not supported on web';
  @override
  String get saveBackup => 'Save backup';
  @override
  String get cancelled => 'Cancelled';
  @override
  String chatsSaved(int count) => '✓ $count chats saved';
  @override
  String get noChatsToExport => 'No chats to export';
  @override
  String get importFileWebUnsupported =>
      'Importing files is not supported on web';
  @override
  String get selectBackupFile => 'Select backup file';
  @override
  String get emptyOrInvalidFile => 'File is empty or invalid';
  @override
  String jsonReadError(String e) => 'JSON read error: $e';
  @override
  String get backupHasNoChats => 'Backup file has no chats';
  @override
  String chatsImported(int chats, int messages) =>
      '✓ $chats chats and $messages messages imported';

  @override
  String get installLinuxOnly =>
      'Automatic install is only supported on Linux.';
  @override
  String get downloadingOllama => 'Downloading and installing Ollama…';
  @override
  String installFailed(int code) =>
      'Install failed (code $code). Root access required.';
  @override
  String get installComplete =>
      'Install complete. Enabling systemd service…';
  @override
  String get installDoneApiUnavailable =>
      'Installed but API is not available yet. Start the service manually.';
  @override
  String get enablingOllamaService => 'Enabling ollama service…';
  @override
  String get ollamaServiceEnabled => 'Ollama service enabled.';
  @override
  String get serviceEnableFailed =>
      'Failed to enable service. Try: sudo systemctl enable --now ollama';
  @override
  String get localRunWebUnsupported =>
      'Local execution is not supported on web.';
  @override
  String get ollamaCommandNotFound => 'ollama command not found.';
  @override
  String get runningOllamaServe => 'Running ollama serve in background…';
  @override
  String get processStartedWait =>
      'Process started; wait a few seconds.';

  @override
  String get pullingManifest => 'Pulling manifest…';
  @override
  String get downloadingLayers => 'Downloading layers…';
  @override
  String get verifyingChecksum => 'Verifying checksum…';
  @override
  String get installSuccess => 'Installed ✓';
  @override
  String get downloading => 'Downloading…';

  @override
  String get downloadingTab => 'Downloading';
  @override
  String get noActiveDownloads => 'No downloads in progress';
  @override
  String get downloadPaused => 'Paused';
  @override
  String get pauseDownload => 'Pause';
  @override
  String get resumeDownload => 'Resume';
  @override
  String get cancelDownload => 'Cancel';
  @override
  String get downloadQueued => 'Queued';
  @override
  String get etaRemaining => 'Calculating…';
  @override
  String etaSeconds(int seconds) => '${seconds}s left';
  @override
  String etaMinutesSeconds(int minutes, int seconds) =>
      '${minutes}m ${seconds}s left';
  @override
  String etaHoursMinutes(int hours, int minutes) =>
      '${hours}h ${minutes}m left';
  @override
  String get noModelsInstalledHint =>
      'No models installed — browse the Library tab to install one';

  @override
  String get audioRecordUnsupported =>
      'Audio recording is not supported on this platform';
  @override
  String get microphoneDenied => 'Microphone permission denied';
  @override
  String get audioFileNotSaved => 'Audio file was not saved';
  @override
  String get audioFileNotFound => 'Audio file not found';
  @override
  String get audioRecordEmpty => 'Recording was empty';

  @override
  String get promptOrImageRequired => 'Prompt or reference image required';
  @override
  String get noImageReturned => 'No image returned';
  @override
  String get imageDownloadFailed => 'Image download failed';
  @override
  String get imageFormatUnsupported =>
      'Image response format not supported';

  @override
  Map<String, String> get extractFieldLabels => const {
        'name': 'Name',
        'role': 'Role',
        'skills': 'Skills',
        'project': 'Project',
        'preference': 'Preference',
        'location': 'Location',
        'education': 'Education',
        'other': 'Other',
      };

  @override
  String dateTimeLabel(String dt) => 'Date/time: $dt';
  @override
  String userInfoLabel(String info) => 'User info:\n$info';

  @override
  List<({String label, String text})> get promptPresets => const [
        (
          label: '🤖 Assistant',
          text:
              'You are a helpful assistant. Answer accurately, usefully, and honestly.',
        ),
        (
          label: '💻 Coder',
          text:
              'You are a programming expert. Always answer with code examples in code blocks.',
        ),
        (
          label: '📚 Teacher',
          text:
              'You are a patient teacher. Explain with examples, from simple to complex.',
        ),
        (
          label: '✍️ Editor',
          text:
              'You are a professional editor. Find grammar issues and suggest improvements.',
        ),
        (
          label: '🔍 Analyst',
          text:
              'You are a precise analyst. Examine with reasoning and evidence.',
        ),
        (
          label: '🌐 Translator',
          text:
              'You are a professional translator. Write fluent, natural translations.',
        ),
      ];

  @override
  String fileAttachment(String name) => '\n\n--- File: $name ---\n';
}
