import 'dart:async';
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
      Future<void> Function()? onUpdate;
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
            (call) async {
              updates.add(call);
              await onUpdate?.call();
              return null;
            },
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

      final failure = PlatformException(
        code: 'invalid_image',
        message: 'Cannot decode image.',
      );
      Object? receivedError;
      StackTrace? receivedStack;
      Widget errorBuilder(
        BuildContext context,
        Object error,
        StackTrace? stack,
      ) {
        receivedError = error;
        receivedStack = stack;
        return const Text('Image failed');
      }

      for (final failedView in <NativeHdrImageView>[
        NativeHdrImageView.file(
          File('/tmp/missing.heic'),
          errorBuilder: errorBuilder,
        ),
        NativeHdrImageView.bytes(bytes, errorBuilder: errorBuilder),
        NativeHdrImageView.network(
          'https://example.com/missing.heic',
          errorBuilder: errorBuilder,
        ),
      ]) {
        onUpdate = () async => throw failure;
        await showView(failedView);
        expect(find.text('Image failed'), findsOneWidget);
        expect((receivedError! as PlatformException).code, failure.code);
        expect(receivedStack, isNotNull);
        expect(tester.takeException(), isNull);

        onUpdate = null;
        await show('/tmp/recovered.heic', BoxFit.contain);
        expect(find.text('Image failed'), findsNothing);
        expect(viewFinder, findsOneWidget);
        expect(viewIds, hasLength(1));
      }

      onUpdate = () async => throw failure;
      await show('/tmp/no-builder.heic', BoxFit.contain);
      expect(tester.takeException(), isA<PlatformException>());

      final pending = Completer<void>();
      onUpdate = () => pending.future;
      await showView(
        NativeHdrImageView(
          imagePath: '/tmp/old.heic',
          errorBuilder: errorBuilder,
        ),
      );
      onUpdate = null;
      await showView(
        NativeHdrImageView(
          imagePath: '/tmp/new.heic',
          errorBuilder: errorBuilder,
        ),
      );
      pending.completeError(failure);
      await tester.pump();
      expect(find.text('Image failed'), findsNothing);
      expect(tester.takeException(), isNull);

      await show(null, BoxFit.contain);
      expect((updates.last.arguments as Map)['imagePath'], isNull);
      expect(viewIds, hasLength(1));
      final disposedRequest = Completer<void>();
      onUpdate = () => disposedRequest.future;
      await show('/tmp/disposed.heic', BoxFit.contain);
      await tester.pumpWidget(const SizedBox.shrink());
      disposedRequest.completeError(failure);
      await tester.pump();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant(<TargetPlatform>{platform}));
  }
}
