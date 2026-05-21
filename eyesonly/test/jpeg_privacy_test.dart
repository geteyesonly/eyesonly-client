import 'dart:typed_data';

import 'package:eyesonly/services/jpeg_privacy.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  test('normalizeJpegOrientation rotates pixels when EXIF orientation is set', () {
    final img.Image base = img.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 0, 255);

    final Uint8List plainJpeg = Uint8List.fromList(
      img.encodeJpg(base, quality: 100),
    );
    final Uint8List exifOriented = _injectExifOrientation(plainJpeg, 6);

    final Uint8List normalized = JpegPrivacy.normalizeJpegOrientation(
      exifOriented,
    );
    final img.Image? decoded = img.decodeImage(normalized);

    expect(decoded, isNotNull);
    expect(decoded!.width, 1);
    expect(decoded.height, 2);
  });

  test('stripJpegMetadata removes APP segments', () {
    final img.Image base = img.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 0, 255);

    final Uint8List plainJpeg = Uint8List.fromList(
      img.encodeJpg(base, quality: 100),
    );
    final Uint8List exifOriented = _injectExifOrientation(plainJpeg, 6);

    expect(_hasAppSegmentBeforeSos(exifOriented), isTrue);

    final Uint8List stripped = JpegPrivacy.stripJpegMetadata(exifOriented);

    expect(_hasAppSegmentBeforeSos(stripped), isFalse);
    expect(img.decodeImage(stripped), isNotNull);
  });
}

Uint8List _injectExifOrientation(Uint8List jpeg, int orientation) {
  if (jpeg.length < 2 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
    throw ArgumentError('Input must be a JPEG with SOI marker');
  }
  if (orientation < 1 || orientation > 8) {
    throw ArgumentError('EXIF orientation must be in [1, 8]');
  }

  final BytesBuilder payload = BytesBuilder(copy: false)
    ..add(<int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00]) // Exif\0\0
    ..add(<int>[0x49, 0x49, 0x2A, 0x00]) // TIFF little-endian + 42
    ..add(<int>[0x08, 0x00, 0x00, 0x00]) // IFD0 offset
    ..add(<int>[0x01, 0x00]) // entry count
    ..add(<int>[0x12, 0x01]) // tag: Orientation
    ..add(<int>[0x03, 0x00]) // type: SHORT
    ..add(<int>[0x01, 0x00, 0x00, 0x00]) // count: 1
    ..add(<int>[orientation, 0x00, 0x00, 0x00]) // value in 4-byte field
    ..add(<int>[0x00, 0x00, 0x00, 0x00]); // next IFD offset

  final Uint8List payloadBytes = payload.toBytes();
  final int segLen = payloadBytes.length + 2;

  final BytesBuilder out = BytesBuilder(copy: false)
    ..add(<int>[0xFF, 0xD8]) // SOI
    ..add(<int>[0xFF, 0xE1, (segLen >> 8) & 0xFF, segLen & 0xFF])
    ..add(payloadBytes)
    ..add(jpeg.sublist(2));

  return out.toBytes();
}

bool _hasAppSegmentBeforeSos(Uint8List src) {
  if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) {
    return false;
  }

  int pos = 2;
  while (pos < src.length) {
    if (src[pos] != 0xFF) {
      return false;
    }

    while (pos < src.length && src[pos] == 0xFF) {
      pos++;
    }
    if (pos >= src.length) {
      return false;
    }

    final int marker = src[pos++];

    if (marker == 0xD9 || marker == 0xDA) {
      return false;
    }

    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      continue;
    }

    if (pos + 1 >= src.length) {
      return false;
    }

    final int segLen = (src[pos] << 8) | src[pos + 1];
    if (segLen < 2 || pos + segLen > src.length) {
      return false;
    }

    if (marker >= 0xE0 && marker <= 0xEF) {
      return true;
    }

    pos += segLen;
  }

  return false;
}
