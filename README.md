<div align="center">

<img src="assets/images/app_logo.jpg" alt="MindGrid" width="120" style="border-radius: 24px;" />

# MindGrid

**دستیار هوش مصنوعی محلی و ابری — برای موبایل و دسکتاپ**

[![Flutter](https://img.shields.io/badge/Flutter-3.11+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Linux%20%7C%20Windows-333333)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)]()

[فارسی](#-معرفی) · [English](#-overview)

</div>

---

## ✨ معرفی

**MindGrid** یک اپ native ساخته‌شده با Flutter است که Ollama و APIهای سازگار با OpenAI را در یک رابط چت یکپارچه جمع می‌کند. مدل‌های محلی روی LAN، کلیدهای ابری، prompt engineering، vision، صدا و تولید تصویر — همه در یک جا، با ذخیره‌سازی کاملاً محلی.

> بدون وابستگی به سرور میانی. داده‌های چت روی دستگاه شما می‌ماند.

---

## 📱 پلتفرم‌ها

| پلتفرم | وضعیت |
|--------|--------|
| 🤖 Android | ✅ |
| 🐧 Linux | ✅ |
| 🪟 Windows | ✅ |
| 🍎 macOS / iOS | 🔜 |

---

## 🚀 قابلیت‌ها

### 💬 چت هوشمند
- استریم real-time پاسخ‌ها با امکان توقف و retry
- Markdown، syntax highlight، بلوک کد با دکمه کپی
- Thinking mode برای مدل‌های پشتیبانی‌شده (DeepSeek-R1 و …)
- ویرایش، کپی و اشتراک‌گذاری پیام‌ها
- Shift+Enter برای خط جدید · Enter برای ارسال

### 🔌 اتصال به مدل‌ها
- **Ollama** — localhost، failover خودکار، کشف LAN روی پورت `11434`
- **OpenAI** · **OpenRouter** · **Custom API** — با پروفایل چندگانه API Key
- تنظیمات پیشرفته: دما، max tokens، context window، timeout، هدر JSON سفارشی
- حالت streaming و non-streaming

### 👁️ چندوجهی
- پیوست تصویر برای مدل‌های vision (LLaVA، Qwen-VL، GPT-4o و …)
- ضبط و ارسال صدا برای مدل‌های audio-capable
- Drag & drop فایل روی دسکتاپ (Linux / Windows / macOS)
- پیوست فایل متنی

### 🎨 تولید تصویر
- پنل اختصاصی image generation
- پشتیبانی از مدل‌های Ollama (Flux، Stable Diffusion و …) و APIهای ابری (DALL·E، GPT-Image)

### 🧠 Prompt Engineering
- system prompt قابل تنظیم با preset و متغیر
- پیش‌نمایش payload با syntax highlight JSON
- override دستی payload قبل از ارسال

### 👤 پروفایل کاربر
- ذخیره اطلاعات کاربر و تزریق خودکار به system prompt
- Auto-extract هوشمند از مکالمات با مدل جداگانه (اختیاری)

### 🏠 مدیریت Ollama
- نصب خودکار روی Linux
- pull / delete مدل‌ها با progress bar
- راهنمای سخت‌افزار (RAM، VRAM، کوانتیزاسیون)
- کشف و اتصال به Ollama روی شبکه محلی

### 💾 داده و بکاپ
- SQLite محلی — چت‌ها و تنظیمات روی دستگاه
- Export / Import مکالمات به JSON (ادغام یا جایگزینی)
- UI ریسپانسیو با breakpoint ~640px

### 🌐 بومی‌سازی
- رابط **فارسی** و **انگلیسی** با فونت Vazirmatn
- RTL/LTR خودکار
- تم تیره مدرن

---

## 🖼️ پیش‌نمایش

<!-- TODO: اسکرین‌شات‌های واقعی را اینجا اضافه کنید -->
<!-- ![Chat](docs/screenshots/chat.png) -->
<!-- ![Settings](docs/screenshots/settings.png) -->

> اسکرین‌شات‌ها به‌زودی اضافه می‌شوند.

---

## ⚡ شروع سریع

### پیش‌نیازها

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ **3.11**
- برای Android: JDK + Android SDK
- برای Windows: Visual Studio با workload دسکتاپ
- (اختیاری) [Ollama](https://ollama.com) برای مدل‌های محلی

### نصب و اجرا

```bash
git clone https://github.com/YOUR_USERNAME/mindgrid.git
cd mindgrid
flutter pub get
flutter run                  # دستگاه متصل
flutter run -d linux         # لینوکس
flutter run -d windows         # ویندوز
flutter run -d android         # اندروید
```

### بیلد Release

```bash
flutter build apk --release       # APK اندروید
flutter build linux --release     # باینری لینوکس
flutter build windows --release   # exe ویندوز
```

---

## 🦙 راه‌اندازی Ollama

### روی همین دستگاه

```bash
ollama serve
# پیش‌فرض: http://127.0.0.1:11434
```

MindGrid به‌صورت خودکار `127.0.0.1`، `localhost` و `::1` را امتحان می‌کند.

### دسترسی از شبکه (LAN)

روی ماشینی که Ollama اجرا می‌شود:

```bash
export OLLAMA_HOST=0.0.0.0
ollama serve
```

در اپ: **Settings → جستجوی Ollama در شبکه** — subnetهای IPv4 محلی روی پورت `11434` اسکن می‌شوند.

### API ابری

**Settings → API / Provider** — provider، Base URL و API Key را تنظیم کنید.

---

## 🏗️ معماری

```
lib/
├── main.dart · app.dart           # نقطه ورود
├── core/                          # uid، RTL/LTR، file picker
├── data/database.dart             # SQLite (sqflite + ffi)
├── models/                        # settings، chat، prompt، ollama
├── services/
│   ├── llm_client.dart            # مدل‌ها + استریم چت
│   ├── ollama_runtime.dart        # failover، think، payload
│   ├── network_discovery.dart     # اسکن LAN
│   ├── ollama_manager_service.dart
│   ├── image_generation_service.dart
│   ├── audio_recorder_service.dart
│   ├── prompt_builder.dart
│   ├── extract_service.dart
│   └── chat_export_service.dart
├── state/app_state.dart           # state مرکزی (Provider)
├── l10n/                          # فارسی · انگلیسی
├── theme/app_theme.dart
├── screens/home_screen.dart
└── widgets/                       # sidebar، chat، settings، …
```

---

## 📦 وابستگی‌های کلیدی

| پکیج | نقش |
|------|-----|
| `provider` | مدیریت state |
| `http` | Ollama / OpenAI API |
| `sqflite` + `sqflite_common_ffi` | DB محلی (موبایل + دسکتاپ) |
| `flutter_markdown` | رندر پاسخ‌ها |
| `google_fonts` | فونت Vazirmatn |
| `file_picker` · `desktop_drop` | پیوست فایل |
| `record` | ضبط صدا |
| `shared_preferences` | تنظیمات prompt |

---

## 🧪 تست

```bash
flutter analyze
flutter test
```

تست‌های e2e با mock در `test/app_state_test.dart` — جریان ارسال، استریم، توقف، retry و persist.

---

## 🗺️ نقشه راه

- [ ] کشف mDNS (`_ollama._tcp`)
- [ ] پشتیبانی macOS / iOS
- [ ] signing release اندروید
- [ ] همگام‌سازی بین دستگاه‌ها

---

## 🤝 مشارکت

Pull Request و Issue خوش‌آمد است. قبل از PR:

```bash
flutter analyze   # بدون error
flutter test      # همه تست‌ها سبز
```

---

## 📄 License

MIT — جزئیات در فایل [LICENSE](LICENSE).

---

<br>

## 🌍 Overview

**MindGrid** is a cross-platform Flutter app for chatting with **Ollama** and **OpenAI-compatible APIs**. Run local LLMs, discover Ollama on your LAN, attach images and audio, generate images, engineer prompts, and keep everything stored locally on your device.

**Platforms:** Android · Linux · Windows

```bash
flutter pub get && flutter run
```

---

<div align="center">

**ساخته‌شده با Flutter**

</div>
