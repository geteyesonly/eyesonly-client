import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eyesonly/l10n/app_localizations.dart';

import 'package:eyesonly/screens/main_manager/send_captured_picture_page.dart';
import 'package:eyesonly/services/jpeg_privacy.dart';
import 'package:eyesonly/services/photo_expiration.dart';
import 'package:eyesonly/services/screen_feedback.dart';
import 'package:eyesonly/services/settings_store.dart';

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
  bool _isZooming = false;
  String? _cameraErrorMessage;
  CameraLensDirection _activeLensDirection = CameraLensDirection.back;
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusIndicatorPosition;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;
  bool _isApplyingZoomLevel = false;
  double? _pendingZoomLevel;
  final SettingsStore _settingsStore = SettingsStore();
  PhotoExpirationSelection _sessionExpirationSelection =
      const PhotoExpirationSelection.defaultSelection();

  @override
  void initState() {
    super.initState();
    _loadPreferredExpirationSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _initializeCamera();
    });
  }

  Future<void> _loadPreferredExpirationSelection() async {
    try {
      final PhotoExpirationSelection savedSelection =
          await _settingsStore.loadPreferredPhotoExpirationSelection();
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionExpirationSelection = savedSelection;
      });
    } catch (_) {
      // Keep the default if persisted preferences cannot be loaded.
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isInitializingCamera = true;
      _cameraErrorMessage = null;
    });

    try {
      final AppLocalizations? l10n = AppLocalizations.of(context);
      final String noCameraMessage =
          l10n?.captureNoCameraAvailable ?? 'No camera available.';
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError(noCameraMessage);
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
        _cameraErrorMessage = AppLocalizations.of(context)?.unexpectedErrorOccurred ?? 'An unexpected error occurred.';
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
    await _initializeZoomBounds(controller);

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

  Future<void> _initializeZoomBounds(CameraController controller) async {
    final double minZoom = await controller.getMinZoomLevel();
    final double maxZoom = await controller.getMaxZoomLevel();
    final double initialZoom = _currentZoomLevel.clamp(minZoom, maxZoom);

    await controller.setZoomLevel(initialZoom);

    _minZoomLevel = minZoom;
    _maxZoomLevel = maxZoom;
    _currentZoomLevel = initialZoom;
    _baseZoomLevel = initialZoom;
  }

  void _onScaleStart(ScaleStartDetails details) {
    final bool isPinching = details.pointerCount > 1;
    if (_isZooming != isPinching && mounted) {
      setState(() {
        _isZooming = isPinching;
      });
    } else {
      _isZooming = isPinching;
    }
    _baseZoomLevel = _currentZoomLevel;
  }

  void _onScaleUpdate(
    ScaleUpdateDetails details,
    CameraController controller,
  ) {
    if (details.pointerCount < 2) {
      return;
    }

    if (!_isZooming && mounted) {
      setState(() {
        _isZooming = true;
      });
    } else {
      _isZooming = true;
    }
    final double nextZoomLevel = (_baseZoomLevel * details.scale).clamp(
      _minZoomLevel,
      _maxZoomLevel,
    );
    _applyZoomLevel(controller, nextZoomLevel);
  }

  Future<void> _applyZoomLevel(
    CameraController controller,
    double zoomLevel,
  ) async {
    _pendingZoomLevel = zoomLevel;
    if (_isApplyingZoomLevel) {
      return;
    }

    _isApplyingZoomLevel = true;
    while (_pendingZoomLevel != null) {
      final double targetZoomLevel = _pendingZoomLevel!;
      _pendingZoomLevel = null;

      try {
        await controller.setZoomLevel(targetZoomLevel);
        if (!mounted) {
          _currentZoomLevel = targetZoomLevel;
        } else {
          setState(() {
            _currentZoomLevel = targetZoomLevel;
          });
        }
      } catch (_) {
        // Ignore unsupported zoom updates from transient camera states.
      }
    }
    _isApplyingZoomLevel = false;
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
        _cameraErrorMessage = AppLocalizations.of(context)?.unexpectedErrorOccurred ?? 'An unexpected error occurred.';
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _toggleFlashMode() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final FlashMode nextFlashMode = _flashMode == FlashMode.off
        ? FlashMode.auto
        : FlashMode.off;

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
      ScreenFeedback.showError(
        context,
        error,
        fallbackMessage: AppLocalizations.of(context)!.captureFlashModeFailed,
      );
    }
  }

  Future<void> _capturePhoto() async {
    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }

    bool captureOrientationLocked = false;
    XFile? capturedFile;

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

      capturedFile = await controller.takePicture();
      final Uint8List rawBytes = await capturedFile.readAsBytes();
      final Uint8List normalizedBytes = JpegPrivacy.normalizeJpegOrientation(
        rawBytes,
      );
      final Uint8List imageBytes = JpegPrivacy.stripJpegMetadata(
        normalizedBytes,
      );

      if (!mounted) {
        return;
      }

      final SendCapturedPictureResult? result =
          await Navigator.push<SendCapturedPictureResult>(
            context,
            MaterialPageRoute<SendCapturedPictureResult>(
              builder: (BuildContext context) => SendCapturedPicturePage(
                baseUrl: widget.baseUrl,
                groupId: widget.groupId,
                groupName: widget.groupName,
                imageBytes: imageBytes,
                initialExpirationSelection: _sessionExpirationSelection,
              ),
            ),
          );

      if (result != null) {
        _sessionExpirationSelection = result.expirationSelection;
        await _settingsStore.savePreferredPhotoExpirationSelection(
          _sessionExpirationSelection,
        );
      }

      if (result?.shouldDelete == true && mounted) {
        ScreenFeedback.showMessage(
          context,
          AppLocalizations.of(context)!.pictureDeleted,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScreenFeedback.showError(
        context,
        error,
        fallbackMessage: AppLocalizations.of(context)!.captureTakePhotoFailed,
      );
    } finally {
      if (!kIsWeb && capturedFile != null) {
        try {
          final File tempFile = File(capturedFile.path);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {
          // Best effort cleanup of the camera temp file.
        }
      }
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
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    switch (_flashMode) {
      case FlashMode.auto:
        return l10n.flashAuto;
      case FlashMode.always:
      case FlashMode.torch:
        return l10n.flashOn;
      case FlashMode.off:
        return l10n.flashOff;
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
      onScaleStart: _onScaleStart,
      onScaleUpdate: (ScaleUpdateDetails details) =>
          _onScaleUpdate(details, controller),
      onScaleEnd: (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isZooming = false;
        });
      },
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
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _isZooming ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentZoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
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
    if (!controller.value.isInitialized || _isZooming) return;

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

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
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
                      label: Text(l10n.retryCamera),
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
                        onPressed: _availableCameras.length < 2
                            ? null
                            : _switchCamera,
                        icon: const Icon(
                          Icons.cameraswitch,
                          color: Colors.white,
                        ),
                        tooltip: l10n.switchCamera,
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
