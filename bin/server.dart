import 'dart:convert';
import 'dart:io';
import 'dart:isolate'; // Import for Isolate.run

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

// --- Imports from your local lib folder ---
// Replace 'flutter_appplication_1' with your actual package name found in pubspec.yaml
import 'fractal_engine.dart';
import 'algorithm_manager.dart';
import 'access_log_dao.dart';
import 'personas_dao.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ISOLATE WORKER FUNCTION
// ─────────────────────────────────────────────────────────────────────────────
// Runs the heavy Algorithm Dijkstra task in a separate thread.
String _runDijkstraWorkload(Map<String, dynamic> args) {
  return AlgorithmManager.generateRandomPoints(
    args['vertexSize'],
    args['sampleSize'],
    args['sourcePoint'],
  );
}

void main(List<String> args) async {
  // Initialize DAOs and Engine
  final fractalEngine = FractalEngine();
  final accessLogDAO = AccessLogDAO();
  final personasDAO = PersonasDAO();

  // Configure Router
  final app = Router();

  // ─────────────────────────────────────────────────────────────────────────────
  // PING (/zero - returns 204 No Content)
  // ─────────────────────────────────────────────────────────────────────────────
  app.get('/zero', (Request request) {
    return Response(204);
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // FRACTALS (Synchronous - safe for main thread)
  // ─────────────────────────────────────────────────────────────────────────────
  app.get('/api/fractals/generate', (Request request) async {
    try {
      final params = request.url.queryParameters;
      
      final kindParam = int.tryParse(params['kind'] ?? '') ?? 1;
      final fractalKind = FractalKind.fromValue(kindParam);

      // Default bounds based on kind
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

      // Explicitly typed list to ensure .toJson() works below
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
    } catch (e) {
      return Response.internalServerError(body: 'Error generating fractal: $e');
    }
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // ALGORITMO (DIJKSTRA) - Offloaded to Isolate
  // ─────────────────────────────────────────────────────────────────────────────
  app.get('/GenerateRandomVertex_SpringBoot', (Request request) async {
    const vertexSize = 9;
    const sampleSize = 23; // sampleSizeRaw maps to 23 in your examples
    const sourcePoint = 0;

    try {
      // !!! IMPORTANT !!!
      // We use Isolate.run in pure Dart to prevent this heavy calculation
      // from freezing the web server while it processes.
      final result = await Isolate.run(() => _runDijkstraWorkload({
            'vertexSize': vertexSize,
            'sampleSize': sampleSize,
            'sourcePoint': sourcePoint,
          }));

      return Response.ok(result, headers: {'Content-Type': 'text/plain'});
    } catch (e, stackTrace) {
      print('Dijkstra Error: $e\n$stackTrace');
      return Response.internalServerError(body: 'Computation Error: $e');
    }
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // DATOS (MySQL via DAO)
  // ─────────────────────────────────────────────────────────────────────────────
  
  app.get('/api/data/getAllLogs', (Request request) async {
    try {
      final logs = await accessLogDAO.getAllLogs();
      final jsonResponse = logs.map((l) => l.toJson()).toList();
       return Response.ok(
        jsonEncode(jsonResponse),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      // Return generic error to client, log specific error server-side
      return Response.internalServerError(body: 'Failed to fetch logs');
    }
  });

  app.get('/api/data/getAllPersons', (Request request) async {
    try {
      final personas = await personasDAO.getAllPersons();
      final jsonResponse = personas.map((p) => p.toJson()).toList();
      return Response.ok(
        jsonEncode(jsonResponse),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(body: 'Failed to fetch persons');
    }
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SERVER SETUP
  // ─────────────────────────────────────────────────────────────────────────────
  
  // Use logRequests() middleware to see incoming requests in console
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(app.call);

  // Determine port (Render/Railway provide PORT env var, default to 8080 locally)
  var port = int.parse(Platform.environment['PORT'] ?? '8080');
  
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}