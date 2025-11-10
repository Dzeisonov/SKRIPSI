// lib/ml/infer_client.dart
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'infer_isolate.dart';

/// - Loads model + labels on the UI isolate
/// - Spawns worker isolate and passes raw bytes
class InferClient {
  final String modelAsset;
  final String labelsAsset;
  final int inputSize;

  InferClient({
    this.modelAsset = 'assets/model_20.tflite',
    this.labelsAsset = 'assets/labels_20.txt',
    this.inputSize = 224,
  });

  SendPort? _workPort;
  bool get isReady => _workPort != null;

  Future<void> start() async {
    // Load assets on UI isolate
    final modelData = await rootBundle.load(modelAsset);
    final modelBytes = modelData.buffer.asUint8List();

    final labelsStr = await rootBundle.loadString(labelsAsset);
    final labels = labelsStr
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final ready = ReceivePort();

    await Isolate.spawn(
      inferIsolateEntry,
      InitMsg(
        ready.sendPort,
        modelBytes,
        labels,
        inputSize,
      ),
    );

    // Read both handshake messages in one go (avoid double .first)
    final msgs = await ready.take(2).toList();
    if (msgs.isEmpty || msgs[0] is! SendPort) {
      throw Exception('Unexpected init handshake (no work port)');
    }

    _workPort = msgs[0] as SendPort;

    final second = msgs[1];
    if (second is Err) throw Exception(second.msg);
    if (second is! Ready) throw Exception('Classifier not ready');
  }

  /// Top-1
  Future<({String label, double confidence})> classify(Uint8List bytes) async {
    final list = await classifyTopK(bytes, k: 1);
    return list.first;
  }

  /// Top-K predictions
  Future<List<({String label, double confidence})>> classifyTopK(
    Uint8List bytes, {int k = 3}
  ) async {
    final port = _workPort;
    if (port == null) throw Exception('InferClient not started');

    final reply = ReceivePort();
    port.send(ClassifyMsg(reply.sendPort, bytes, k));
    final msg = await reply.first;

    if (msg is Ok) {
      return [(label: msg.label, confidence: msg.confidence)];
    } else if (msg is OkTop) {
      final out = <({String label, double confidence})>[];
      for (var i = 0; i < msg.labels.length; i++) {
        out.add((label: msg.labels[i], confidence: msg.confidences[i]));
      }
      return out;
    } else if (msg is Err) {
      throw Exception(msg.msg);
    } else {
      throw Exception('Unexpected response from isolate');
    }
  }
}
