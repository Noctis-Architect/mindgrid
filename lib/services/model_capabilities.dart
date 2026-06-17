/// Heuristic detection of vision and image-generation models by name.
class ModelCapabilities {
  ModelCapabilities._();

  static final _visionPatterns = [
    RegExp(r'llava', caseSensitive: false),
    RegExp(r'bakllava', caseSensitive: false),
    RegExp(r'moondream', caseSensitive: false),
    RegExp(r'minicpm[-_]?v', caseSensitive: false),
    RegExp(r'qwen[-_.]?vl', caseSensitive: false),
    RegExp(r'qwen2[-_.]?vl', caseSensitive: false),
    RegExp(r'cogvlm', caseSensitive: false),
    RegExp(r'internvl', caseSensitive: false),
    RegExp(r'pixtral', caseSensitive: false),
    RegExp(r'llama[-_.]?3\.2[-_.]?vision', caseSensitive: false),
    RegExp(r'gemma[-_.]?3', caseSensitive: false),
    RegExp(r'gemma[-_.]?4', caseSensitive: false),
    RegExp(r'gemma[-_.]?3.*vision', caseSensitive: false),
    RegExp(r'gpt[-_.]?4o', caseSensitive: false),
    RegExp(r'gpt[-_.]?4[-_.]?vision', caseSensitive: false),
    RegExp(r'claude[-_.]?3', caseSensitive: false),
    RegExp(r'gemini.*vision', caseSensitive: false),
    RegExp(r'vision', caseSensitive: false),
    RegExp(r'vl[-_:]', caseSensitive: false),
    RegExp(r'[-_:]vl(?:[-_:]|$)', caseSensitive: false),
  ];

  static final _imageGenPatterns = [
    RegExp(r'flux', caseSensitive: false),
    RegExp(r'stable[-_.]?diffusion', caseSensitive: false),
    RegExp(r'\bsdxl\b', caseSensitive: false),
    RegExp(r'dreamshaper', caseSensitive: false),
    RegExp(r'playground', caseSensitive: false),
    RegExp(r'dall[-_.]?e', caseSensitive: false),
    RegExp(r'gpt[-_.]?image', caseSensitive: false),
    RegExp(r'gpt[-_.]?5[-_.]?image', caseSensitive: false),
    RegExp(r'image[-_.]?gen', caseSensitive: false),
    RegExp(r'img2img', caseSensitive: false),
    RegExp(r'\bxl\b.*diffusion', caseSensitive: false),
    RegExp(r'sdxl', caseSensitive: false),
    RegExp(r'gemini.*image', caseSensitive: false),
    RegExp(r'imagen', caseSensitive: false),
    RegExp(r'riverflow', caseSensitive: false),
    RegExp(r'mai[-_.]?image', caseSensitive: false),
    RegExp(r'sourceful', caseSensitive: false),
    RegExp(r'recraft', caseSensitive: false),
    RegExp(r'seedream', caseSensitive: false),
    RegExp(r'ideogram', caseSensitive: false),
  ];

  static bool isVisionModel(String? name) {
    return supportsVision(name);
  }

  static bool supportsVision(
    String? name, {
    List<String> capabilities = const [],
  }) {
    if (capabilities.contains('vision')) return true;
    if (name == null || name.isEmpty) return false;
    if (isImageGenModel(name)) return false;
    return _visionPatterns.any((p) => p.hasMatch(name));
  }

  static bool supportsAudio(
    String? name, {
    List<String> capabilities = const [],
  }) {
    if (capabilities.contains('audio')) return true;
    return isAudioModel(name);
  }

  static bool isImageGenModel(String? name) {
    if (name == null || name.isEmpty) return false;
    return _imageGenPatterns.any((p) => p.hasMatch(name));
  }

  static bool supportsImageGeneration(
    String? name, {
    List<String> capabilities = const [],
    List<String> outputModalities = const [],
  }) {
    if (outputModalities.contains('image')) return true;
    if (capabilities.contains('image')) return true;
    return isImageGenModel(name);
  }

  static final _audioPatterns = [
    RegExp(r'gemma[-_.]?4', caseSensitive: false),
    RegExp(r'gemma[-_.]?3n', caseSensitive: false),
    RegExp(r'qwen[-_.]?2[-_.]?audio', caseSensitive: false),
    RegExp(r'qwen[-_.]?audio', caseSensitive: false),
    RegExp(r'whisper', caseSensitive: false),
    RegExp(r'audio', caseSensitive: false),
  ];

  static bool isAudioModel(String? name) {
    if (name == null || name.isEmpty) return false;
    return _audioPatterns.any((p) => p.hasMatch(name));
  }

  static const audioExtensions = {'wav', 'mp3', 'm4a', 'ogg', 'flac', 'webm'};

  static String? audioMimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'wav' => 'audio/wav',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'ogg' => 'audio/ogg',
      'flac' => 'audio/flac',
      'webm' => 'audio/webm',
      _ => null,
    };
  }

  static const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

  static String? mimeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => null,
    };
  }

  static String? extensionFromName(String name) {
    if (!name.contains('.')) return null;
    return name.split('.').last.toLowerCase();
  }
}
