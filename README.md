# native_hdr_image_view

Native HDR image views for Flutter.

| Platform | Min OS version | Min OS version (HDR support) | Native view   |
| -------- | -------------- | ---------------------------- | ------------- |
| Android  | 7.0 (API 24)   | 14 (API 34)                  | `ImageView`   |
| iOS      | 16.0           | 17.0                         | `UIImageView` |
| macOS    | 12.0           | 14.0                         | `NSImageView` |

**Call `NativeHdrImageView.hasHdrSupport()` to check if the device supports HDR rendering**.

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
