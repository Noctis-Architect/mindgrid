import 'package:flutter/material.dart';

import 'app_strings.dart';

class StringsFa extends AppStrings {
  @override
  String get appName => 'MindGrid';
  @override
  String get loading => 'در حال بارگذاری…';
  @override
  String get language => 'زبان';
  @override
  String get languageEn => 'English';
  @override
  String get languageFa => 'فارسی';

  @override
  String get newChat => 'چت جدید';
  @override
  String get close => 'بستن';
  @override
  String get conversations => 'مکالمات';
  @override
  String get noConversationsYet => 'هنوز مکالمه‌ای ندارید';
  @override
  String get delete => 'حذف';
  @override
  String get cancel => 'انصراف';
  @override
  String get deleteConversation => 'حذف مکالمه';
  @override
  String get deleteConversationConfirm =>
      'این مکالمه برای همیشه حذف می‌شود؟';
  @override
  String get imageGeneration => 'ساخت تصویر';
  @override
  String get backupExport => 'بکاپ / اکسپورت';
  @override
  String get ollamaManager => 'مرکز مدل‌ها';
  @override
  String get promptEngineering => 'Prompt Engineering';
  @override
  String get userProfile => 'پروفایل کاربری';
  @override
  String get settings => 'تنظیمات';
  @override
  String get today => 'امروز';
  @override
  String get yesterday => 'دیروز';

  @override
  String get clearConversation => 'پاک کردن مکالمه';
  @override
  String get clearConversationConfirm =>
      'همه پیام‌های این مکالمه پاک می‌شوند؟';
  @override
  String get clear => 'پاک کن';
  @override
  String get contextWindow => 'پنجره Context';

  @override
  String get welcomeTitle => 'چطور می‌تونم کمکت کنم؟';
  @override
  String get welcomeSubtitle =>
      'از پیشنهادهای زیر شروع کن یا هر سوالی داری بپرس';
  @override
  String get welcomeSuggestionsRefreshing => 'در حال شخصی‌سازی پیشنهادها…';
  @override
  List<({String label, IconData icon, String prompt})> get welcomeSuggestions => [
        (
          label: 'ترنسفورمرها',
          icon: Icons.psychology_outlined,
          prompt: 'توضیح بده ترنسفورمرها در یادگیری ماشین چطور کار می‌کنند',
        ),
        (
          label: 'پارسر JSON',
          icon: Icons.code_rounded,
          prompt: 'یک تابع پایتون بنویس که JSON را پارس کند و خطاها را مدیریت کند',
        ),
        (
          label: 'REST در برابر GraphQL',
          icon: Icons.compare_arrows_rounded,
          prompt: 'تفاوت‌های کلیدی REST و GraphQL چیست؟',
        ),
        (
          label: 'بازبینی کد',
          icon: Icons.rate_review_outlined,
          prompt: 'کدم را بازبینی کن و پیشنهاد بهبود بده',
        ),
      ];

  @override
  String get inputHintOllama =>
      'پیامی به Ollama بنویس… (Shift+Enter خط جدید)';
  @override
  String get inputHint => 'پیامی بنویس… (Shift+Enter خط جدید)';
  @override
  String get attachFile => 'پیوست فایل';
  @override
  String get attachImage => 'پیوست تصویر';
  @override
  String get attachImageNeedsVision =>
      'پیوست تصویر (نیاز به مدل vision)';
  @override
  String get stopRecording => 'توقف ضبط';
  @override
  String get recordAudio => 'ضبط صدا';
  @override
  String get recordAudioNeedsModel =>
      'نیاز به مدل صوتی (مثل gemma4)';
  @override
  String get recordingProgress => 'در حال ضبط…';
  @override
  String audioFileLabel(String duration) =>
      duration.isNotEmpty ? 'صدا · $duration' : 'فایل صوتی';
  @override
  String get processAudioFile => 'این فایل صوتی را پردازش کن.';
  @override
  String get disclaimer =>
      'MindGrid می‌تواند اشتباه کند. اطلاعات مهم را تأیید کنید.';
  @override
  String fileTooLarge(String name) => '$name خیلی بزرگه';
  @override
  String fileTooLargeMax(String name) =>
      '$name خیلی بزرگه (حداکثر ۱۰MB)';
  @override
  String readImageFailed(String name) =>
      '$name: خواندن تصویر ناموفق';
  @override
  String get selectVisionModel =>
      'برای ارسال تصویر یک مدل vision انتخاب کنید';
  @override
  String get imageOnlyPrompt => 'این تصویر را توصیف کن.';
  @override
  String dropFileError(String name) =>
      '$name: فقط فایل متنی یا تصویر (با مدل vision)';
  @override
  String get audioNotSupported =>
      'ضبط صدا در این پلتفرم پشتیبانی نمی‌شود';
  @override
  String get selectAudioModel =>
      'برای ضبط صدا یک مدل صوتی (مثل gemma4) انتخاب کنید';
  @override
  String get audioSaved => '✓ ضبط صدا ذخیره شد';

