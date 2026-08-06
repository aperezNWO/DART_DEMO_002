import 'dart:io';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Server listening on port $port');

  await for (HttpRequest request in server) {
    switch (request.uri.path) {
      case '/':
      case '/zero':
        // Respuesta de 0 bytes: sin body, solo status + headers mínimos
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentLength = 0;
        await request.response.close();
        break;

      case '/health':
        request.response.statusCode = HttpStatus.ok;
        request.response.write('ok');
        await request.response.close();
        break;

      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }
}