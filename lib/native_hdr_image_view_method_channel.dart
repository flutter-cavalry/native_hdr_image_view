import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_hdr_image_view_platform_interface.dart';

/// An implementation of [NativeHdrImageViewPlatform] that uses method channels.
class MethodChannelNativeHdrImageView extends NativeHdrImageViewPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_hdr_image_view');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