  @override
  String get stopped => 'متوقف شد';
  @override
  String get showThinking => 'مشاهده فرآیند تفکر';
  @override
  String get hideThinking => 'پنهان کردن تفکر';
  @override
  String get copy => 'کپی';
  @override
  String get copied => 'کپی شد';
  @override
  String get retry => 'تلاش مجدد';
  @override
  String get share => 'اشتراک';
  @override
  String get edit => 'ویرایش';
  @override
  String get otherModel => 'مدل دیگر';
  @override
  String get me => 'من';
  @override
  String get expand => 'باز کردن';
  @override
  String get collapse => 'جمع کردن';
  @override
  String lineCount(int n) => '$n خط';

  @override
  String get selectModel => 'انتخاب مدل';
  @override
  String get noModelsFound => 'مدلی یافت نشد';
  @override
  String get search => 'جستجو...';
  @override
  String get noModelSelected => 'مدلی انتخاب نشده';

  @override
  String get settingsTitle => 'تنظیمات';
  @override
  String get tabGeneral => 'عمومی';
  @override
  String get tabApi => 'API / Provider';
  @override
  String get tabAutoExtract => 'Auto-extract';
  @override
  String get tabAdvanced => 'پیشرفته';
  @override
  String get saveSettings => 'ذخیره تنظیمات';
  @override
  String get creativity => 'خلاقیت (Temperature)';
  @override
  String get maxOutputTokens => 'حداکثر توکن خروجی';
  @override
  String get contextMessageCount => 'تعداد پیام در Context';
  @override
  String get streaming => 'Streaming';
  @override
  String get streamingSubtitle =>
      'پاسخ‌ها به صورت زنده نمایش داده شوند';
  @override
  String get thinkingMode => 'Thinking mode';
  @override
  String get thinkingModeOllama =>
      'فعال‌سازی تفکر مدل (Ollama think API)';
  @override
  String get thinkingModeOllamaOnly =>
      'فقط برای provider محلی Ollama';
  @override
  String get provider => 'Provider';
  @override
  String get ollamaUrl => 'Ollama URL';
  @override
  String get searching => 'در حال جستجو...';
  @override
  String get discoverOllama => 'جستجوی Ollama در شبکه';
  @override
  String get baseUrl => 'Base URL';
  @override
  String get apiKeys => 'کلیدهای API';
  @override
  String get savedKey => 'کلید ذخیره‌شده';
  @override
  String get newKey => '— کلید جدید —';
  @override
  String get keyName => 'نام کلید';
  @override
  String get deleteKey => 'حذف کلید';
  @override
  String get apiKey => 'API Key';
  @override
  String get manualModelName => 'نام مدل (دستی)';
  @override
  String get requestTimeout => 'Request Timeout (ms)';
  @override
  String get customHeaders => 'Custom Headers (JSON)';
  @override
  String get autoExtractDescription =>
      'بعد از هر پیام، هوش مصنوعی اطلاعات مهم را شناسایی و در پروفایل کاربر ذخیره می‌کند.';
  @override
  String get autoExtract => 'استخراج خودکار';
  @override
  String get autoExtractSubtitle =>
      'شناسایی و ذخیره اطلاعات مهم کاربر';
  @override
  String get extractProvider => 'Provider استخراج';
  @override
  String get extractModel => 'مدل استخراج';
  @override
  String get sameChatModel => 'همان مدل مکالمه';
  @override
  String get extractModelManual => 'یا نام مدل را بنویسید';
  @override
  String get extractionPrompt => 'Extraction Prompt';
  @override
  String get advancedWarning =>
      'عملیات این بخش برگشت‌ناپذیر هستند.';
  @override
  String get clearAllData => 'پاک کردن همه داده‌ها';
  @override
  String get clearAllDataConfirm =>
      'تمام مکالمات و تنظیمات حذف می‌شوند. ادامه؟';
  @override
  String get deleteApiKey => 'حذف کلید API';
  @override
  String deleteApiKeyConfirm(String name) => 'کلید «$name» حذف شود؟';
  @override
  String get apiKeyDeleted => 'کلید حذف شد';

  @override
  String get clearProfile => 'پاک کردن پروفایل';
  @override
  String get clearProfileConfirm =>
      'تمام اطلاعات ذخیره‌شده پروفایل حذف شود؟';
  @override
  String get profileInfo => 'اطلاعات پروفایل';
  @override
  String get profileHint =>
      'مثلاً: من یک توسعه‌دهنده پایتون هستم که روی اپ‌های وب کار می‌کنم…';
  @override
  String get profileDescription =>
      'این اطلاعات در هر مکالمه به‌عنوان زمینه برای مدل تزریق می‌شود.';
  @override
  String get unsavedChanges => 'تغییرات ذخیره‌نشده';
  @override
  String get saveProfile => 'ذخیره پروفایل';

