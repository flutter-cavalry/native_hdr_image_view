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
    this.errorBuilder,
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
    ImageErrorWidgetBuilder? errorBuilder,
  }) : this(
         key: key,
         imagePath: file.path,
         width: width,
         height: height,
         fit: fit,
         errorBuilder: errorBuilder,
       );

  const NativeHdrImageView.bytes(
    Uint8List bytes, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.errorBuilder,
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
    this.errorBuilder,
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
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Whether the current OS provides native HDR image rendering support.
  ///
  /// This does not guarantee that the current display or image supports HDR.
  static Future<bool> hasHdrSupport() {
    if (kIsWeb ||
        !<TargetPlatform>{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      return Future<bool>.value(false);
    }
    return NativeHdrImageViewPlatform.instance.hasHdrSupport();
  }

  @override
  State<NativeHdrImageView> createState() => _NativeHdrImageViewState();
}

class _NativeHdrImageViewState extends State<NativeHdrImageView> {
  MethodChannel? _channel;
  Object? _error;
  StackTrace? _errorStack;
  int _request = 0;

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
      _error = null;
      _errorStack = null;
      _updateView();
    }
  }

  Future<void> _updateView() async {
    final channel = _channel;
    if (channel == null) return;
    final request = ++_request;
    try {
      await channel.invokeMethod<void>('update', _parameters);
    } on PlatformException catch (error, stack) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _errorStack = stack;
      });
      if (widget.errorBuilder == null) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'native_hdr_image_view',
          ),
        );
      }
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
      case TargetPlatform.android:
        view = AndroidView(
          viewType: 'native_hdr_image_view',
          creationParams: _parameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
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
          'NativeHdrImageView is only supported on Android, iOS, and macOS.',
        );
    }
    final errorBuilder = widget.errorBuilder;
    final showError = _error != null && errorBuilder != null;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: IndexedStack(
        index: showError ? 1 : 0,
        sizing: StackFit.passthrough,
        children: [
          view,
          if (showError) errorBuilder(context, _error!, _errorStack),
        ],
      ),
    );
  }
}
