import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_hdr_image_view/native_hdr_image_view_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNativeHdrImageView platform = MethodChannelNativeHdrImageView();
  const MethodChannel channel = MethodChannel('native_hdr_image_view');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