  @override
  String get backupRestore => 'بکاپ و بازیابی';
  @override
  String get exportSection => 'اکسپورت';
  @override
  String get exportAllChats => 'اکسپورت همه چت‌ها';
  @override
  String get exportAllChatsSubtitle =>
      'ذخیره همه مکالمات در فایل JSON';
  @override
  String get exportCurrentChat => 'اکسپورت چت فعلی';
  @override
  String get exportCurrentChatSubtitle =>
      'ذخیره فقط مکالمه فعال فعلی';
  @override
  String get importSection => 'وارد کردن';
  @override
  String get importMerge => 'وارد کردن (ادغام)';
  @override
  String get importMergeSubtitle =>
      'افزودن چت‌ها از فایل در کنار مکالمات موجود';
  @override
  String get importReplace => 'وارد کردن (جایگزینی)';
  @override
  String get importReplaceSubtitle =>
      'حذف همه چت‌های فعلی و جایگزینی با فایل';
  @override
  String get replaceAllChats => 'جایگزینی همه چت‌ها';
  @override
  String get replaceAllChatsConfirm =>
      'همه چت‌های فعلی برای همیشه حذف و با فایل واردشده جایگزین می‌شوند. ادامه؟';
  @override
  String get replace => 'جایگزین';
  @override
  String savedConversations(int count) => '$count مکالمه ذخیره‌شده';
  @override
  String get processing => 'در حال پردازش…';

  @override
  String get presetRoles => 'نقش‌های از پیش‌تعریف';
  @override
  String get presetApplied => 'پرست اعمال شد';
  @override
  String get save => 'ذخیره';
  @override
  String get systemPromptLabel =>
      'system — در ابتدای هر مکالمه ارسال می‌شود';
  @override
  String get systemPromptHint => 'تو یک دستیار مفید هستی…';
  @override
  String get variables => 'متغیرها {{key}}';
  @override
  String get add => '+ افزودن';
  @override
  String get key => 'کلید';
  @override
  String get value => 'مقدار';
  @override
  String get injectUserProfile => 'پروفایل کاربر';
  @override
  String get injectUserProfileSubtitle =>
      'تزریق اطلاعات کاربر به system prompt';
  @override
  String get conversationHistory => 'تاریخچه مکالمه';
  @override
  String get dateTime => 'تاریخ و زمان';
  @override
  String get fullPayload => 'پیلود کامل (فرمت OpenAI)';
  @override
  String get customPayloadApplied => 'پیلود سفارشی اعمال شد ✓';
  @override
  String get apply => '✓ اعمال';
  @override
  String get reset => '↺ بازنشانی';
  @override
  String get jsonCopied => 'JSON کپی شد ✓';

  @override
  String get imageGenTitle => 'ساخت تصویر';
  @override
  String get imageGenDescription =>
      'با یک مدل تصویری، از روی پرامپت یا تصویر مرجع (+ پرامپت اختیاری) تصویر بسازید.';
  @override
  String get prompt => 'پرامپت';
  @override
  String get promptHint => 'مثلاً: یک گربه فضانورد روی ماه...';
  @override
  String get generating => 'در حال ساخت...';
  @override
  String get generateImage => 'ساخت تصویر';
  @override
  String get result => 'نتیجه';
  @override
  String get saveImage => 'ذخیره';
  @override
  String get help => 'راهنما';
  @override
  String get imageGenNoModels =>
      'مدل تصویری یافت نشد.\nبرای Ollama مدل‌های flux یا stable-diffusion را نصب کنید.\nبرای API آنلاین (OpenAI و...) کلید API را در تنظیمات وارد کنید.';
  @override
  String get refreshModels => 'بروزرسانی مدل‌ها';
  @override
  String get imageModel => 'مدل تصویری';
  @override
  String get referenceImage => 'تصویر مرجع (اختیاری)';
  @override
  String get selectReferenceImage => 'انتخاب تصویر مرجع';
  @override
  String get enterPromptOrImage => 'پرامپت یا تصویر مرجع وارد کنید';
  @override
  String get noImageModelSelected => 'مدل تصویری انتخاب نشده';
  @override
  String get imageTooLarge => 'تصویر خیلی بزرگه (حداکثر ۱۰MB)';
  @override
  String get saveNotSupportedWeb =>
      'ذخیره فایل در وب پشتیبانی نمی‌شود';
  @override
  String get useSaveButton => 'از دکمه ذخیره استفاده کنید';
  @override
  String get imageSaved => 'ذخیره شد ✓';

