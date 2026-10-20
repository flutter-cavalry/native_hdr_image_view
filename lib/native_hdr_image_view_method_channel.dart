import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_hdr_image_view_platform_interface.dart';

/// An implementation of [NativeHdrImageViewPlatform] that uses method channels.
class MethodChannelNativeHdrImageView extends NativeHdrImageViewPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('native_hdr_image_view');

  @override
  Future<bool> hasHdrSupport() async {
    final supported = await methodChannel.invokeMethod<bool>('hasHdrSupport');
    return supported ?? false;
  }
}
