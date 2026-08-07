import 'dart:math';
import 'fractal_point.dart';
import 'fractal_bounds.dart';
import 'fractal_kind.dart';

export 'fractal_point.dart';
export 'fractal_bounds.dart';
export 'fractal_kind.dart';

class FractalEngine {
  static const int CANVAS_WIDTH = 800;
  static const int CANVAS_HEIGHT = 600;

  List<FractalPoint> getFractal(
    FractalKind fractalKind,
    Bounds bounds,
    int maxIterations,
  ) {
    switch (fractalKind) {
      case FractalKind.mandelbrot:
        return generateMandelbrot(bounds, maxIterations);
      case FractalKind.julia:
        return generateJulia(bounds, maxIterations);
      case FractalKind.leaf:
        return generateLeaf();
    }
  }

  static int _encodeIntensity(int iter, int maxIterations) =>
      (iter == maxIterations) ? 0 : (iter * 255 ~/ maxIterations);

  // --- Mandelbrot ---
  static List<FractalPoint> generateMandelbrot(Bounds bounds, int maxIterations) {
    final points = <FractalPoint>[];
    final xRange = bounds.xMax - bounds.xMin;
    final yRange = bounds.yMax - bounds.yMin;

    for (int screenY = 0; screenY < CANVAS_HEIGHT; screenY++) {
      for (int screenX = 0; screenX < CANVAS_WIDTH; screenX++) {
        final cRe = bounds.xMin + (screenX * xRange / CANVAS_WIDTH);
        final cIm = bounds.yMin + (screenY * yRange / CANVAS_HEIGHT);
        double zRe = 0.0, zIm = 0.0;
        int iter = 0;
        while (zRe * zRe + zIm * zIm <= 4.0 && iter < maxIterations) {
          final nextRe = zRe * zRe - zIm * zIm + cRe;
          final nextIm = 2.0 * zRe * zIm + cIm;
          zRe = nextRe;
          zIm = nextIm;
          iter++;
        }
        points.add(FractalPoint(screenX.toDouble(), screenY.toDouble(), _encodeIntensity(iter, maxIterations)));
      }
    }
    return points;
  }

  // --- Julia ---
  static List<FractalPoint> generateJulia(Bounds bounds, int maxIterations) {
    final points = <FractalPoint>[];
    final xRange = bounds.xMax - bounds.xMin;
    final yRange = bounds.yMax - bounds.yMin;
    const cRe = -0.400;
    const cIm = 0.600;
    for (int screenY = 0; screenY < CANVAS_HEIGHT; screenY++) {
      for (int screenX = 0; screenX < CANVAS_WIDTH; screenX++) {
        double zRe = bounds.xMin + (screenX * xRange / CANVAS_WIDTH);
        double zIm = bounds.yMin + (screenY * yRange / CANVAS_HEIGHT);
        int iter = 0;
        while (zRe * zRe + zIm * zIm <= 4.0 && iter < maxIterations) {
          final nextRe = zRe * zRe - zIm * zIm + cRe;
          final nextIm = 2.0 * zRe * zIm + cIm;
          zRe = nextRe;
          zIm = nextIm;
          iter++;
        }
        points.add(FractalPoint(screenX.toDouble(), screenY.toDouble(), _encodeIntensity(iter, maxIterations)));
      }
    }
    return points;
  }

  // --- Leaf ---
  static List<FractalPoint> generateLeaf() {
    final points = <FractalPoint>[];
    final pixelGrid = List.generate(CANVAS_WIDTH, (_) => List.filled(CANVAS_HEIGHT, 0));
    var x = 0.0, y = 0.0;
    final rand = Random();
    for (int i = 0; i < 150000; i++) {
      double nextX, nextY;
      int r = rand.nextInt(100);
      if (r < 1) { nextX = 0.0; nextY = 0.16 * y; }
      else if (r < 86) { nextX = 0.85 * x + 0.04 * y; nextY = -0.04 * x + 0.85 * y + 1.6; }
      else if (r < 93) { nextX = 0.20 * x - 0.26 * y; nextY = 0.23 * x + 0.22 * y + 1.6; }
      else { nextX = -0.15 * x + 0.28 * y; nextY = 0.26 * x + 0.24 * y + 0.44; }
      x = nextX; y = nextY;
      int screenX = ((x + 2.182) * (CANVAS_WIDTH - 1) / (2.655 + 2.182)).round();
      int screenY = ((9.96 - y) * (CANVAS_HEIGHT - 1) / 9.96).round();
      if (screenX >= 0 && screenX < CANVAS_WIDTH && screenY >= 0 && screenY < CANVAS_HEIGHT) {
        pixelGrid[screenX][screenY] = 200;
      }
    }
    for (int px = 0; px < CANVAS_WIDTH; px++) {
      for (int py = 0; py < CANVAS_HEIGHT; py++) {
        if (pixelGrid[px][py] > 0) {
          points.add(FractalPoint(px.toDouble(), py.toDouble(), pixelGrid[px][py]));
        }
      }
    }
    return points;
  }
}