  @override
  String get ollamaManagerTitle => 'مرکز مدل‌ها';
  @override
  String get refresh => 'بروزرسانی';
  @override
  String get library => 'کتابخانه';
  @override
  String get installed => 'نصب‌شده';
  @override
  String get hardwareGuide => 'راهنمای سخت‌افزار';
  @override
  String get searchModels => 'جستجوی مدل، پارامتر یا کوانتایز…';
  @override
  String get installOnLinux => 'نصب روی لینوکس';
  @override
  String get installLinuxDescription =>
      'Ollama به‌صورت خودکار نصب می‌شود. نیاز به دسترسی مدیر (sudo/pkexec) دارد. '
      'پس از نصب، سرویس systemd فعال می‌شود تا Ollama در پس‌زمینه اجرا شود.';
  @override
  String get installOllama => 'نصب Ollama';
  @override
  String get startSystemdService => 'راه‌اندازی سرویس systemd';
  @override
  String get manualCommands => 'دستورات دستی';
  @override
  String get installOnWindows => 'نصب روی ویندوز';
  @override
  String get installWindowsSteps =>
      '۱. OllamaSetup.exe را از GitHub دانلود کنید.\n'
      '۲. نصب‌کننده را اجرا کنید.\n'
      '۳. پس از نصب، Ollama خودکار در system tray اجرا می‌شود.\n'
      '۴. به اینجا برگردید و دکمه بروزرسانی را بزنید.';
  @override
  String get downloadFromGitHub => 'دانلود از GitHub';
  @override
  String get ollamaNotAvailable => 'Ollama در دسترس نیست';
  @override
  String get ollamaNotAvailableDescription =>
      'برای استفاده از Ollama، آن را روی سیستم یا شبکه نصب و اجرا کنید، '
      'سپس URL را در تنظیمات پیکربندی کنید.';
  @override
  String get noModelsInstalled =>
      'مدلی نصب نشده — از تب کتابخانه یک مدل نصب کنید';
  @override
  String get loadingModels => 'در حال بارگذاری…';
  @override
  String get deleteModel => 'حذف مدل';
  @override
  String deleteModelConfirm(String name) =>
      'مدل «$name» از Ollama حذف شود؟';
  @override
  String modelRemoved(String name) => '✓ $name حذف شد';
  @override
  String modelInstalled(String name) => '✓ $name نصب شد';
  @override
  String get failedToOpenLink => 'باز کردن لینک ناموفق بود';
  @override
  String error(String e) => 'خطا: $e';
  @override
  String get running => 'در حال اجرا';
  @override
  String get stoppedStatus => 'متوقف';
  @override
  String get notInstalled => 'نصب نشده';
  @override
  String get unsupported => 'پشتیبانی نمی‌شود';
  @override
  String get ollamaRunning => 'Ollama در حال اجراست';
  @override
  String get ollamaRunningSubtitle =>
      'می‌توانید مدل‌ها را نصب و مدیریت کنید.';
  @override
  String get ollamaStopped => 'Ollama نصب است اما اجرا نمی‌شود';
  @override
  String get ollamaStoppedSubtitle =>
      'سرویس را راه‌اندازی کنید.';
  @override
  String get ollamaNotInstalled => 'Ollama نصب نشده';
  @override
  String get ollamaNotInstalledSubtitle =>
      'Ollama را نصب کنید.';
  @override
  String get platformNotSupported => 'پلتفرم پشتیبانی نمی‌شود';
  @override
  String get platformNotSupportedSubtitle =>
      'نصب محلی روی این پلتفرم در دسترس نیست.';
  @override
  String get expandVariants => 'برای دیدن variantها باز کنید';
  @override
  String variantsInfo(int variants, int installed) =>
      '$variants variant · $installed نصب‌شده';
  @override
  String get audio => 'صدا';
  @override
  String get vision => 'vision';
  @override
  String get noVariantsFound => 'variantی یافت نشد';
  @override
  String get install => 'نصب';

  @override
  String get hwHowToChoose => 'چطور مدل مناسب انتخاب کنیم؟';
  @override
  String get hwHowToChooseText =>
      'حجم مدل (مثلاً 7B = ۷ میلیارد پارامتر) و نوع کوانتیزاسیون (Q4، Q8، FP16) '
      'مشخص می‌کنند چقدر RAM/VRAM لازم است. Q4 حدود نصف FP16 حافظه می‌گیرد '
      'با افت کیفیت کم. برای چت روزمره Q4_K_M توصیه می‌شود.';
  @override
  String get hwSpeed => 'سرعت (توکن بر ثانیه)';
  @override
  String get hwSpeedText =>
      'روی GPU معمولاً ۳۰–۱۰۰ tok/s؛ روی CPU ۵–۳۰ tok/s. '
      'اگر پاسخ کند است: مدل کوچک‌تر، Q4، یا context کمتر (مثلاً ۴۰۹۶) امتحان کنید.';
  @override
  String get hwQuantization => 'کوانتیزاسیون';
  @override
  String get hwQuantizationText =>
      'در نام مدل: llama3.2:3b = پیش‌فرض، :3b-instruct-q4_K_M = Q4';
  @override
  String get hwTable => 'جدول سخت‌افزار';
  @override
  String get hwPracticalTips => 'نکات عملی';
  @override
  String get hwRecommendedModel => 'مدل پیشنهادی';
  @override
  String get hwApproxSpeed => 'سرعت تقریبی';
  @override
  String get hwVramApprox => 'VRAM تقریبی';
  @override
  String get hwPracticalTipsBody =>
      '• Context window در Settings: هر ۱K توکن ≈ ۰.۵–۱ GB VRAM اضافه\n'
      '• RAM سیستم: حداقل ۸ GB بیش از VRAM برای OS و Ollama\n'
      '• لینوکس: ollama ps برای دیدن مصرف واقعی\n'
      '• اگر OOM: مدل کوچک‌تر یا num_ctx کمتر در Modelfile';
  @override
  List<({String ram, String vram, String models, String speed, String note})>
      get hwTiers => [
            (
              ram: '۸ GB',
              vram: '—',
              models: 'llama3.2:1b، phi3:mini',
              speed: '۵–۱۵ tok/s',
              note: 'مناسب تست و چت سبک.',
            ),
            (
              ram: '۱۶ GB',
              vram: '۶ GB',
              models: 'llama3.2:3b، mistral:7b-q4',
              speed: '۸–۲۵ tok/s',
              note: 'مناسب استفاده روزمره.',
            ),
            (
              ram: '۳۲ GB',
              vram: '۸ GB',
              models: 'llama3.1:8b-q4، gemma2:9b',
              speed: '۳۰–۵۰ tok/s',
              note: 'راحت برای اکثر کارها.',
            ),
            (
              ram: '۳۲ GB',
              vram: '۱۲ GB',
              models: 'llama3.1:8b، qwen2.5:14b-q4',
              speed: '۴۰–۷۰ tok/s',
              note: 'تعادل خوب سرعت و کیفیت.',
            ),
            (
              ram: '۶۴ GB',
              vram: '۱۶ GB',
              models: 'llama3.1:70b-q4، qwen2.5:32b',
              speed: '۳۵–۶۰ tok/s',
              note: 'مدل‌های بزرگ با GPU.',
            ),
            (
              ram: '۶۴ GB+',
              vram: '۲۴ GB',
              models: 'llama3.1:70b، mixtral:8x7b-q4',
              speed: '۲۵–۵۵ tok/s',
              note: 'استنتاج محلی پیشرفته.',
            ),
            (
              ram: '۱۲۸ GB+',
              vram: '۴۸ GB+',
              models: '70B+ FP16، multi-GPU',
              speed: '۲۰–۸۰ tok/s',
              note: 'راه‌اندازی workstation / سرور.',
            ),
          ];

