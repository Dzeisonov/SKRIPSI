// lib/ml/infer_isolate.dart
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

/// Messages passed between UI isolate and worker isolate
class InitMsg {
  final SendPort replyPort;
  final Uint8List modelBytes;
  final List<String> labels;
  final int inputSize;
  InitMsg(this.replyPort, this.modelBytes, this.labels, this.inputSize);
}

class ClassifyMsg {
  final SendPort replyPort;
  final Uint8List imageBytes;
  final int topK; // NEW: request Top-K
  ClassifyMsg(this.replyPort, this.imageBytes, [this.topK = 1]);
}

class Ready {}
class Ok { 
  final String label; 
  final double confidence; 
  Ok(this.label, this.confidence); 
}

// Multiple results payload
class OkTop {
  final List<String> labels;
  final List<double> confidences;
  OkTop(this.labels, this.confidences);
}

class Err { 
  final String msg; 
  Err(this.msg); 
}

/// Background isolate entry. Only uses what UI passes in.
void inferIsolateEntry(dynamic message) async {
  if (message is! InitMsg) return;

  final inbox = ReceivePort();

  late Interpreter interpreter;
  late List<String> labels;
  late ImageProcessor processor;

  try {
    // Build interpreter from bytes
    interpreter = await Interpreter.fromBuffer(
      message.modelBytes.buffer.asUint8List(),
      options: InterpreterOptions()
        ..threads = 2
        ..useNnApiForAndroid = true,
    );

    labels = message.labels;

    processor = ImageProcessorBuilder()
        .add(ResizeOp(message.inputSize, message.inputSize, ResizeMethod.BILINEAR))
        .build();

    // Handshake: send the port for work, then Ready
    message.replyPort.send(inbox.sendPort);
    message.replyPort.send(Ready());
  } catch (e) {
    message.replyPort.send(Err('Init failed: $e'));
    return;
  }

  await for (final m in inbox) {
    if (m is ClassifyMsg) {
      try {
        final decoded = img.decodeImage(m.imageBytes);
        if (decoded == null) {
          m.replyPort.send(Err('Invalid image bytes'));
          continue;
        }

        var ti = TensorImage(TensorType.float32)..loadImage(decoded);
        ti = processor.process(ti);

        final out = TensorBufferFloat([1, labels.length]);
        interpreter.run(ti.buffer, out.buffer);

        final map = TensorLabel.fromList(labels, out).getMapWithFloatValue();

        // Sort descending & take Top-K
        final sorted = map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final k = m.topK.clamp(1, sorted.length);
        final top = sorted.take(k).toList();

        if (k == 1) {
          m.replyPort.send(Ok(top.first.key, top.first.value));
        } else {
          m.replyPort.send(
            OkTop(
              top.map((e) => e.key).toList(),
              top.map((e) => e.value).toList(),
            ),
          );
        }
      } catch (e) {
        m.replyPort.send(Err('Run failed: $e'));
      }
    }
  }
}
