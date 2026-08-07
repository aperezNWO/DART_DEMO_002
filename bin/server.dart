// ─────────────────────────────────────────────────────────────────────────────
// MS SQL SERVER NOT SUPPORTED BY DART. USE MYSQL OR POSTGRESQL INSTEAD.
// ─────────────────────────────────────────────────────────────────────────────
  
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// --- Imports from your local lib folder ---
// Replace 'flutter_appplication_1' with your actual package name from pubspec.yaml
import 'fractal_engine.dart';
import 'algorithm_manager.dart';
import 'access_log_dao.dart';
import 'personas_dao.dart';
import 'app_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: CENTRALIZED ERROR HANDLING
// ─────────────────────────────────────────────────────────────────────────────
/// Catches [AppException]s thrown down the pipeline and returns appropriate
/// JSON HTTP responses. Also catches unexpected fatal errors.
Middleware createErrorHandlingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on AppException catch (e) {
        // Map known domain exceptions to HTTP status codes
        int statusCode = HttpStatus.internalServerError;
        
        if (e is ValidationException) statusCode = HttpStatus.badRequest;
        else if (e is DatabaseException) statusCode = HttpStatus.serviceUnavailable;
        else if (e is ExternalServiceException) statusCode = HttpStatus.badGateway;

        // Return standardized JSON error structure
        return Response(
          statusCode,
          body: jsonEncode({
            'error': {
              'type': e.prefix,
              'message': e.message,
            }
          }),
          headers: {'Content-Type': 'application/json'},
        );

      } catch (e, stack) {
        // Catch-all for unexpected programming errors (500)
        print('[FATAL ERROR] $e\n$stack');
        return Response.internalServerError(
          body: jsonEncode({
            'error': {
              'type': 'ServerError',
              'message': 'An unexpected internal server error occurred.',
            }
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: HTTP REQUEST LOGGING
// ─────────────────────────────────────────────────────────────────────────────
/// Emulates SLF4J logging: method, uri, status, and duration.
Middleware logRequestsToJson() {
  return (Handler innerHandler) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      print('[START] HTTP ${request.method} ${request.requestedUri}');
      
      // 'late' ensures it's assigned before finally runs, safely handling scope
      late Response response;
      try {
        response = await innerHandler(request);
        return response;
      } finally {
        watch.stop();
        print('[END] HTTP ${request.method} ${request.requestedUri} '
              '-> Status: ${response.statusCode} [Time: ${watch.elapsedMilliseconds}ms]');
      }
    };
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: CORS (CROSS-ORIGIN RESOURCE SHARING)
// ─────────────────────────────────────────────────────────────────────────────
/// Configures headers to allow requests from web browsers.
Middleware addCorsHeaders() {
  final headers = {
    // WARNING: In production, replace '*' with your specific Angular frontend URL
    'Access-Control-Allow-Origin': '*', 
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization',
    // Required if Angular sends credentials (cookies/authorization headers)
    'Access-Control-Allow-Credentials': 'true', 
  };

  return createMiddleware(
    requestHandler: (Request request) {
      // Handle browser pre-flight OPTIONS requests
      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: headers);
      }
      // Pass other requests through
      return null;
    },
    responseHandler: (Response response) {
      // Add headers to successful responses
      return response.change(headers: headers);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE WORKER FUNCTION for Dijkstra
// ─────────────────────────────────────────────────────────────────────────────
/// Runs heavy computation in a separate thread to avoid blocking server.
String _runDijkstraWorkload(Map<String, dynamic> args) {
  try {
    return AlgorithmManager.generateRandomPoints(
      args['vertexSize'],
      args['sampleSize'],
      args['sourcePoint'],
    );
  } catch (e) {
    // Wrap generic algorithm errors in a specific exception type
    throw ExternalServiceException('Algorithm execution failed: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SERVER ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────
void main(List<String> args) async {
  // 1. Initialize Data Access Objects and Engine
  final fractalEngine = FractalEngine();
  final accessLogDAO = AccessLogDAO();
  final personasDAO = PersonasDAO();

  // 2. Configure Router
  final app = Router();

  // --- Ping Endpoint ---
  app.get('/zero', (Request request) {
    return Response(204); // No Content
  });

  // --- Fractal Generation Endpoint ---
  app.get('/api/fractals/generate', (Request request) async {
    final params = request.url.queryParameters;
    
    // Parse kind, throw ValidationException if bad input
    final kindParam = int.tryParse(params['kind'] ?? '');
    if (kindParam == null) {
      throw ValidationException('Missing or invalid "kind" parameter.');
    }
    
    final fractalKind = FractalKind.fromValue(kindParam);

    // Determine bounds
    Bounds defaultBounds = (fractalKind == FractalKind.mandelbrot)
        ? const Bounds(xMin: -2.0, xMax: 1.0, yMin: -1.2, yMax: 1.2)
        : const Bounds(xMin: -1.5, xMax: 1.5, yMin: -1.5, yMax: 1.5);

    double? xMin = double.tryParse(params['xMin'] ?? '');
    double? xMax = double.tryParse(params['xMax'] ?? '');
    double? yMin = double.tryParse(params['yMin'] ?? '');
    double? yMax = double.tryParse(params['yMax'] ?? '');

    Bounds bounds = defaultBounds;
    if (xMin != null && xMax != null && yMin != null && yMax != null) {
      bounds = Bounds(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax);
    }

    int maxIterations = int.tryParse(params['maxIterations'] ?? '') ?? 500;

    // Generate points (FractalEngine methods are now static/pure)
    List<FractalPoint> points = fractalEngine.getFractal(
      fractalKind, 
      bounds, 
      maxIterations
    );
    
    // Serialize to JSON
    final jsonResponse = points.map((p) => p.toJson()).toList();

    return Response.ok(
      jsonEncode(jsonResponse),
      headers: {'Content-Type': 'application/json'},
    );
    // Errors caught by middleware
  });

  // --- Dijkstra Algorithm Endpoint (Async/Isolate) ---
  app.get('/GenerateRandomVertex_SpringBoot', (Request request) async {
    // Constants derived from original implementation
    const vertexSize = 9;
    const sampleSize = 23; 
    const sourcePoint = 0;

    // Move heavy lifting to background Isolate
    final result = await Isolate.run(() => _runDijkstraWorkload({
          'vertexSize': vertexSize,
          'sampleSize': sampleSize,
          'sourcePoint': sourcePoint,
        }));

    return Response.ok(result, headers: {'Content-Type': 'text/plain'});
    // Errors caught by middleware
  });

  // --- Database Data Endpoints ---
  
  app.get('/api/data/getAllLogs', (Request request) async {
    // DAO now throws DatabaseException which is caught by middleware
    final logs = await accessLogDAO.getAllLogs();
    
    return Response.ok(
      jsonEncode(logs.map((l) => l.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  });

  app.get('/api/data/getAllPersons', (Request request) async {
    // DAO now throws DatabaseException which is caught by middleware
    final personas = await personasDAO.getAllPersons();
    
    return Response.ok(
      jsonEncode(personas.map((p) => p.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Server Setup with Middleware Pipeline
  // ─────────────────────────────────────────────────────────────────────────────
  
  // Order matters: 
  // 1. CORS allows request through
  // 2. Logger times the execution
  // 3. Error Handler catches failures from logger or handlers
  final handler = const Pipeline()
      .addMiddleware(addCorsHeaders())
      .addMiddleware(logRequestsToJson())
      .addMiddleware(createErrorHandlingMiddleware()) 
      .addHandler(app.call);

  // Use PORT environment variable (e.g., from Render/Railway), default to 8080
  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.parse(portStr);
  
  // Start server
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}