  @override
  String get genericError => 'خطا';
  @override
  String get invalidCustomHeadersJson =>
      'Custom Headers: فرمت JSON اشتباه است';
  @override
  String modelsLoaded(int count) => '✓ $count مدل';
  @override
  String get noModelFound => 'مدلی یافت نشد';
  @override
  String get noModelSelectedToast => 'مدلی انتخاب نشده';
  @override
  String get modelNoVision =>
      'مدل انتخاب‌شده از تصویر پشتیبانی نمی‌کند';
  @override
  String get modelNoAudio =>
      'مدل انتخاب‌شده از ورودی صدا پشتیبانی نمی‌کند';
  @override
  String get thinkingOn => 'Thinking روشن شد';
  @override
  String get thinkingOff => 'Thinking خاموش شد';
  @override
  String get profileUpdated => '✦ پروفایل به‌روز شد';
  @override
  String get messageLoaded => 'پیام در ورودی بارگذاری شد';
  @override
  String get imageModelNotSelected => 'مدل تصویری انتخاب نشده';
  @override
  String get imageModelNotSuitable =>
      'مدل انتخاب‌شده برای ساخت تصویر مناسب نیست';
  @override
  String get settingsSaved => 'تنظیمات ذخیره شد ✓';
  @override
  String get profileSaved => 'پروفایل ذخیره شد ✓';
  @override
  String get promptSaved => 'پرامپت ذخیره شد ✓';
  @override
  String get saved => 'ذخیره شد';
  @override
  String get imported => 'وارد شد';
  @override
  String get noOpenChat => 'چتی باز نیست';
  @override
  String get newChatTitle => 'چت جدید';
  @override
  String get chatTitleFallback => 'چت';

  @override
  String get chatNotFound => 'چت یافت نشد';
  @override
  String get invalidFileFormat => 'فرمت فایل نامعتبر است';
  @override
  String get saveFileWebUnsupported =>
      'ذخیره فایل در نسخه وب پشتیبانی نمی‌شود';
  @override
  String get saveBackup => 'ذخیره بکاپ';
  @override
  String get cancelled => 'لغو شد';
  @override
  String chatsSaved(int count) => '✓ $count چت ذخیره شد';
  @override
  String get noChatsToExport => 'چتی برای اکسپورت وجود ندارد';
  @override
  String get importFileWebUnsupported =>
      'وارد کردن فایل در نسخه وب پشتیبانی نمی‌شود';
  @override
  String get selectBackupFile => 'انتخاب فایل بکاپ';
  @override
  String get emptyOrInvalidFile => 'فایل خالی یا نامعتبر است';
  @override
  String jsonReadError(String e) => 'خطا در خواندن JSON: $e';
  @override
  String get backupHasNoChats => 'فایل بکاپ چتی ندارد';
  @override
  String chatsImported(int chats, int messages) =>
      '✓ $chats چت و $messages پیام وارد شد';

  @override
  String get installLinuxOnly =>
      'نصب خودکار فقط روی لینوکس پشتیبانی می‌شود.';
  @override
  String get downloadingOllama => 'در حال دانلود و نصب Ollama…';
  @override
  String installFailed(int code) =>
      'نصب ناموفق بود (کد $code). دسترسی root لازم است.';
  @override
  String get installComplete =>
      'نصب کامل شد. فعال‌سازی سرویس systemd…';
  @override
  String get installDoneApiUnavailable =>
      'نصب انجام شد اما API هنوز در دسترس نیست. سرویس را دستی راه‌اندازی کنید.';
  @override
  String get enablingOllamaService => 'فعال‌سازی سرویس ollama…';
  @override
  String get ollamaServiceEnabled => 'سرویس ollama فعال شد.';
  @override
  String get serviceEnableFailed =>
      'فعال‌سازی سرویس ناموفق بود. sudo systemctl enable --now ollama';
  @override
  String get localRunWebUnsupported =>
      'اجرای محلی در وب پشتیبانی نمی‌شود.';
  @override
  String get ollamaCommandNotFound => 'دستور ollama یافت نشد.';
  @override
  String get runningOllamaServe => 'اجرای ollama serve در پس‌زمینه…';
  @override
  String get processStartedWait =>
      'فرآیند شروع شد؛ چند ثانیه صبر کنید.';

