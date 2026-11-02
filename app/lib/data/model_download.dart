import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';

import 'llm_runtime.dart';

class ModelDownloadCancelled implements Exception {
  const ModelDownloadCancelled();

  @override
  String toString() => 'ModelDownloadCancelled';
}

/// The downloaded bytes are not the file that was pinned. Deleted, never
/// loaded: a model file is executable input to a native library.
class ModelChecksumMismatch implements Exception {
  const ModelChecksumMismatch(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => 'ModelChecksumMismatch($expected != $actual)';
}

/// Downloads one model file, resumably, and verifies it.
///
/// Bytes land in `<file>.part` next to the target; an interrupted download
/// continues from where it stopped with an HTTP range request. Only after
/// the SHA-256 matches the pinned one does the file get its real name, so
/// the model loader can never pick up half a file or a swapped one.
class ModelDownloader {
  ModelDownloader({HttpClient Function()? clientFactory})
      : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  HttpClient? _client;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }

  static File partialFileFor(File target) => File('${target.path}.part');

  /// [source] overrides where the bytes come from — a mirror, or a local
  /// server in tests. The pinned size and checksum still apply.
  Future<File> download(
    LocalModelSpec spec,
    File target, {
    void Function(int received, int total)? onProgress,
    void Function()? onVerifying,
    Uri? source,
  }) async {
    final uri = source ?? spec.downloadUri;
    final partial = partialFileFor(target);
    var offset = partial.existsSync() ? partial.lengthSync() : 0;
    if (offset > spec.sizeBytes) {
      await partial.delete();
      offset = 0;
    }

    if (offset < spec.sizeBytes) {
      final client = _client = _clientFactory()
        ..connectionTimeout = const Duration(seconds: 20)
        ..userAgent = '100days (+https://github.com/mikexkllr/100days)';
      try {
        final response = await _open(client, uri, offset);
        if (response.statusCode == HttpStatus.ok && offset > 0) {
          // The server ignored the range: start over rather than append a
          // second copy to the first half.
          offset = 0;
        } else if (response.statusCode != HttpStatus.ok &&
            response.statusCode != HttpStatus.partialContent) {
          await response.drain<void>();
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }

        final sink = partial.openWrite(
          mode: offset > 0 ? FileMode.append : FileMode.write,
        );
        var received = offset;
        onProgress?.call(received, spec.sizeBytes);
        try {
          await for (final List<int> chunk in response) {
            if (_cancelled) throw const ModelDownloadCancelled();
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, spec.sizeBytes);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
      } on Object {
        if (_cancelled) throw const ModelDownloadCancelled();
        rethrow;
      } finally {
        client.close(force: true);
        _client = null;
      }
    }

    if (_cancelled) throw const ModelDownloadCancelled();
    onVerifying?.call();
    final path = partial.path;
    final digest = await Isolate.run(() => sha256OfFile(path));
    if (digest != spec.sha256) {
      await partial.delete();
      throw ModelChecksumMismatch(spec.sha256, digest);
    }
    return partial.rename(target.path);
  }

  /// Follows redirects by hand: the file lives on a CDN behind a redirect,
  /// and the range header has to reach the CDN, not just the first hop.
  Future<HttpClientResponse> _open(
    HttpClient client,
    Uri uri,
    int offset,
  ) async {
    var current = uri;
    for (var hop = 0; hop < 6; hop++) {
      final request = await client.getUrl(current);
      request.followRedirects = false;
      if (offset > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      final response = await request.close();
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null) break;
        current = current.resolve(location);
        if (current.scheme != 'https') {
          throw HttpException('Refusing a non-HTTPS redirect', uri: current);
        }
        continue;
      }
      return response;
    }
    throw HttpException('Too many redirects', uri: uri);
  }
}

/// SHA-256 of a file, read in chunks so a five-gigabyte model never has to
/// fit in memory. Runs in an isolate; the UI keeps animating.
String sha256OfFile(String path) {
  final sink = _DigestSink();
  final input = sha256.startChunkedConversion(sink);
  final file = File(path).openSync();
  try {
    const chunk = 4 * 1024 * 1024;
    while (true) {
      final bytes = file.readSync(chunk);
      if (bytes.isEmpty) break;
      input.add(bytes);
    }
  } finally {
    file.closeSync();
  }
  input.close();
  return sink.value.toString();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
