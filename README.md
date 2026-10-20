# native_hdr_image_view

Display local HDR image files in native Apple image views without decoding or
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
import 'package:flutter/widgets.dart';
import 'package:native_hdr_image_view/native_hdr_image_view.dart';

SizedBox(
	width: 320,
	height: 240,
	child: NativeHdrImageView(
		imagePath: '/absolute/path/to/image.heic',
		fit: BoxFit.cover,
	),
)
```

`imagePath` is a local filesystem path, not a URL or Flutter asset key. The app
must have permission to read it, including any required sandbox access on macOS.
Copy bundled assets or download remote files to a local file before displaying
them. A null path clears the image. Changing the path loads the new file;
changing `fit` updates the existing native view without reloading the file.
Unreadable or unsupported files report a `PlatformException` through Flutter's
error reporting with code `invalid_image`.

All Flutter `BoxFit` values are supported: `fill`, `contain` (default), `cover`,
`fitWidth`, `fitHeight`, `none`, and `scaleDown`. Images are centered and clipped
to the widget's bounds. Give the widget bounded dimensions, as native platform
views do not provide intrinsic image sizing to Flutter.

Set the application's deployment targets to iOS 17.0 and macOS 14.0 or newer.

