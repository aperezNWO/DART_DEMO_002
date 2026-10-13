// ─────────────────────────────────────────────────────────────────────────────
// MS SQL SERVER NOT SUPPORTED BY DART. USE MYSQL OR POSTGRESQL INSTEAD.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:yaml/yaml.dart'; // Requiere el paquete 'yaml' en pubspec.yaml

// --- Importaciones de tu carpeta local lib ---
import 'fractal_engine.dart';
import 'algorithm_manager.dart';
import 'access_log_dao.dart';
import 'personas_dao.dart';
import 'app_exception.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DICCIONARIO DE ENDPOINTS (Inspirado en C++)
// ─────────────────────────────────────────────────────────────────────────────
class EndpointInfo {
  final String path;
  final String description;

  const EndpointInfo(this.path, this.description);
}

final Map<String, EndpointInfo> endpointDictionary = {
  'HEALTH_ENDPOINT':
      const EndpointInfo('/health', 'Print all endpoints and a server status '),
  'PING_ENDPOINT':
      const EndpointInfo('/zero', 'Quick server verification (Ping)'),
  'FRACTAL_ENDPOINT': const EndpointInfo('/api/fractals/generate',
      'Fratacls Genearation (Julia, Mandelbrot, Barnsley Fern)'),
  'DIJKSTRA_ENDPOINT': const EndpointInfo('/GenerateRandomVertex_Dart',
      'Generar vértices aleatorios mediante Dijkstra (Isolate)'),
  'GET_ALL_LOGS_ENDPOINT': const EndpointInfo('/api/data/getAllLogs',
      'Get the first 100 records from the database' 's application logs  '),
  'GET_ALL_PERSONS_ENDPOINT': const EndpointInfo(
      '/api/data/getAllPersons', 'Get a sample list of persons from database'),
  'LANGUAGE_VERSION_ENDPOINT': const EndpointInfo(
      '/api/system/language-version', 'Get Dart language version'),
  'SERVER_VERSION_ENDPOINT': const EndpointInfo(
      '/api/system/server-version', 'Get Dart HTTP Server version'),
  'APP_VERSION_ENDPOINT':
      const EndpointInfo('/api/system/app-version', 'Get Application Version'),
};

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: MANEJO CENTRALIZADO DE ERRORES
// ─────────────────────────────────────────────────────────────────────────────
Middleware createErrorHandlingMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on AppException catch (e) {
        int statusCode = HttpStatus.internalServerError;

        if (e is ValidationException)
          statusCode = HttpStatus.badRequest;
        else if (e is DatabaseException)
          statusCode = HttpStatus.serviceUnavailable;
        else if (e is ExternalServiceException)
          statusCode = HttpStatus.badGateway;

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
        print('[FATAL ERROR] $e\n$stack');
        return Response.internalServerError(
          body: jsonEncode({
            'error': {
              'type': 'ServerError',
              'message': 'Ocurrió un error interno inesperado en el servidor.',
            }
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    };
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: REGISTRO DE SOLICITUDES HTTP
// ─────────────────────────────────────────────────────────────────────────────
Middleware logRequestsToJson() {
  return (Handler innerHandler) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      print('[START] HTTP ${request.method} ${request.requestedUri}');

      late Response response;
      try {
        response = await innerHandler(request);
        return response;
      } finally {
        watch.stop();
        print('[END] HTTP ${request.method} ${request.requestedUri} '
            '-> Estado: ${response.statusCode} [Tiempo: ${watch.elapsedMilliseconds}ms]');
      }
    };
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// MIDDLEWARE: CORS (INTERCAMBIO DE RECURSOS DE ORIGEN CRUZADO)
// ─────────────────────────────────────────────────────────────────────────────
Middleware addCorsHeaders() {
  final headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, Content-Type, Accept, Authorization',
    'Access-Control-Allow-Credentials': 'true',
  };

  return createMiddleware(
    requestHandler: (Request request) {
      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: headers);
      }
      return null;
    },
    responseHandler: (Response response) {
      return response.change(headers: headers);
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FUNCIÓN WORKER ISOLATE PARA DIJKSTRA
// ─────────────────────────────────────────────────────────────────────────────
String _runDijkstraWorkload(Map<String, dynamic> args) {
  try {
    return AlgorithmManager.generateRandomPoints(
      args['vertexSize'],
      args['sampleSize'],
      args['sourcePoint'],
    );
  } catch (e) {
    throw ExternalServiceException('Falló la ejecución del algoritmo: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUNTO DE ENTRADA PRINCIPAL DEL SERVIDOR
// ─────────────────────────────────────────────────────────────────────────────
void main(List<String> args) async {
  // 1. Inicializar DAOs y Motor
  final fractalEngine = FractalEngine();
  final accessLogDAO = AccessLogDAO();
  final personasDAO = PersonasDAO();

  // 2. Configurar Enrutador
  final app = Router();

  Future<String> getShelfVersion() async {
    try {
      final lockFile = File('pubspec.lock');
      if (await lockFile.exists()) {
        final content = await lockFile.readAsString();
        final doc = loadYaml(content);
        return doc['packages']['shelf']['version']?.toString() ?? 'desconocido';
      }
    } catch (_) {}
    return 'desconocido';
  }

  // --- Endpoint Health (Lista todos los endpoints del diccionario) ---
  app.get(endpointDictionary['HEALTH_ENDPOINT']!.path, (Request request) async {
    final serverVersion = await getShelfVersion();

    final endpointsList = endpointDictionary.entries.map((entry) {
      return {
        'key': entry.key,
        'path': entry.value.path,
        'description': entry.value.description,
      };
    }).toList();

    return Response.ok(
      jsonEncode({
        'server': 'Dart / Shelf -  HTTP Server - v[$serverVersion] Working!',
        'endpoints': endpointsList,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- Endpoint Ping (/zero) ---
  app.get(endpointDictionary['PING_ENDPOINT']!.path, (Request request) {
    return Response(204);
  });

  // --- Endpoint de Generación de Fractales ---
  app.get(endpointDictionary['FRACTAL_ENDPOINT']!.path,
      (Request request) async {
    final params = request.url.queryParameters;

    final kindParam = int.tryParse(params['kind'] ?? '');
    if (kindParam == null) {
      throw ValidationException('Parámetro "kind" faltante o inválido.');
    }

    final fractalKind = FractalKind.fromValue(kindParam);

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

    List<FractalPoint> points =
        fractalEngine.getFractal(fractalKind, bounds, maxIterations);

    final jsonResponse = points.map((p) => p.toJson()).toList();

    return Response.ok(
      jsonEncode(jsonResponse),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- Endpoint de Algoritmo Dijkstra (Async/Isolate) ---
  app.get(endpointDictionary['DIJKSTRA_ENDPOINT']!.path,
      (Request request) async {
    const vertexSize = 9;
    const sampleSize = 23;
    const sourcePoint = 0;

    final result = await Isolate.run(() => _runDijkstraWorkload({
          'vertexSize': vertexSize,
          'sampleSize': sampleSize,
          'sourcePoint': sourcePoint,
        }));

    return Response.ok(result, headers: {'Content-Type': 'text/plain'});
  });

  // --- Endpoints de Datos de Base de Datos ---
  app.get(endpointDictionary['GET_ALL_LOGS_ENDPOINT']!.path,
      (Request request) async {
    final logs = await accessLogDAO.getAllLogs();

    return Response.ok(
      jsonEncode(logs.map((l) => l.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  });

  app.get(endpointDictionary['GET_ALL_PERSONS_ENDPOINT']!.path,
      (Request request) async {
    final personas = await personasDAO.getAllPersons();

    return Response.ok(
      jsonEncode(personas.map((p) => p.toJson()).toList()),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- Endpoint de Versión de Lenguaje ---
  app.get(endpointDictionary['LANGUAGE_VERSION_ENDPOINT']!.path,
      (Request request) {
    return Response.ok(
      jsonEncode({
        'language': 'Dart',
        'version': Platform.version,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- Endpoint de Versión del Servidor Web ---
  app.get(endpointDictionary['SERVER_VERSION_ENDPOINT']!.path,
      (Request request) async {
    final version = await getShelfVersion();

    return Response.ok(
      jsonEncode({
        'server': 'Dart Shelf Backend',
        'version': version,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- Endpoint de Versión del Aplicativo ---
  app.get(endpointDictionary['APP_VERSION_ENDPOINT']!.path,
      (Request request) async {
    return Response.ok(
      jsonEncode({
        'appVersion': '1.0.0',
      }),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Configuración del Servidor con Tubería de Middleware
  // ─────────────────────────────────────────────────────────────────────────────
  final handler = const Pipeline()
      .addMiddleware(addCorsHeaders())
      .addMiddleware(logRequestsToJson())
      .addMiddleware(createErrorHandlingMiddleware())
      .addHandler(app.call);

  final portStr = Platform.environment['PORT'] ?? '8080';
  final port = int.parse(portStr);

  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  print('Servidor escuchando en el puerto ${server.port}');
}
