/// A local network synchronization host.
class SyncHost {
  final String address;
  final int port;
  const SyncHost(this.address, this.port);

  @override
  String toString() => '$address:$port';
}
