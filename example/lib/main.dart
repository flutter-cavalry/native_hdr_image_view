import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _imagePath;
  String? _imageName;
  String? _error;
  BoxFit _fit = BoxFit.contain;
  bool _isPicking = false;

  Future<void> _selectImage() async {
    setState(() {
      _isPicking = true;
      _error = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[
          XTypeGroup(
            label: 'Images',
            uniformTypeIdentifiers: <String>['public.image'],
            extensions: <String>[
              'heic',
              'heif',
              'avif',
              'jpg',
              'jpeg',
              'png',
              'tif',
              'tiff',
              'gif',
              'webp',
              'bmp',
            ],
          ),
        ],
      );
      if (!mounted || file == null) return;
      setState(() {
        _imagePath = file.path;
        _imageName = file.name;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open image: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native HDR Image View',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF226D5C)),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Native HDR Image View')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _isPicking ? null : _selectImage,
                      icon: _isPicking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open),
                      label: const Text('Open image'),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<BoxFit>(
                        initialValue: _fit,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'BoxFit',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: <DropdownMenuItem<BoxFit>>[
                          for (final fit in BoxFit.values)
                            DropdownMenuItem(value: fit, child: Text(fit.name)),
                        ],
                        onChanged: (fit) {
                          if (fit != null) setState(() => _fit = fit);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear image',
                      onPressed: _imagePath == null
                          ? null
                          : () => setState(() {
                              _imagePath = null;
                              _imageName = null;
                              _error = null;
                            }),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_imageName != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Tooltip(
                    message: _imagePath!,
                    child: Text(
                      _imageName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(_error!),
                ),
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFE7E9EC),
                  child: SizedBox.expand(
                    child: _imagePath == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.image_outlined, size: 48),
                                SizedBox(height: 12),
                                Text('No image selected'),
                              ],
                            ),
                          )
                        : NativeHdrImageView(imagePath: _imagePath, fit: _fit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