  @override
  String get pullingManifest => 'دریافت manifest…';
  @override
  String get downloadingLayers => 'دانلود لایه‌ها…';
  @override
  String get verifyingChecksum => 'بررسی checksum…';
  @override
  String get installSuccess => 'نصب شد ✓';
  @override
  String get downloading => 'در حال دانلود…';

  @override
  String get downloadingTab => 'دانلودها';
  @override
  String get noActiveDownloads => 'دانلودی در جریان نیست';
  @override
  String get downloadPaused => 'متوقف شده';
  @override
  String get pauseDownload => 'توقف';
  @override
  String get resumeDownload => 'ادامه';
  @override
  String get cancelDownload => 'لغو';
  @override
  String get downloadQueued => 'در صف';
  @override
  String get etaRemaining => 'در حال محاسبه…';
  @override
  String etaSeconds(int seconds) => '$seconds ثانیه مانده';
  @override
  String etaMinutesSeconds(int minutes, int seconds) =>
      '$minutes دقیقه و $seconds ثانیه مانده';
  @override
  String etaHoursMinutes(int hours, int minutes) =>
      '$hours ساعت و $minutes دقیقه مانده';
  @override
  String get noModelsInstalledHint =>
      'مدلی نصب نشده — از تب کتابخانه یک مدل نصب کنید';

  @override
  String get audioRecordUnsupported =>
      'ضبط صدا در این پلتفرم پشتیبانی نمی‌شود';
  @override
  String get microphoneDenied => 'دسترسی میکروفون رد شد';
  @override
  String get audioFileNotSaved => 'فایل صوتی ذخیره نشد';
  @override
  String get audioFileNotFound => 'فایل صوتی یافت نشد';
  @override
  String get audioRecordEmpty => 'ضبط صدا خالی بود';

  @override
  String get promptOrImageRequired => 'پرامپت یا تصویر مرجع لازم است';
  @override
  String get noImageReturned => 'تصویری برنگشت';
  @override
  String get imageDownloadFailed => 'دانلود تصویر ناموفق بود';
  @override
  String get imageFormatUnsupported =>
      'فرمت پاسخ تصویر پشتیبانی نمی‌شود';

  @override
  Map<String, String> get extractFieldLabels => const {
        'name': 'نام',
        'role': 'نقش',
        'skills': 'مهارت',
        'project': 'پروژه',
        'preference': 'ترجیح',
        'location': 'مکان',
        'education': 'تحصیلات',
        'other': 'سایر',
      };

  @override
  String dateTimeLabel(String dt) => 'تاریخ/زمان: $dt';
  @override
  String userInfoLabel(String info) => 'اطلاعات کاربر:\n$info';

  @override
  List<({String label, String text})> get promptPresets => const [
        (
          label: '🤖 دستیار',
          text:
              'تو یک دستیار هوشمند فارسی‌زبان هستی. دقیق، مفید و صادق جواب بده.',
        ),
        (
          label: '💻 کدنویس',
          text:
              'تو یک متخصص برنامه‌نویسی هستی. همیشه با مثال کد جواب بده. کدها داخل code block باشن. پاسخ فارسی مگر زبان دیگری خواسته بشه.',
        ),
        (
          label: '📚 معلم',
          text:
              'تو یک معلم صبور هستی. با مثال توضیح بده، از ساده به پیچیده برو.',
        ),
        (
          label: '✍️ ویراستار',
          text:
              'تو ویراستار حرفه‌ای متن فارسی هستی. غلط‌های نگارشی پیدا کن و پیشنهاد بده.',
        ),
        (
          label: '🔍 تحلیلگر',
          text: 'تو تحلیلگر دقیق هستی. با دلیل و مدرک بررسی کن.',
        ),
        (
          label: '🌐 مترجم',
          text: 'تو مترجم حرفه‌ای هستی. ترجمه روان و طبیعی بنویس.',
        ),
      ];

  @override
  String fileAttachment(String name) => '\n\n--- فایل: $name ---\n';

