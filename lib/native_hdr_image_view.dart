import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_hdr_image_view_platform_interface.dart';

class NativeHdrImageView extends StatefulWidget {
  const NativeHdrImageView({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  }) : imageBytes = null,
       imageUrl = null,
       assert(width == null || width >= 0),
       assert(height == null || height >= 0);

  NativeHdrImageView.file(
    File file, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) : this(
         key: key,
         imagePath: file.path,
         width: width,
         height: height,
         fit: fit,
       );

  const NativeHdrImageView.bytes(
    Uint8List bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  }) : imageBytes = bytes,
       imagePath = null,
       imageUrl = null,
       assert(width == null || width >= 0),
       assert(height == null || height >= 0);

  const NativeHdrImageView.network(
    String url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  }) : imageUrl = url,
       imagePath = null,
       imageBytes = null,
       assert(width == null || width >= 0),
       assert(height == null || height >= 0);

  final String? imagePath;
  final Uint8List? imageBytes;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  Future<String?> getPlatformVersion() {
    return NativeHdrImageViewPlatform.instance.getPlatformVersion();
  }

  @override
  State<NativeHdrImageView> createState() => _NativeHdrImageViewState();
}

class _NativeHdrImageViewState extends State<NativeHdrImageView> {
  MethodChannel? _channel;

  Map<String, Object?> get _parameters => <String, Object?>{
    'imagePath': widget.imagePath,
    if (widget.imageBytes != null) 'imageBytes': widget.imageBytes,
    if (widget.imageUrl != null) 'imageUrl': widget.imageUrl,
    'fit': widget.fit.name,
  };

  @override
  void didUpdateWidget(covariant NativeHdrImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.fit != widget.fit) {
      _updateView();
    }
  }

  Future<void> _updateView() async {
    try {
      await _channel?.invokeMethod<void>('update', _parameters);
    } on PlatformException catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'native_hdr_image_view',
        ),
      );
    }
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('native_hdr_image_view/$id');
    _updateView();
  }

  @override
  Widget build(BuildContext context) {
    final Widget view;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        view = UiKitView(
          viewType: 'native_hdr_image_view',
          creationParams: _parameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
      case TargetPlatform.macOS:
        view = AppKitView(
          viewType: 'native_hdr_image_view',
          creationParams: _parameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
      default:
        throw UnsupportedError(
          'NativeHdrImageView requires iOS 17+ or macOS 14+.',
        );
    }
    return SizedBox(width: widget.width, height: widget.height, child: view);
  }
}
