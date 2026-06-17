import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/file_picker_utils.dart';
import '../core/platform_file_picker.dart';
import '../core/hover_surface.dart';
import '../l10n/l10n.dart';
import '../models/chat_models.dart';
import '../services/model_capabilities.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ImageGenerationPanel extends StatefulWidget {
  const ImageGenerationPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<ImageGenerationPanel> createState() => _ImageGenerationPanelState();
}

class _ImageGenerationPanelState extends State<ImageGenerationPanel> {
  final _promptController = TextEditingController();
  AttachedImage? _sourceImage;
  String _selectedModel = '';
  Uint8List? _resultBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncModel());
  }

  void _syncModel() {
    final models = context.read<AppState>().imageGenModels;
    if (models.isEmpty) return;
    if (_selectedModel.isEmpty || !models.any((m) => m.name == _selectedModel)) {
      setState(() => _selectedModel = models.first.name);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickSourceImage() async {
    final state = context.read<AppState>();
    final s = state.strings;
    final result = await PlatformFilePicker.pickFiles(
      type: FileType.image,
      withData: kIsWeb || !(Platform.isAndroid || Platform.isIOS),
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    final ext = ModelCapabilities.extensionFromName(f.name);
    final mime = (ext != null
            ? ModelCapabilities.mimeFromExtension(ext)
            : null) ??
        'image/jpeg';
    final bytes = await readPlatformFileBytes(f);
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      state.showToast(s.readImageFailed(f.name), type: ToastType.err);
      return;
    }
    if (bytes.length > 10 * 1024 * 1024) {
      state.showToast(s.imageTooLarge, type: ToastType.err);
      return;
    }
    setState(() {
      _sourceImage = AttachedImage(name: f.name, mimeType: mime, bytes: bytes);
      _resultBytes = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    final state = context.read<AppState>();
    final s = state.strings;
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty && _sourceImage == null) {
      state.showToast(s.enterPromptOrImage, type: ToastType.err);
      return;
    }
    if (_selectedModel.isEmpty) {
      state.showToast(s.noImageModelSelected, type: ToastType.err);
      return;
    }

    setState(() {
      _error = null;
      _resultBytes = null;
    });

    try {
      final result = await state.generateImage(
        model: _selectedModel,
        prompt: prompt,
        sourceImage: _sourceImage,
      );
      if (!mounted) return;
      setState(() => _resultBytes = result.bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      state.showToast(s.error(e.toString()), type: ToastType.err);
    }
  }

  Future<void> _saveResult() async {
    if (_resultBytes == null) return;
    final s = context.sRead;
    if (kIsWeb) {
      context.read<AppState>().showToast(s.saveNotSupportedWeb, type: ToastType.info);
      return;
    }
    final path = await PlatformFilePicker.saveFile(
      dialogTitle: s.saveImage,
      fileName: 'mindgrid_${DateTime.now().millisecondsSinceEpoch}.png',
      type: FileType.image,
    );
    if (path == null) return;
    await File(path).writeAsBytes(_resultBytes!);
    if (!mounted) return;
    context.read<AppState>().showToast(context.sRead.imageSaved, type: ToastType.ok);
  }

  void _copyPrompt() {
    if (_resultBytes == null) return;
    context.read<AppState>().showToast(
      context.sRead.useSaveButton,
      type: ToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = context.s;
    final mobile = MediaQuery.sizeOf(context).width < mobileBreakpoint;
    final imageModels = state.imageGenModels;

    return Container(
      constraints: BoxConstraints(
        maxWidth: mobile ? double.infinity : 720,
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PanelHeader(onClose: widget.onClose, title: s.imageGenTitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.imageGenDescription,
                    style: const TextStyle(color: AppColors.text3, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (imageModels.isEmpty)
                    _EmptyModelsHint(onRefresh: () => state.fetchModels(), s: s)
                  else ...[
                    _ModelField(
                      models: imageModels,
                      selected: _selectedModel,
                      label: s.imageModel,
                      onChanged: (v) => setState(() => _selectedModel = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _promptController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        labelText: s.prompt,
                        hintText: s.promptHint,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SourceImageSection(
                      image: _sourceImage,
                      title: s.referenceImage,
                      pickLabel: s.selectReferenceImage,
                      onPick: _pickSourceImage,
                      onRemove: () => setState(() {
                        _sourceImage = null;
                        _resultBytes = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: state.isGeneratingImage ? null : _generate,
                      icon: state.isGeneratingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        state.isGeneratingImage ? s.generating : s.generateImage,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.red, fontSize: 12),
                      ),
                    ],
                    if (_resultBytes != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        s.result,
                        style: const TextStyle(
                          color: AppColors.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _resultBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _saveResult,
                            icon: const Icon(Icons.save_alt_rounded, size: 16),
                            label: Text(s.saveImage),
                          ),
                          TextButton.icon(
                            onPressed: _copyPrompt,
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: Text(s.help),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onClose, required this.title});
  final VoidCallback onClose;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.text1,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

class _EmptyModelsHint extends StatelessWidget {
  const _EmptyModelsHint({required this.onRefresh, required this.s});
  final VoidCallback onRefresh;
  final dynamic s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.image_not_supported_outlined,
              color: AppColors.text4, size: 32),
          const SizedBox(height: 10),
          Text(
            s.imageGenNoModels,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text3, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(s.refreshModels),
          ),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.models,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final List<LlmModel> models;
  final String selected;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(selected),
      initialValue:
          models.any((m) => m.name == selected) ? selected : models.first.name,
      decoration: InputDecoration(labelText: label),
      items: models
          .map(
            (m) => DropdownMenuItem(
              value: m.name,
              child: Text(m.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _SourceImageSection extends StatelessWidget {
  const _SourceImageSection({
    required this.image,
    required this.title,
    required this.pickLabel,
    required this.onPick,
    required this.onRemove,
  });

  final AttachedImage? image;
  final String title;
  final String pickLabel;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCode,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.text2, fontSize: 12),
          ),
          const SizedBox(height: 8),
          if (image != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    Uint8List.fromList(image!.bytes),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    image!.name,
                    style: const TextStyle(color: AppColors.text2, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.text4,
                ),
              ],
            ),
          ] else
            HoverSurface(
              onTap: onPick,
              builder: (context, hovered) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: hovered ? AppColors.bgHover : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hovered ? AppColors.accentDim : AppColors.borderMd,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: hovered ? AppColors.accent : AppColors.text4,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pickLabel,
                      style: TextStyle(
                        color: hovered ? AppColors.text2 : AppColors.text4,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
