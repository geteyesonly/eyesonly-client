import 'dart:typed_data';

import 'package:image/image.dart' as img;

class JpegPrivacy {
  const JpegPrivacy._();

  static Uint8List normalizeJpegOrientation(Uint8List src) {
    final int? orientation = _readJpegExifOrientation(src);
    if (orientation == null || orientation == 1) {
      return src;
    }

    final img.Image? decoded = img.decodeImage(src);
    if (decoded == null) {
      return src;
    }

    final img.Image normalized = img.bakeOrientation(decoded);
    return Uint8List.fromList(img.encodeJpg(normalized, quality: 100));
  }

  /// Strips all JPEG APP segments (EXIF, XMP, IPTC, ICC profile, GPS, etc.)
  /// from [src] without re-encoding, so image quality is fully preserved.
  static Uint8List stripJpegMetadata(Uint8List src) {
    // A valid JPEG starts with SOI: FF D8.
    if (src.length < 2 || src[0] != 0xFF || src[1] != 0xD8) {
      return src;
    }

    final Uint8List dst = Uint8List(src.length);
    int dstPos = 0;

    void writeByte(int b) => dst[dstPos++] = b;

    void writeRange(int start, int end) {
      dst.setRange(dstPos, dstPos + (end - start), src, start);
      dstPos += end - start;
    }

    // Copy SOI.
    writeByte(0xFF);
    writeByte(0xD8);

    int pos = 2;
    while (pos < src.length) {
      if (src[pos] != 0xFF) break; // malformed stream

      // Advance past any 0xFF fill bytes.
      while (pos < src.length && src[pos] == 0xFF) {
        pos++;
      }
      if (pos >= src.length) break;

      final int marker = src[pos++];

      // EOI: done.
      if (marker == 0xD9) {
        writeByte(0xFF);
        writeByte(0xD9);
        break;
      }

      // SOS: write it and all remaining bytes (entropy-coded data + EOI) as-is.
      if (marker == 0xDA) {
        writeByte(0xFF);
        writeByte(0xDA);
        writeRange(pos, src.length);
        break;
      }

      // Standalone markers (RST0-7, TEM): no length field.
      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        writeByte(0xFF);
        writeByte(marker);
        continue;
      }

      // All other markers carry a 2-byte length field (length includes itself).
      if (pos + 1 >= src.length) break;
      final int segLen = (src[pos] << 8) | src[pos + 1];
      if (segLen < 2 || pos + segLen > src.length) break; // malformed

      // APP0–APP15 (0xE0–0xEF): these carry all metadata — drop them.
      if (marker >= 0xE0 && marker <= 0xEF) {
        pos += segLen;
        continue;
      }

      // Everything else (DQT, SOF, DHT, COM, ...): keep.
      writeByte(0xFF);
      writeByte(marker);
      writeRange(pos, pos + segLen);
      pos += segLen;
    }

    return dst.sublist(0, dstPos);
  }

  static int? _readJpegExifOrientation(Uint8List src) {
    if (src.length < 4 || src[0] != 0xFF || src[1] != 0xD8) {
      return null;
    }

    int pos = 2;
    while (pos < src.length) {
      if (src[pos] != 0xFF) {
        break;
      }

      while (pos < src.length && src[pos] == 0xFF) {
        pos++;
      }
      if (pos >= src.length) {
        break;
      }

      final int marker = src[pos++];
      if (marker == 0xD9 || marker == 0xDA) {
        break;
      }

      if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        continue;
      }

      if (pos + 1 >= src.length) {
        break;
      }
      final int segLen = (src[pos] << 8) | src[pos + 1];
      if (segLen < 2 || pos + segLen > src.length) {
        break;
      }

      if (marker == 0xE1 && segLen >= 10) {
        final int dataStart = pos + 2;
        if (dataStart + 6 <= src.length &&
            src[dataStart] == 0x45 &&
            src[dataStart + 1] == 0x78 &&
            src[dataStart + 2] == 0x69 &&
            src[dataStart + 3] == 0x66 &&
            src[dataStart + 4] == 0x00 &&
            src[dataStart + 5] == 0x00) {
          final int tiffStart = dataStart + 6;
          final int segmentEnd = pos + segLen;
          if (tiffStart + 8 > segmentEnd) {
            return null;
          }

          final bool littleEndian =
              src[tiffStart] == 0x49 && src[tiffStart + 1] == 0x49;
          final bool bigEndian =
              src[tiffStart] == 0x4D && src[tiffStart + 1] == 0x4D;
          if (!littleEndian && !bigEndian) {
            return null;
          }

          int read16(int offset) {
            if (littleEndian) {
              return src[offset] | (src[offset + 1] << 8);
            }
            return (src[offset] << 8) | src[offset + 1];
          }

          int read32(int offset) {
            if (littleEndian) {
              return src[offset] |
                  (src[offset + 1] << 8) |
                  (src[offset + 2] << 16) |
                  (src[offset + 3] << 24);
            }
            return (src[offset] << 24) |
                (src[offset + 1] << 16) |
                (src[offset + 2] << 8) |
                src[offset + 3];
          }

          if (read16(tiffStart + 2) != 42) {
            return null;
          }

          final int ifdOffset = read32(tiffStart + 4);
          final int ifd0 = tiffStart + ifdOffset;
          if (ifd0 + 2 > segmentEnd) {
            return null;
          }

          final int entryCount = read16(ifd0);
          int entryPos = ifd0 + 2;
          for (int i = 0; i < entryCount; i++) {
            if (entryPos + 12 > segmentEnd) {
              return null;
            }

            final int tag = read16(entryPos);
            if (tag == 0x0112) {
              final int type = read16(entryPos + 2);
              final int count = read32(entryPos + 4);

              if (type != 3 || count < 1) {
                return null;
              }

              int orientation;
              if (count == 1) {
                orientation = read16(entryPos + 8);
              } else {
                final int valueOffset = read32(entryPos + 8);
                final int valuePos = tiffStart + valueOffset;
                if (valuePos + 2 > segmentEnd) {
                  return null;
                }
                orientation = read16(valuePos);
              }

              if (orientation >= 1 && orientation <= 8) {
                return orientation;
              }
              return null;
            }
            entryPos += 12;
          }
        }
      }

      pos += segLen;
    }

    return null;
  }
}