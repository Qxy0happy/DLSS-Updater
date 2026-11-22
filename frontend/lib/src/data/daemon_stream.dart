/// A server-streaming response with explicit cancellation.
///
/// Cancelling a `StreamSubscription` does not cancel the underlying gRPC call,
/// so repositories receive this handle instead of a bare `Stream` and call
/// [cancel] when the user cancels. The server then observes context
/// cancellation and stops between files.
abstract class DaemonStream<T> {
  /// The events of the call, in the order the server sent them.
  Stream<T> get events;

  /// Cancels the call. Safe to call after the stream has completed.
  Future<void> cancel();
}
