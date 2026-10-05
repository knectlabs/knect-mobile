import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Model id the embedding is produced for. Must match the API default
/// (`FACE_EMBEDDING_MODEL_ID`) so the server compares against the right rows.
const faceModelId = 'mobilefacenet-v1';

/// Fixed embedding length for [faceModelId]. The API stores and compares a
/// 128-dimension vector; the output here must be exactly this long.
const faceEmbeddingDimension = 128;

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
/// fixed-dimension embedding.
///
/// Detection is done by Google ML Kit (detection / crop / alignment ONLY — no
/// liveness or anti-spoofing). The embedding step is a clearly-marked
/// PLACEHOLDER: it does NOT yet run real MobileFaceNet weights. See
/// [_embedCrop] for the exact contract and the replacement path.
abstract class FaceEmbedder {
  /// Returns a 128-dimension L2-normalized embedding for the largest face in
  /// the image at [imagePath], or `null` when no face is detected.
  Future<FaceEmbedding?> detectAndEmbed(String imagePath);
}

/// ML Kit backed [FaceEmbedder]. Reuse a single instance; call [dispose] when
/// done to release the native detector.
class MlKitFaceEmbedder implements FaceEmbedder {
  MlKitFaceEmbedder()
      : _detector = FaceDetector(
          options: FaceDetectorOptions(
            // Accurate mode improves the crop box; no classification/landmarks
            // are needed because we only use the bounding box for the crop.
            performanceMode: FaceDetectorMode.accurate,
          ),
        );

  final FaceDetector _detector;

  @override
  Future<FaceEmbedding?> detectAndEmbed(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final faces = await _detector.processImage(input);
    if (faces.isEmpty) return null;

    // Pick the largest face by bounding-box area; it is the subject of a
    // self-portrait selfie.
    faces.sort((a, b) =>
        _area(b.boundingBox).compareTo(_area(a.boundingBox)));
    final face = faces.first;

    final bytes = await File(imagePath).readAsBytes();
    final vector = _embedCrop(bytes, face.boundingBox);
    return FaceEmbedding(
      vector: vector,
      dimension: faceEmbeddingDimension,
      modelId: faceModelId,
    );
  }

  double _area(Rect box) => box.width * box.height;

  /// PLACEHOLDER embedding.
  ///
  /// TODO(face): replace with a real MobileFaceNet (`.tflite`) inference via
  /// `tflite_flutter`: crop/align [box] from the decoded image, resize to the
  /// model input (112x112), run the interpreter, and return its 128-float
  /// output. The dependency is already added for that work.
  ///
  /// Until then this derives a DETERMINISTIC vector from the cropped face
  /// region's raw bytes so the same face/photo yields the same vector. The
  /// RESULT is a genuine [faceEmbeddingDimension]-length float array that is
  /// L2-normalized — the server contract (dimension + normalized vector) is
  /// real; only the feature extractor is a stand-in. It is NOT an identity
  /// model and must not be relied on for real matching.
  List<double> _embedCrop(Uint8List imageBytes, Rect box) {
    // Mix the face-region geometry into the byte sampling so different crops of
    // the same photo diverge, keeping the placeholder deterministic per face.
    final seed = (box.left.round() * 73856093) ^
        (box.top.round() * 19349663) ^
        (box.width.round() * 83492791) ^
        (box.height.round() * 2654435761);

    final accumulators = List<double>.filled(faceEmbeddingDimension, 0.0);
    if (imageBytes.isNotEmpty) {
      for (var i = 0; i < imageBytes.length; i++) {
        final bucket = (i + (seed & 0x7fffffff)) % faceEmbeddingDimension;
        // Centre each byte around zero so the vector is not all-positive.
        accumulators[bucket] += imageBytes[i] - 128.0;
      }
    } else {
      // No pixels to sample: fall back to a geometry-only deterministic fill so
      // the output is still a valid, non-degenerate vector.
      for (var i = 0; i < faceEmbeddingDimension; i++) {
        accumulators[i] = math.sin(seed * (i + 1) * 0.0001);
      }
    }

    return _l2Normalize(accumulators);
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
      // Degenerate input: emit a fixed unit vector (first axis = 1) so the
      // server still receives a normalized, correct-dimension array.
      final fallback = List<double>.filled(faceEmbeddingDimension, 0.0);
      fallback[0] = 1;
      return fallback;
    }
    return [for (final value in vector) value / norm];
  }

  /// Releases the native ML Kit detector.
  Future<void> dispose() => _detector.close();
}
