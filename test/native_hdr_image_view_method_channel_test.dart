import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_hdr_image_view/native_hdr_image_view_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNativeHdrImageView platform = MethodChannelNativeHdrImageView();
  const MethodChannel channel = MethodChannel('native_hdr_image_view');

  bool? nativeSupport = true;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'hasHdrSupport') return nativeSupport;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hasHdrSupport', () async {
    expect(await platform.hasHdrSupport(), true);
  });

  test('hasHdrSupport returns false when native HDR is unsupported', () async {
    nativeSupport = false;

    expect(await platform.hasHdrSupport(), false);
  });

  test('hasHdrSupport defaults to false when native result is absent', () async {
    nativeSupport = null;

    expect(await platform.hasHdrSupport(), false);
  });
}
