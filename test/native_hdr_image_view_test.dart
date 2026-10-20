import 'dart:io';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
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
  Future<bool> hasHdrSupport() => Future<bool>.value(true);
}

void main() {
  final NativeHdrImageViewPlatform initialPlatform =
      NativeHdrImageViewPlatform.instance;

  test('$MethodChannelNativeHdrImageView is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeHdrImageView>());
  });

  test('hasHdrSupport', () async {
    MockNativeHdrImageViewPlatform fakePlatform =
        MockNativeHdrImageViewPlatform();
    NativeHdrImageViewPlatform.instance = fakePlatform;

    expect(await NativeHdrImageView.hasHdrSupport(), true);
  });

  test('hasHdrSupport is false on unsupported platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(await NativeHdrImageView.hasHdrSupport(), false);
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
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

      Future<void> showView(NativeHdrImageView view) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: view),
          ),
        );
        await tester.pump();
      }

      Future<void> show(String? path, BoxFit fit) => showView(
        NativeHdrImageView(imagePath: path, fit: fit, width: 200, height: 100),
      );

      await show('/tmp/hdr.heic', BoxFit.contain);
      expect(creationParameters, <String, Object?>{
        'imagePath': '/tmp/hdr.heic',
        'fit': 'contain',
      });
      expect(
        find.byType(switch (platform) {
          TargetPlatform.android => AndroidView,
          TargetPlatform.iOS => UiKitView,
          _ => AppKitView,
        }),
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

      await showView(
        NativeHdrImageView.file(
          File('/tmp/local.heic'),
          width: 200,
          height: 150,
          fit: BoxFit.cover,
        ),
      );
      expect(updates.last.arguments, <String, Object?>{
        'imagePath': '/tmp/local.heic',
        'fit': 'cover',
      });
      final viewFinder = find.byType(switch (platform) {
        TargetPlatform.android => AndroidView,
        TargetPlatform.iOS => UiKitView,
        _ => AppKitView,
      });
      expect(tester.getSize(viewFinder), const Size(200, 150));

      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      await showView(NativeHdrImageView.bytes(bytes, width: 160, height: 90));
      expect(updates.last.arguments, <String, Object?>{
        'imagePath': null,
        'imageBytes': bytes,
        'fit': 'contain',
      });
      expect(tester.getSize(viewFinder), const Size(160, 90));

      await showView(
        const NativeHdrImageView.network(
          'https://example.com/hdr.heic',
          width: 200,
          height: 150,
          fit: BoxFit.cover,
        ),
      );
      expect(updates.last.arguments, <String, Object?>{
        'imagePath': null,
        'imageUrl': 'https://example.com/hdr.heic',
        'fit': 'cover',
      });
      final updateCount = updates.length;
      await showView(
        const NativeHdrImageView.network(
          'https://example.com/hdr.heic',
          width: 300,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
      expect(updates, hasLength(updateCount));
      expect(tester.getSize(viewFinder), const Size(300, 180));

      await show(null, BoxFit.contain);
      expect((updates.last.arguments as Map)['imagePath'], isNull);
      expect(viewIds, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, variant: TargetPlatformVariant(<TargetPlatform>{platform}));
  }
}
