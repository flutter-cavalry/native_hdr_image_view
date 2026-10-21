# native_hdr_image_view

Display HDR images from files, encoded bytes, or URLs in native platform image views without
decoding or tone-mapping them in Flutter.

| Platform | Minimum OS   | Native view   | Flutter view  |
| -------- | ------------ | ------------- | ------------- |
| Android  | 7.0 (API 24) | `ImageView`   | `AndroidView` |
| iOS      | 16.0         | `UIImageView` | `UiKitView`   |
| macOS    | 12.0         | `NSImageView` | `AppKitView`  |

The Apple native views set `preferredImageDynamicRange` to `.high`. On Android,
`ImageDecoder` is used on API 28+ and `BitmapFactory` is used on earlier
versions. `NativeHdrImageView.hasHdrSupport()` reports whether the current OS
has native HDR image support: Android 14+, iOS 17+, or macOS 14+. It does not
guarantee that the current display or image can show visible HDR. When native
HDR is unavailable, the platform view still displays the image without HDR
enhancement. The Android view requests HDR window color mode for images
containing a gain map. Windows rendering is not implemented.

## Usage

```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';

NativeHdrImageView.network(
	'https://example.com/image.heic',
	width: 200,
	height: 150,
	fit: BoxFit.cover,
)

NativeHdrImageView.file(
	File('/absolute/path/to/image.heic'),
	width: 200,
	height: 150,
	fit: BoxFit.contain,
)

NativeHdrImageView.bytes(
	encodedImageBytes, // Uint8List containing the original encoded image.
	width: 200,
	height: 150,
	fit: BoxFit.cover,
)
```

`.file` accepts a `dart:io` `File`, `.bytes` accepts a `Uint8List` of encoded
image data (not raw RGBA pixels), and `.network` accepts an HTTP or HTTPS URL.
The native OS decodes the original image, preserving HDR metadata. Do not mutate
byte buffers after passing them to the widget; provide a new buffer to update
an image. The original `NativeHdrImageView(imagePath: ...)` constructor remains
available; a null path displays an empty view.

Check native support before replacing a Flutter image view:

```dart
if (await NativeHdrImageView.hasHdrSupport()) {
  // Display the image with NativeHdrImageView.
}
```

When `hasHdrSupport()` returns false, `NativeHdrImageView` can still be used to
display the image normally; the image will not receive native HDR enhancement.

Changing the source loads the new image and cancels any previous download.
Changing only `fit`, `width`, or `height` does not reload the image. Unreadable
or undecodable images report `invalid_image`, HTTP and transport failures report
`network_error`, and invalid URL schemes report `invalid_url` through Flutter's
error reporting as `PlatformException`s.

All constructors accept Flutter's `ImageErrorWidgetBuilder` as `errorBuilder`:

```dart
NativeHdrImageView.file(
	File('/absolute/path/to/image.heic'),
	errorBuilder: (context, error, stackTrace) => const Text('Cannot load image'),
)
```

When supplied, the builder displays a replacement widget instead of reporting
the failure to `FlutterError.onError`. Changing the source clears the error and
loads the new image. Failures from replaced sources or disposed widgets are ignored.

### Android

Android 7.0 (API 24) is the minimum supported version. HDR output requires a
compatible HDR image, Android 14 or newer for Ultra HDR JPEGs, and an HDR
capable display. The plugin requests HDR window color mode when it detects an
Ultra HDR gain map and restores the previous mode when that image is removed.
Files must be readable by the application.

### Network And File Access

Network images are supported on Android, iOS, and macOS. Android uses native
`HttpURLConnection`; Apple uses `URLSession`. HTTPS is recommended; HTTP is
subject to Apple's App Transport Security policy and may require
application-specific exceptions. Downloads do not use Flutter's `ImageCache`.

The plugin declares the Android `INTERNET` permission for network images.

Sandboxed macOS applications must enable outgoing connections in **both** debug
and release entitlements:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Files must be readable by the application. For files chosen with a native macOS
picker, enable `com.apple.security.files.user-selected.read-only` in both
entitlement files. A path or file constructor does not grant sandbox access.
Flutter asset keys are not filesystem paths: load assets as encoded bytes, or
copy them to a local file first.

All Flutter `BoxFit` values are supported: `fill`, `contain` (default), `cover`,
`fitWidth`, `fitHeight`, `none`, and `scaleDown`. Images are centered and clipped
to the widget's bounds. `width` and `height` size the widget directly, subject to
parent constraints, so an outer `SizedBox` is not required. When either dimension
is omitted, the parent must constrain that axis; native platform views do not
provide intrinsic image sizing or an intrinsic aspect ratio to Flutter.

Set the application's deployment targets to Android API 24, iOS 16.0, and
macOS 12.0 or newer. Native HDR image rendering requires Android 14+, iOS 17+,
or macOS 14+.
