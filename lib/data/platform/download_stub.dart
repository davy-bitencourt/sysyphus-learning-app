// Browser-specific export has an alternate implementation on the Web.
Future<bool> downloadFile(String fileName, List<int> bytes) async => false;
