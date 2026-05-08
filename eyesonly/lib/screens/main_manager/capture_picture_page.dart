import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eyesonly/screens/main_manager/send_captured_picture_page.dart';
import 'package:eyesonly/services/screen_feedback.dart';

class CapturePicturePage extends StatefulWidget {
  const CapturePicturePage({
    super.key,
    required this.baseUrl,
    required this.groupId,
    required this.groupName,
  });

  final String baseUrl;
  final String groupId;
  final String groupName;

  @override
  State<CapturePicturePage> createState() => _CapturePicturePageState();
}

class _CapturePicturePageState extends State<CapturePicturePage> {
  List<CameraDescription> _availableCameras = <CameraDescription>[];
  CameraController? _cameraController;
  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  String? _cameraErrorMessage;
  CameraLensDirection _activeLensDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusIndicatorPosition;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraErrorMessage = null;
    });

    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('No camera is available on this device.');
      }

      _availableCameras = cameras;
      final CameraDescription selectedCamera = _pickCamera(
        lensDirection: _activeLensDirection,
      );
      await _attachCamera(selectedCamera);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraErrorMessage = error.toString();
        _isInitializingCamera = false;
      });
    }
  }

  CameraDescription _pickCamera({required CameraLensDirection lensDirection}) {
    return _availableCameras.firstWhere(
      (CameraDescription camera) => camera.lensDirection == lensDirection,
      orElse: () => _availableCameras.first,
    );
  }

  Future<void> _attachCamera(CameraDescription camera) async {
    await _cameraController?.dispose();
    final CameraController controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    await controller.setFlashMode(_flashMode);

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _cameraController = controller;
      _activeLensDirection = camera.lensDirection;
      _isInitializingCamera = false;
    });
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 || _isInitializingCamera || _isCapturing) {
      return;
    }

    final CameraLensDirection nextDirection =
        _activeLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    setState(() {
      _isInitializingCamera = true;
      _cameraErrorMessage = null;
    });

    try {
      await _attachCamera(_pickCamera(lensDirection: nextDirection));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraErrorMessage = error.toString();
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _toggleFlashMode() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final FlashMode nextFlashMode =
        _flashMode == FlashMode.off ? FlashMode.auto : FlashMode.off;

    try {
      await controller.setFlashMode(nextFlashMode);
      if (!mounted) {
        return;
      }
      setState(() {
        _flashMode = nextFlashMode;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    }
  }

  Future<void> _capturePhoto() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    bool captureOrientationLocked = false;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Lock the capture orientation to the current device orientation so the
      // JPEG is saved with correct rotation on both Android and iOS.
      final bool isLandscape =
          MediaQuery.orientationOf(context) == Orientation.landscape;
      try {
        await controller.lockCaptureOrientation(
          isLandscape
              ? DeviceOrientation.landscapeLeft
              : DeviceOrientation.portraitUp,
        );
        captureOrientationLocked = true;
      } catch (_) {
        // Not all devices support lockCaptureOrientation; continue regardless.
      }

      final XFile capturedFile = await controller.takePicture();
      final Uint8List imageBytes = _stripJpegMetadata(
        await capturedFile.readAsBytes(),
      );

      if (!kIsWeb) {
        try {
          final File tempFile = File(capturedFile.path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // Best effort only. The captured bytes are already held in memory.
        }
      }

      if (!mounted) {
        return;
      }

      final bool? shouldDelete = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (BuildContext context) => SendCapturedPicturePage(
            baseUrl: widget.baseUrl,
            groupId: widget.groupId,
            groupName: widget.groupName,
            imageBytes: imageBytes,
          ),
        ),
      );

      if (shouldDelete == true && mounted) {
        ScreenFeedback.showMessage(context, 'Picture deleted.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(context, error);
    } finally {
      if (captureOrientationLocked) {
        try {
          await controller.unlockCaptureOrientation();
        } catch (_) {
          // Best effort only. Some devices do not support orientation unlock.
        }
      }
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  IconData _flashIcon() {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.off:
        return Icons.flash_off;
    }
  }

  String _flashLabel() {
    switch (_flashMode) {
      case FlashMode.auto:
        return 'Flash Auto';
      case FlashMode.always:
      case FlashMode.torch:
        return 'Flash On';
      case FlashMode.off:
        return 'Flash Off';
    }
  }

  Widget _buildPreview(CameraController controller) {
    final Size? sensorSize = controller.value.previewSize;

    // previewSize is in sensor (portrait-primary) coordinates, i.e. height > width
    // for a typical rear camera. CameraPreview rotates the texture internally to
    // match the device orientation. When the device is in landscape the displayed
    // aspect ratio is the inverse of the sensor ratio.
    final bool isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final double displayAspectRatio = sensorSize == null
        ? 1.0
        : isLandscape
            ? sensorSize.width / sensorSize.height
            : sensorSize.height / sensorSize.width;

    return GestureDetector(
      onTapUp: (TapUpDetails details) => _onPreviewTap(details, controller),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: displayAspectRatio,
              child: CameraPreview(controller),
            ),
          ),
          if (_focusIndicatorPosition != null)
            Positioned(
              left: _focusIndicatorPosition!.dx - 24,
              top: _focusIndicatorPosition!.dy - 24,
              child: IgnorePointer(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellowAccent, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onPreviewTap(
    TapUpDetails details,
    CameraController controller,
  ) async {
    if (!controller.value.isInitialized) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final Offset localPos = box.globalToLocal(details.globalPosition);
    final Size boxSize = box.size;

    // Normalise to [0,1] relative to the rendered box.
    final double x = (localPos.dx / boxSize.width).clamp(0.0, 1.0);
    final double y = (localPos.dy / boxSize.height).clamp(0.0, 1.0);

    setState(() => _focusIndicatorPosition = localPos);

    try {
      await controller.setFocusPoint(Offset(x, y));
      await controller.setExposurePoint(Offset(x, y));
    } catch (_) {
      // Some devices don't support manual focus — ignore silently.
    }

    // Hide indicator after a short delay.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _focusIndicatorPosition = null);
  }

  /// Strips all JPEG APP segments (EXIF, XMP, IPTC, ICC profile, GPS, etc.)
  /// from [src] without re-encoding, so image quality is fully preserved.
  static Uint8List _stripJpegMetadata(Uint8List src) {
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

      // Everything else (DQT, SOF, DHT, COM, …): keep.
      writeByte(0xFF);
      writeByte(marker);
      writeRange(pos, pos + segLen);
      pos += segLen;
    }

    return dst.sublist(0, dstPos);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitializingCamera)
            const Center(child: CircularProgressIndicator())
          else if (_cameraErrorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _cameraErrorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _initializeCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Camera'),
                    ),
                  ],
                ),
              ),
            )
          else if (controller != null && controller.value.isInitialized)
            _buildPreview(controller)
          else
            const SizedBox.shrink(),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: _toggleFlashMode,
                        icon: Icon(_flashIcon(), color: Colors.white),
                        tooltip: _flashLabel(),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _isCapturing ? null : _capturePhoto,
                      child: Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing ? Colors.white54 : Colors.white,
                          ),
                          child: _isCapturing
                              ? const Center(
                                  child: SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.black,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const Spacer(),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        onPressed: _availableCameras.length < 2 ? null : _switchCamera,
                        icon: const Icon(Icons.cameraswitch, color: Colors.white),
                        tooltip: 'Switch Camera',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}