import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';
import 'package:native_hdr_image_view_example/main.dart';

class FakeFileSelector extends FileSelectorPlatform {
  XFile? file;
  Object? error;
  List<XTypeGroup>? acceptedTypes;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    acceptedTypes = acceptedTypeGroups;
    if (error != null) throw error!;
    return file;
  }
}

void main() {
  late FakeFileSelector picker;
  late FileSelectorPlatform originalPicker;

  setUp(() {
    originalPicker = FileSelectorPlatform.instance;
    picker = FakeFileSelector();
    FileSelectorPlatform.instance = picker;
  });

  tearDown(() {
    FileSelectorPlatform.instance = originalPicker;
  });

  final platforms = TargetPlatformVariant(<TargetPlatform>{
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  });

  testWidgets('empty state and controls fit a narrow screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MyApp());

    expect(find.text('No image selected'), findsOneWidget);
    expect(find.text('Open image'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<BoxFit>), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  }, variant: platforms);

  testWidgets('select an image, change every fit, and clear it', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final viewIds = <int>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['id'] as int;
        viewIds.add(id);
        messenger.setMockMethodCallHandler(
          MethodChannel('native_hdr_image_view/$id'),
          (call) async => null,
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

    picker.file = XFile('/tmp/hdr.heic');
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Open image'));
    await tester.pumpAndSettle();

    expect(
      picker.acceptedTypes!.single.uniformTypeIdentifiers,
      contains('public.image'),
    );
    expect(find.text('hdr.heic'), findsOneWidget);
    expect(
      tester
          .widget<NativeHdrImageView>(find.byType(NativeHdrImageView))
          .imagePath,
      '/tmp/hdr.heic',
    );

    for (final fit in BoxFit.values) {
      await tester.tap(find.byType(DropdownButtonFormField<BoxFit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(fit.name).last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<NativeHdrImageView>(find.byType(NativeHdrImageView)).fit,
        fit,
      );
    }

    picker.file = null;
    await tester.tap(find.text('Open image'));
    await tester.pumpAndSettle();
    expect(find.text('hdr.heic'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear image'));
    await tester.pumpAndSettle();
    expect(find.byType(NativeHdrImageView), findsNothing);
    expect(find.text('No image selected'), findsOneWidget);
    expect(viewIds, hasLength(1));
    expect(tester.takeException(), isNull);
  }, variant: platforms);

  testWidgets('cancelling the picker leaves the empty state', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Open image'));
    await tester.pumpAndSettle();

    expect(find.text('No image selected'), findsOneWidget);
    expect(find.byType(NativeHdrImageView), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  }, variant: platforms);

  testWidgets('picker failures are displayed and allow retrying', (
    tester,
  ) async {
    picker.error = PlatformException(code: 'picker_failed');
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Open image'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open image:'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    picker.error = null;
    await tester.tap(find.text('Open image'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open image:'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: platforms);
}
