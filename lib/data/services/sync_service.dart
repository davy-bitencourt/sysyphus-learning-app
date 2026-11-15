// The browser cannot host TCP or discover LAN devices over UDP.
// It can join an existing desktop host using HTTP with CORS enabled.
export 'sync_service_io.dart'
    if (dart.library.js_interop) 'sync_service_web.dart';
