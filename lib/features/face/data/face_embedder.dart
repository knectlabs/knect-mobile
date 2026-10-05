import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Model id the embedding is produced for. Must match the API default
/// (`FACE_EMBEDDING_MODEL_ID`) so the server compares a live embedding only
/// against reference rows produced by the SAME model (a compatible embedding
/// space). Bumped when the underlying model/dimension changes so older
/// enrollments are never compared against incompatible vectors.
const faceModelId = 'mobilefacenet-192-v1';

/// Embedding length produced by [faceModelId]. The bundled MobileFaceNet
/// (`assets/models/mobilefacenet.tflite`) maps a 112x112 RGB face to a
/// 192-float embedding. The server stores and compares vectors of this length.
const faceEmbeddingDimension = 192;

/// Square input size (height == width) the model expects, in pixels.
const _inputSize = 112;

/// Relative margin added around the ML Kit face box before the square crop,
/// so the aligned crop includes forehead/chin like the training data.
const _cropMargin = 0.25;

/// Asset path of the bundled face-embedding model.
const _modelAsset = 'assets/models/mobilefacenet.tflite';

/// A single face embedding ready to send to the API. The [vector] is a real,
/// fixed-length, L2-normalized float array — never logged, never persisted on
/// the device.
class FaceEmbedding {
  const FaceEmbedding({
    required this.vector,
    required this.dimension,
    required this.modelId,
  });

  final List<double> vector;
  final int dimension;
  final String modelId;
}

/// Detects a face in a captured photo and turns the aligned face crop into a
/// fixed-dimension identity embedding.
///
/// Detection / crop / alignment is done by Google ML Kit (no liveness or
/// anti-spoofing). The embedding is produced by a real MobileFaceNet TFLite
/// model run through `tflite_flutter`. The embedding is used only for 1:1
/// comparison on the server; the client never decides a match.
abstract class FaceEmbedder {
  /// Returns an L2-normalized [faceEmbeddingDimension]-length embedding for the
  /// largest face in the image at [imagePath], or `null` when no face is found.
  Future<FaceEmbedding?> detectAndEmbed(String imagePath);
}

/// ML Kit detection + MobileFaceNet TFLite embedding. Reuse a single instance;
/// call [dispose] to release the native detector and interpreter.
class MlKitFaceEmbedder implements FaceEmbedder {
  MlKitFaceEmbedder()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            // Accurate mode gives a tighter, more stable bounding box for the
            // crop. No landmarks/classification are requested.
            performanceMode: FaceDetectorMode.accurate,
          ),
        );

  final FaceDetector _detector;
  Interpreter? _interpreter;
  int? _outputLength;

  Future<Interpreter> _ensureInterpreter() async {
    final existing = _interpreter;
    if (existing != null) return existing;
    final interpreter = await Interpreter.fromAsset(_modelAsset);
    interpreter.allocateTensors();
    _outputLength = interpreter.getOutputTensor(0).shape.last;
    _interpreter = interpreter;
    return interpreter;
  }

  @override
  Future<FaceEmbedding?> detectAndEmbed(String imagePath) async {
    final file = File(imagePath);
    final input = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return null;

    // Largest face by bounding-box area is the subject of a selfie.
    faces.sort((a, b) => _area(b.boundingBox).compareTo(_area(a.boundingBox)));
    final box = faces.first.boundingBox;

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // Correct EXIF orientation so the crop box (reported in display
    // coordinates by ML Kit) lines up with the pixels.
    final oriented = img.bakeOrientation(decoded);
    final crop = _cropFace(oriented, box);
    final resized = img.copyResize(
      crop,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.cubic,
    );

    final vector = await _embed(resized);
    return FaceEmbedding(
      vector: vector,
      dimension: vector.length,
      modelId: faceModelId,
    );
  }

  double _area(Rect box) => box.width * box.height;

  /// Crops [image] to the face [box] expanded by [_cropMargin], clamped to the
  /// image bounds and squared so the aspect ratio matches the model input.
  img.Image _cropFace(img.Image image, Rect box) {
    final mx = box.width * _cropMargin;
    final my = box.height * _cropMargin;
    var left = (box.left - mx);
    var top = (box.top - my);
    var right = (box.right + mx);
    var bottom = (box.bottom + my);

    // Square the box around its centre so copyResize does not distort the face.
    final side = math.max(right - left, bottom - top);
    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    left = cx - side / 2;
    top = cy - side / 2;
    right = cx + side / 2;
    bottom = cy + side / 2;

    final x = left.round().clamp(0, image.width - 1);
    final y = top.round().clamp(0, image.height - 1);
    final w = (right - left).round().clamp(1, image.width - x);
    final h = (bottom - top).round().clamp(1, image.height - y);
    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  /// Runs the model on the 112x112 [face] crop and returns the L2-normalized
  /// embedding. Pixels are scaled to [-1, 1] (MobileFaceNet convention:
  /// (value - 127.5) / 128).
  Future<List<double>> _embed(img.Image face) async {
    final interpreter = await _ensureInterpreter();
    final outLength = _outputLength ?? faceEmbeddingDimension;

    // Shape [1, 112, 112, 3] of floats in [-1, 1].
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = face.getPixel(x, y);
          return <double>[
            (pixel.r - 127.5) / 128.0,
            (pixel.g - 127.5) / 128.0,
            (pixel.b - 127.5) / 128.0,
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List<double>.filled(outLength, 0.0));
    interpreter.run(input, output);
    return _l2Normalize(output.first);
  }

  /// Scales [vector] to unit length. Guards the zero vector so the output is
  /// always finite and normalized.
  List<double> _l2Normalize(List<double> vector) {
    var sumSquares = 0.0;
    for (final value in vector) {
      sumSquares += value * value;
    }
    final norm = math.sqrt(sumSquares);
    if (norm == 0) {
      final fallback = List<double>.filled(vector.length, 0.0);
      if (fallback.isNotEmpty) fallback[0] = 1;
      return fallback;
    }
    return [for (final value in vector) value / norm];
  }

  /// Releases the native ML Kit detector and the TFLite interpreter.
  Future<void> dispose() async {
    await _detector.close();
    _interpreter?.close();
    _interpreter = null;
  }
}