  @override
  String get earlier =>
      'قبل‌تر';
  @override
  String get toggleSidebar =>
      'نمایش/پنهان‌کردن نوار کناری';
  @override
  String get searchChats =>
      'جستجوی گفتگوها';
  @override
  String get noResults =>
      'نتیجه‌ای پیدا نشد';
  @override
  String get hubImport =>
      'نصب GGUF';
  @override
  String get clearFinished =>
      'پاک‌کردن تمام‌شده‌ها';
  @override
  String get installOnMac =>
      'نصب روی macOS';
  @override
  String get installMacSteps =>
      '۱. Ollama را برای macOS دانلود کنید.\n۲. آن را به Applications منتقل و باز کنید.\n۳. Ollama در نوار منو در حال اجرا می‌ماند.\n۴. به اینجا برگردید و دکمه‌ی تازه‌سازی را بزنید.';
  @override
  String get downloadForMac =>
      'دانلود برای macOS';
  @override
  String get stageHashing =>
      'در حال بررسی فایل (SHA-256)…';
  @override
  String get stageUploading =>
      'در حال ارسال به Ollama…';
  @override
  String get stageCreating =>
      'در حال ساخت مدل…';
  @override
  String get reconnecting =>
      'اتصال قطع شد — در حال اتصال دوباره…';
  @override
  String get modelName =>
      'نام و تگ مدل';
  @override
  String get modelNameHint =>
      'قالب: name:tag — حروف کوچک انگلیسی، عدد، نقطه، خط تیره و زیرخط.';
  @override
  String get modelNameInvalid =>
      'نام نامعتبر است. از name:tag با حروف کوچک انگلیسی، عدد و . - _ استفاده کنید.';
  @override
  String get modelNameExists =>
      'مدلی با این نام وجود دارد و جایگزین می‌شود.';
  @override
  String get chatFormat =>
      'قالب گفتگو (Template)';
  @override
  String get formatAuto =>
      'خودکار — Ollama قالب را از خود GGUF بخواند';
  @override
  String copyFromInstalled(String name) =>
      'مثل مدل نصب‌شده: $name';
  @override
  String get formatNotDetected =>
      'قالب گفتگو تشخیص داده نشد. دستی انتخاب کنید، وگرنه مدل ممکن است هذیان بگوید.';
  @override
  String detectedVia(String reason) =>
      'تشخیص از روی $reason — قالب، توکن‌های توقف و پارامترها مطابق آن تنظیم شد.';
  @override
  String guessedVia(String reason) =>
      'حدس از روی $reason — لطفاً بررسی کنید.';
  @override
  String get formatManual =>
      'قالب به‌صورت دستی انتخاب شده است.';
  @override
  String get systemPromptOptional =>
      'پرامپت سیستمی (اختیاری)';
  @override
  String get advancedOptions =>
      'پیشرفته: قالب، توکن‌های توقف، پارامترها';
  @override
  String get modelfilePreview =>
      'پیش‌نمایش Modelfile';
  @override
  String get back =>
      'بازگشت';
  @override
  String get templateLabel =>
      'قالب (Go Template)';
  @override
  String get templateAutoHint =>
      'خالی — Ollama آن را از GGUF یا renderer پایین می‌گیرد.';
  @override
  String get stopSequences =>
      'توکن‌های توقف (Stop)';
  @override
  String get addStop =>
      'افزودن…';
  @override
  String get parametersLabel =>
      'پارامترها';
  @override
  String get chooseGgufFile =>
      'انتخاب فایل GGUF';
  @override
  String get notGgufFile =>
      'این فایل به‌عنوان GGUF قابل خواندن نیست.';
  @override
  String get hfInvalidLink =>
      'یک لینک Hugging Face یا owner/repo وارد کنید.';
  @override
  String get hfNoGguf =>
      'هیچ فایل GGUF در این مخزن پیدا نشد.';
  @override
  String queuedToast(String name) =>
      '$name به دانلودها اضافه شد';
  @override
  String get analyzingGguf =>
      'در حال خواندن متادیتای GGUF…';
  @override
  String get installToOllama =>
      'نصب روی Ollama';
  @override
  String get downloadAndInstall =>
      'دانلود و نصب';
  @override
  String get importLocalTitle =>
      'نصب از فایل GGUF';
  @override
  String get importLocalDesc =>
      'فایل ‎.gguf که قبلاً دانلود کرده‌اید را انتخاب کنید. مایندگرید متادیتا را می‌خواند و Modelfile درست می‌سازد.';
  @override
  String get importLocalDescDrop =>
      'فایل ‎.gguf را انتخاب کنید یا اینجا رها کنید. مایندگرید متادیتا را می‌خواند و Modelfile درست می‌سازد.';
  @override
  String get importHfTitle =>
      'دانلود از Hugging Face';
  @override
  String get importHfDesc =>
      'لینک مخزن یا فایل را بچسبانید. دانلود با قابلیت ادامه و سپس نصب خودکار.';
  @override
  String get hfConnection =>
      'تنظیمات اتصال';
  @override
  String get hfFindFiles =>
      'یافتن فایل‌ها';
  @override
  String get importHint =>
      'قالب گفتگو، توکن‌های توقف و پارامترها از روی خود GGUF تشخیص داده می‌شوند و مثل مدل‌های رسمی کتابخانه‌ی Ollama نوشته می‌شوند — تا تگ‌های thinking، فراخوانی ابزار و توکن پایان نوبت درست کار کنند.';
  @override
  String get hfEndpoint =>
      'آدرس Hub یا mirror';
  @override
  String get hfEndpointHelp =>
      'اگر huggingface.co روی شبکه‌ی شما بسته است از mirror استفاده کنید.';
  @override
  String get hfProxy =>
      'پروکسی HTTP (اختیاری)';
  @override
  String get hfProxyHelp =>
      'مثلاً پورت HTTP/mixed کلاینت VPN شما.';
  @override
  String get hfToken =>
      'توکن دسترسی (اختیاری)';
  @override
  String get hfTokenHelp =>
      'فقط برای مخزن‌های خصوصی یا دارای مجوز لازم است.';
  @override
  String get hfKeepFile =>
      'نگه‌داشتن فایل GGUF بعد از نصب';
  @override
  String get hfProjector =>
      'پروژکتور تصویر';
  @override
  String get hfSplitUnsupported =>
      'فایل چندتکه — پشتیبانی نمی‌شود';

