import 'dart:math';
import 'dart:typed_data';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_theme.dart';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${List.generate(4, (_) => Random.secure().nextInt(1 << 30).toRadixString(36)).join()}';

class MediaSelection {
  MediaSelection([List<String> paths = const []]) : paths = [...paths];
  final List<String> paths;
  final List<({Uint8List bytes, String mime})> pending = [];
  Future<List<String>> upload(String prefix) async {
    while (pending.isNotEmpty) {
      final f = pending.first,
          path = '$prefix/${newId()}.${f.mime == 'image/png' ? 'png' : 'jpg'}';
      await FirebaseStorage.instance
          .ref(path)
          .putData(f.bytes, SettableMetadata(contentType: f.mime));
      paths.add(path);
      pending.removeAt(0);
    }
    return [...paths];
  }
}

class MediaPicker extends StatefulWidget {
  const MediaPicker({
    super.key,
    required this.selection,
    this.limit = 5,
    this.enabled = true,
    this.onChanged,
  });
  final MediaSelection selection;
  final int limit;
  final bool enabled;
  final VoidCallback? onChanged;
  @override
  State<MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<MediaPicker> {
  bool _busy = false;
  String? _error;
  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      final png =
              bytes.length >= 8 &&
              bytes[0] == 137 &&
              bytes[1] == 80 &&
              bytes[2] == 78 &&
              bytes[3] == 71,
          jpeg =
              bytes.length >= 3 &&
              bytes[0] == 255 &&
              bytes[1] == 216 &&
              bytes[2] == 255;
      if ((!png && !jpeg) || bytes.length >= 5 * 1024 * 1024) {
        throw ArgumentError('5MB-аас бага JPG/PNG зураг сонгоно уу.');
      }
      if (mounted) {
        setState(
          () => widget.selection.pending.add((
            bytes: bytes,
            mime: png ? 'image/png' : 'image/jpeg',
          )),
        );
        widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ArgumentError
              ? e.message.toString()
              : 'Зургийн сан/камерын зөвшөөрлөө шалгана уу.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.selection, count = s.paths.length + s.pending.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < s.paths.length; i++)
              SizedBox(
                width: 90,
                height: 105,
                child: Stack(
                  children: [
                    Positioned.fill(child: StorageImage(path: s.paths[i])),
                    if (widget.enabled)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filled(
                          tooltip: 'Зураг хасах',
                          onPressed: () {
                            setState(() => s.paths.removeAt(i));
                            widget.onChanged?.call();
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            for (int i = 0; i < s.pending.length; i++)
              SizedBox(
                width: 90,
                height: 105,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(
                        s.pending[i].bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                      ),
                    ),
                    if (widget.enabled)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filled(
                          tooltip: 'Зураг хасах',
                          onPressed: () {
                            setState(() => s.pending.removeAt(i));
                            widget.onChanged?.call();
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy && count < widget.limit
                  ? () => _pick(ImageSource.gallery)
                  : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text('Зураг ($count/${widget.limit})'),
            ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_busy && count < widget.limit
                  ? () => _pick(ImageSource.camera)
                  : null,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Камер'),
            ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

class StorageImage extends StatefulWidget {
  const StorageImage({
    super.key,
    required this.path,
    this.height = 200,
    this.fit = BoxFit.cover,
  });
  final String path;
  final double height;
  final BoxFit fit;
  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<Uint8List?> _data;
  void _load() {
    _data = FirebaseStorage.instance.ref(widget.path).getData(5 * 1024 * 1024);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _load();
    }
  }

  Widget _broken() => const ColoredBox(
    color: AppColors.mint,
    child: Center(child: Icon(Icons.broken_image_outlined)),
  );
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: widget.height,
      child: FutureBuilder<Uint8List?>(
        future: _data,
        builder: (context, s) {
          if (s.hasError) {
            return _broken();
          }
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.memory(
            s.data!,
            width: double.infinity,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: 900,
            errorBuilder: (c, e, st) => _broken(),
          );
        },
      ),
    ),
  );
}
