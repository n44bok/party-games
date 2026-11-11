import 'dart:typed_data';

/// Plays a WAV recording backwards: the sample frames are put in reverse
/// order, the header stays as it is (apart from the sizes).
///
/// Handles plain PCM WAV files with extra chunks (phones add some) and sizes
/// that are zero or too big (a recording that was not finished properly).
/// Throws [FormatException] when [wav] is not PCM WAV audio.
Uint8List reverseWav(Uint8List wav) {
  if (wav.length < 12 || _tag(wav, 0) != 'RIFF' || _tag(wav, 8) != 'WAVE') {
    throw const FormatException('Not a WAV file');
  }
  final data = ByteData.sublistView(wav);
  int? frameSize;
  int? dataStart;
  var declared = 0;

  var pos = 12;
  while (pos + 8 <= wav.length) {
    final id = _tag(wav, pos);
    final size = data.getUint32(pos + 4, Endian.little);
    final body = pos + 8;
    if (id == 'fmt ' && body + 16 <= wav.length) {
      final format = data.getUint16(body, Endian.little);
      final channels = data.getUint16(body + 2, Endian.little);
      final bits = data.getUint16(body + 14, Endian.little);
      // 1 = PCM, 0xFFFE = extensible (PCM in practice).
      if ((format != 1 && format != 0xFFFE) || channels == 0 || bits % 8 != 0) {
        throw const FormatException('Not PCM audio');
      }
      frameSize = channels * bits ~/ 8;
    } else if (id == 'data') {
      dataStart = body;
      declared = size;
      break;
    }
    // Chunks are padded to an even size.
    pos = body + size + (size.isOdd ? 1 : 0);
  }
  if (frameSize == null || frameSize == 0 || dataStart == null) {
    throw const FormatException('Missing fmt or data chunk');
  }

  final available = wav.length - dataStart;
  var length = (declared == 0 || declared > available) ? available : declared;
  length -= length % frameSize;

  final out = Uint8List(dataStart + length)..setRange(0, dataStart, wav);
  final frames = length ~/ frameSize;
  for (var i = 0; i < frames; i++) {
    final from = dataStart + (frames - 1 - i) * frameSize;
    out.setRange(
      dataStart + i * frameSize,
      dataStart + (i + 1) * frameSize,
      wav,
      from,
    );
  }
  final header = ByteData.sublistView(out);
  header.setUint32(4, out.length - 8, Endian.little);
  header.setUint32(dataStart - 4, length, Endian.little);
  return out;
}

/// How long a PCM WAV recording lasts, or [Duration.zero] if it cannot be
/// read.
Duration wavDuration(Uint8List wav) {
  try {
    final data = ByteData.sublistView(wav);
    var pos = 12;
    int? byteRate;
    while (pos + 8 <= wav.length) {
      final id = _tag(wav, pos);
      final size = data.getUint32(pos + 4, Endian.little);
      final body = pos + 8;
      if (id == 'fmt ') {
        byteRate = data.getUint32(body + 8, Endian.little);
      } else if (id == 'data') {
        final available = wav.length - body;
        final length = (size == 0 || size > available) ? available : size;
        if (byteRate == null || byteRate == 0) return Duration.zero;
        return Duration(microseconds: length * 1000000 ~/ byteRate);
      }
      pos = body + size + (size.isOdd ? 1 : 0);
    }
  } catch (_) {}
  return Duration.zero;
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