  @override
  String get navChat =>
      'گفتگو';
  @override
  String get navModels =>
      'مدل‌ها';
  @override
  String get navSpeech =>
      'گفتار';
  @override
  String get navImages =>
      'تصویر';
  @override
  String get navPrompts =>
      'پرامپت';
  @override
  String get downloadComplete =>
      'دانلود کامل شد';
  @override
  String get speechTitle =>
      'گفتار';
  @override
  String get speechSubtitle =>
      'تبدیل گفتار به متن به‌صورت محلی با whisper.cpp';
  @override
  String get speechEngine =>
      'موتور';
  @override
  String get speechLocal =>
      'همین دستگاه';
  @override
  String get speechRemote =>
      'سرور دیگر';
  @override
  String speechRunning(String model) =>
      'در حال اجرا — مدل $model بارگذاری شده';
  @override
  String get speechStopped =>
      'متوقف. با شروع موتور یا اولین دیکته، مدل بارگذاری می‌شود.';
  @override
  String get speechStarting =>
      'در حال بارگذاری مدل…';
  @override
  String get speechStart =>
      'بارگذاری مدل';
  @override
  String get speechStop =>
      'خارج‌کردن از حافظه';
  @override
  String get speechBinaryNotFound =>
      'موتور whisper.cpp (فایل whisper-server) روی این سیستم پیدا نشد.';
  @override
  String get speechBinaryHelp =>
      'بسته‌های انتشار، موتور را همراه دارند. برای نصب دستی، whisper.cpp را بیلد کنید و فایل build/bin/whisper-server را انتخاب کنید:';
  @override
  String get speechChooseBinary =>
      'انتخاب موتور…';
  @override
  String get speechRemoteUrl =>
      'آدرس سرور whisper.cpp';
  @override
  String get speechRemoteHelp =>
      'هر دستگاهی در شبکه که whisper-server روی آن اجراست. برای اندروید مناسب است.';
  @override
  String get speechTest =>
      'تست';
  @override
  String get speechRemoteOk =>
      'سرور در دسترس است.';
  @override
  String get speechRemoteFail =>
      'اتصال به سرور ممکن نشد.';
  @override
  String get speechModels =>
      'مدل‌های روی این دستگاه';
  @override
  String get speechNoModels =>
      'هنوز مدلی ندارید — از پایین دانلود کنید یا یک فایل ggml ‎.bin اضافه کنید.';
  @override
  String get speechAddModelFile =>
      'افزودن فایل مدل';
  @override
  String get speechCatalog =>
      'دانلود مدل';
  @override
  String get speechCatalogHelp =>
      'از Hugging Face (ggerganov/whisper.cpp) با همان تنظیمات اتصالِ بخش مدل‌ها ← نصب GGUF دانلود می‌شود. مدل بزرگ‌تر دقیق‌تر و کندتر است؛ نسخه‌های q5 کوچک‌تر و با کیفیت نزدیک‌اند.';
  @override
  String get speechOptions =>
      'تنظیمات';
  @override
  String get speechLanguage =>
      'زبان گفتار';
  @override
  String get speechLanguageHelp =>
      'انتخاب دقیق زبان از تشخیص خودکار مطمئن‌تر است.';
  @override
  String get speechAuto =>
      'تشخیص خودکار';
  @override
  String get speechTranslate =>
      'ترجمه به انگلیسی';
  @override
  String get speechTranslateHelp =>
      'هر زبانی گفته شود، متن انگلیسی برمی‌گرداند.';
  @override
  String get speechDictation =>
      'دیکته در چت';
  @override
  String get speechDictationHelp =>
      'میکروفونِ باکس پیام، گفته‌ی شما را تایپ می‌کند.';
  @override
  String get speechThreads =>
      'تعداد thread پردازنده';
  @override
  String get speechRecord =>
      'ضبط و تبدیل به متن';
  @override
  String get speechStopRecording =>
      'در حال ضبط — برای پایان بزنید';
  @override
  String get speechPickAudio =>
      'فایل صوتی';
  @override
  String get speechTranscribing =>
      'در حال تبدیل به متن…';
  @override
  String get speechTryHint =>
      'کاملاً روی دستگاه خودتان اجرا می‌شود.';
  @override
  String get speechNeedSetup =>
      'ابتدا در بخش گفتار یک مدل whisper آماده کنید (یا مدل چتِ دارای ورودی صوت انتخاب کنید).';
  @override
  String get speechNothingHeard =>
      'گفتاری تشخیص داده نشد.';
  @override
  String get speechTtsNote =>
      'whisper.cpp فقط گفتار به متن است. تبدیل متن به گفتار موتور جداگانه‌ای می‌خواهد و در این نسخه نیست.';
}
