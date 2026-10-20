import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';
import 'package:native_hdr_image_view/native_hdr_image_view_method_channel.dart';
import 'package:native_hdr_image_view/native_hdr_image_view_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeHdrImageViewPlatform
    with MockPlatformInterfaceMixin
    implements NativeHdrImageViewPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final NativeHdrImageViewPlatform initialPlatform =
      NativeHdrImageViewPlatform.instance;

  test('$MethodChannelNativeHdrImageView is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeHdrImageView>());
  });

  test('getPlatformVersion', () async {
    NativeHdrImageView nativeHdrImageViewPlugin = NativeHdrImageView();
    MockNativeHdrImageViewPlatform fakePlatform =
        MockNativeHdrImageViewPlatform();
    NativeHdrImageViewPlatform.instance = fakePlatform;

    expect(await nativeHdrImageViewPlugin.getPlatformVersion(), '42');
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets('$platform creates and updates a file image view', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final updates = <MethodCall>[];
      final viewIds = <int>[];
      Map<Object?, Object?>? creationParameters;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map<Object?, Object?>;
          final id = arguments['id']! as int;
          viewIds.add(id);
          expect(arguments['viewType'], 'native_hdr_image_view');
          creationParameters = const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(arguments['params']! as Uint8List),
          ) as Map<Object?, Object?>;
          messenger.setMockMethodCallHandler(
            MethodChannel('native_hdr_image_view/$id'),
            (call) async => updates.add(call),
          );
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final id in viewIds) {
          messenger.setMockMethodCallHandler(
            MethodChannel('native_hdr_image_view/$id'),
            null,
          );
        }
      });

      Future<void> show(String? path, BoxFit fit) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox(
              width: 200,
              height: 100,
              child: NativeHdrImageView(imagePath: path, fit: fit),
            ),
          ),
        );
        await tester.pump();
      }

      await show('/tmp/hdr.heic', BoxFit.contain);
      expect(creationParameters, <String, Object?>{
        'imagePath': '/tmp/hdr.heic',
        'fit': 'contain',
      });
      expect(
        find.byType(platform == TargetPlatform.iOS ? UiKitView : AppKitView),
        findsOneWidget,
      );
      for (final fit in BoxFit.values) {
        await show('/tmp/other.heic', fit);
        expect(updates.last.method, 'update');
        expect(updates.last.arguments, <String, Object?>{
          'imagePath': '/tmp/other.heic',
          'fit': fit.name,
        });
      }
      await show(null, BoxFit.contain);
      expect((updates.last.arguments as Map)['imagePath'], isNull);
      expect(viewIds, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, variant: TargetPlatformVariant(<TargetPlatform>{platform}));
  }
}
