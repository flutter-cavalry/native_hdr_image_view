// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hasHdrSupport reports a native capability', (
    WidgetTester tester,
  ) async {
    expect(await NativeHdrImageView.hasHdrSupport(), isA<bool>());
  });

  testWidgets('native sources decode, cancel, and report errors', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF33AA66), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    image.dispose();
    picture.dispose();

    final directory = await Directory.systemTemp.createTemp(
      'native_hdr_sources',
    );
    final file = await File('${directory.path}/image.png').writeAsBytes(bytes);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final delayedRequest = Completer<HttpRequest>();
    server.listen((request) async {
      if (request.uri.path == '/slow') {
        delayedRequest.complete(request);
        return;
      }
      if (request.uri.path == '/missing') {
        request.response.statusCode = HttpStatus.notFound;
      } else if (request.uri.path == '/invalid') {
        request.response.write('not an image');
      } else {
        request.response.headers.contentType = ContentType('image', 'png');
        request.response.add(bytes);
      }
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await directory.delete(recursive: true);
    });

    final id = platformViewsRegistry.getNextPlatformViewId();
    final parameters = <String, Object?>{'imagePath': null, 'fit': 'contain'};
    final controller = Platform.isIOS
        ? await PlatformViewsService.initUiKitView(
            id: id,
            viewType: 'native_hdr_image_view',
            layoutDirection: ui.TextDirection.ltr,
            creationParams: parameters,
            creationParamsCodec: const StandardMessageCodec(),
          )
        : await PlatformViewsService.initAppKitView(
            id: id,
            viewType: 'native_hdr_image_view',
            layoutDirection: ui.TextDirection.ltr,
            creationParams: parameters,
            creationParamsCodec: const StandardMessageCodec(),
          );
    addTearDown(controller.dispose);
    final channel = MethodChannel('native_hdr_image_view/$id');
    final baseUrl = 'http://127.0.0.1:${server.port}';

    await channel.invokeMethod<void>('update', <String, Object?>{
      'imagePath': file.path,
      'fit': 'cover',
    });
    await channel.invokeMethod<void>('update', <String, Object?>{
      'imageBytes': bytes,
      'fit': 'contain',
    });
    await channel.invokeMethod<void>('update', <String, Object?>{
      'imageUrl': '$baseUrl/image.png',
      'fit': 'fitWidth',
    });

    final pending = channel.invokeMethod<void>('update', <String, Object?>{
      'imageUrl': '$baseUrl/slow',
      'fit': 'contain',
    });
    final staleRequest = await delayedRequest.future;
    await channel.invokeMethod<void>('update', <String, Object?>{
      'imageBytes': bytes,
      'fit': 'cover',
    });
    await pending;
    await staleRequest.response.close();

    for (final source in <Map<String, Object?>>[
      <String, Object?>{'imageUrl': 'file:///not-a-network-url'},
      <String, Object?>{'imageUrl': '$baseUrl/missing'},
      <String, Object?>{'imageUrl': '$baseUrl/invalid'},
      <String, Object?>{
        'imageBytes': Uint8List.fromList(<int>[1, 2, 3]),
      },
      <String, Object?>{'imagePath': '${directory.path}/missing.png'},
    ]) {
      final expectedCode = source['imageUrl'] == 'file:///not-a-network-url'
          ? 'invalid_url'
          : source['imageUrl'] == '$baseUrl/missing'
          ? 'network_error'
          : 'invalid_image';
      await expectLater(
        channel.invokeMethod<void>('update', <String, Object?>{
          ...source,
          'fit': 'contain',
        }),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            expectedCode,
          ),
        ),
      );
    }
    await channel.invokeMethod<void>('update', parameters);
  });
}
