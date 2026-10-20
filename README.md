# native_hdr_image_view

Display HDR images from files, encoded bytes, or URLs in native Apple image views without decoding or
tone-mapping them in Flutter.

| Platform | Minimum OS | Native view | Flutter view |
| --- | --- | --- | --- |
| iOS | 17.0 | `UIImageView` | `UiKitView` |
| macOS | 14.0 | `NSImageView` | `AppKitView` |

Both native views set `preferredImageDynamicRange` to `.high`. Visible HDR
depends on the source image, OS decoder, display capabilities, and available
display headroom. SDR files display normally. Android rendering is not implemented.

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

Changing the source loads the new image and cancels any previous download.
Changing only `fit`, `width`, or `height` does not reload the image. Unreadable
or undecodable images report `invalid_image`, HTTP and transport failures report
`network_error`, and invalid URL schemes report `invalid_url` through Flutter's
error reporting as `PlatformException`s.

### Network And File Access

Network images are supported on both iOS and macOS, using native `URLSession`
downloads. HTTPS is recommended; HTTP is subject to Apple's App Transport
Security policy and may require application-specific exceptions. Downloads do
not use Flutter's `ImageCache`; any HTTP caching follows the system URL session.

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

Set the application's deployment targets to iOS 17.0 and macOS 14.0 or newer.

