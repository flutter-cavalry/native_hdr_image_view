import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'native_hdr_image_view_method_channel.dart';

abstract class NativeHdrImageViewPlatform extends PlatformInterface {
  /// Constructs a NativeHdrImageViewPlatform.
  NativeHdrImageViewPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeHdrImageViewPlatform _instance = MethodChannelNativeHdrImageView();

  /// The default instance of [NativeHdrImageViewPlatform] to use.
  ///
  /// Defaults to [MethodChannelNativeHdrImageView].
  static NativeHdrImageViewPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [NativeHdrImageViewPlatform] when
  /// they register themselves.
  static set instance(NativeHdrImageViewPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
