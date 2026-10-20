import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_hdr_image_view_platform_interface.dart';

class NativeHdrImageView extends StatefulWidget {
  const NativeHdrImageView({
    super.key,
    this.imagePath,
    this.fit = BoxFit.contain,
  });

  final String? imagePath;
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
    'fit': widget.fit.name,
  };

  @override
  void didUpdateWidget(covariant NativeHdrImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
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
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: 'native_hdr_image_view',
          creationParams: _parameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      case TargetPlatform.macOS:
        return AppKitView(
          viewType: 'native_hdr_image_view',
          creationParams: _parameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      default:
        throw UnsupportedError(
          'NativeHdrImageView requires iOS 17+ or macOS 14+.',
        );
    }
  }
}
