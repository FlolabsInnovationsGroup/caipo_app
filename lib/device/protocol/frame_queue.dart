import 'dart:async';
import 'dart:typed_data';

class TransferCancelled implements Exception {
  const TransferCancelled();
}

/// Stops an in-flight [FrameQueue.next] wait.
class TransferCancellation {
  final Completer<void> _done = Completer<void>();
  var cancelled = false;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    if (!_done.isCompleted) _done.complete();
  }

  Future<void> get whenCancelled => _done.future;
}

/// Buffers inbound frames so a timeout does not leave a pending read.
class FrameQueue {
  FrameQueue(Stream<Uint8List> frames) {
    _sub = frames.listen(
      (frame) {
        if (_waiters.isNotEmpty) {
          _waiters.removeAt(0).complete(frame);
        } else {
          _buffer.add(frame);
        }
      },
      onDone: () {
        for (final waiter in _waiters) {
          if (!waiter.isCompleted) waiter.complete(null);
        }
        _waiters.clear();
        _closed = true;
      },
    );
  }

  final List<Uint8List> _buffer = [];
  final List<Completer<Uint8List?>> _waiters = [];
  late final StreamSubscription<Uint8List> _sub;
  var _closed = false;

  Future<Uint8List?> next(Duration timeout, {Future<void>? cancel}) {
    if (_buffer.isNotEmpty) return Future<Uint8List?>.value(_buffer.removeAt(0));
    if (_closed) return Future<Uint8List?>.value();
    final waiter = Completer<Uint8List?>();
    _waiters.add(waiter);
    Timer(timeout, () {
      if (!waiter.isCompleted) {
        _waiters.remove(waiter);
        waiter.complete(null);
      }
    });
    if (cancel != null) {
      cancel.then((_) {
        if (!waiter.isCompleted) {
          _waiters.remove(waiter);
          waiter.completeError(const TransferCancelled());
        }
      });
    }
    return waiter.future;
  }

  Future<void> close() => _sub.cancel();
}
