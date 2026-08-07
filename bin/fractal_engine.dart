import 'dart:math';

enum FractalKind {
  mandelbrot(1),
  julia(2),
  leaf(3);

  final int value;
  const FractalKind(this.value);

  static FractalKind fromValue(int value) {
    for (var kind in FractalKind.values) {
      if (kind.value == value) return kind;
    }
    throw ArgumentError('Tipo de fractal inválido: $value');
  }
}

class FractalPoint {
  final double x;
  final double y;
  final int intensity;

  const FractalPoint(this.x, this.y, this.intensity);

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'intensity': intensity,
      };
}

class Bounds {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  const Bounds(this.xMin, this.xMax, this.yMin, this.yMax);
}

class FractalEngine {
  static const int canvasWidth = 800;
  static const int canvasHeight = 600;
  static const int maxIterationsDefault = 500;

  static int _encodeIntensity(int iter, int maxIterations) {
    return (iter == maxIterations) ? 0 : (iter * 255 ~/ maxIterations);
  }

  List<FractalPoint> getFractal(
      FractalKind fractalKind, Bounds bounds, int maxIterations) {
    switch (fractalKind) {
      case FractalKind.mandelbrot:
        return generateMandelbrot(bounds, maxIterations);
      case FractalKind.julia:
        return generateJulia(bounds, maxIterations);
      case FractalKind.leaf:
        return generateLeaf();
    }
  }

  static List<FractalPoint> generateMandelbrot(Bounds bounds, int maxIterations) {
    List<FractalPoint> points = [];

    double xRange = bounds.xMax - bounds.xMin;
    double yRange = bounds.yMax - bounds.yMin;

    for (int screenY = 0; screenY < canvasHeight; screenY++) {
      for (int screenX = 0; screenX < canvasWidth; screenX++) {
        double cRe = bounds.xMin + (screenX * xRange / canvasWidth);
        double cIm = bounds.yMin + (screenY * yRange / canvasHeight);

        double zRe = 0.0, zIm = 0.0;
        int iter = 0;

        while (zRe * zRe + zIm * zIm <= 4.0 && iter < maxIterations) {
          double nextRe = zRe * zRe - zIm * zIm + cRe;
          double nextIm = 2.0 * zRe * zIm + cIm;
          zRe = nextRe;
          zIm = nextIm;
          iter++;
        }

        points.add(FractalPoint(
            screenX.toDouble(), screenY.toDouble(), _encodeIntensity(iter, maxIterations)));
      }
    }

    return points;
  }

  static List<FractalPoint> generateJulia(Bounds bounds, int maxIterations) {
    List<FractalPoint> points = [];

    double xRange = bounds.xMax - bounds.xMin;
    double yRange = bounds.yMax - bounds.yMin;

    double cRe = -0.400;
    double cIm = 0.600;

    for (int screenY = 0; screenY < canvasHeight; screenY++) {
      for (int screenX = 0; screenX < canvasWidth; screenX++) {
        double zRe = bounds.xMin + (screenX * xRange / canvasWidth);
        double zIm = bounds.yMin + (screenY * yRange / canvasHeight);

        int iter = 0;
        while (zRe * zRe + zIm * zIm <= 4.0 && iter < maxIterations) {
          double nextRe = zRe * zRe - zIm * zIm + cRe;
          double nextIm = 2.0 * zRe * zIm + cIm;
          zRe = nextRe;
          zIm = nextIm;
          iter++;
        }

        points.add(FractalPoint(
            screenX.toDouble(), screenY.toDouble(), _encodeIntensity(iter, maxIterations)));
      }
    }

    return points;
  }

  static List<FractalPoint> generateLeaf() {
    List<FractalPoint> points = [];
    // Using a flattened structure or lookup grid for Dart
    var pixelGrid = List.generate(canvasWidth, (_) => List.filled(canvasHeight, 0));

    double x = 0.0, y = 0.0;
    Random rand = Random();
    int totalPoints = 150_000;

    for (int i = 0; i < totalPoints; i++) {
      double nextX, nextY;
      int r = rand.nextInt(100);

      if (r < 1) {
        nextX = 0.0;
        nextY = 0.16 * y;
      } else if (r < 86) {
        nextX = 0.85 * x + 0.04 * y;
        nextY = -0.04 * x + 0.85 * y + 1.6;
      } else if (r < 93) {
        nextX = 0.20 * x - 0.26 * y;
        nextY = 0.23 * x + 0.22 * y + 1.6;
      } else {
        nextX = -0.15 * x + 0.28 * y;
        nextY = 0.26 * x + 0.24 * y + 0.44;
      }

      x = nextX;
      y = nextY;

      int screenX = ((x + 2.182) * (canvasWidth - 1) / (2.655 + 2.182)).round();
      int screenY = ((9.96 - y) * (canvasHeight - 1) / 9.96).round();

      if (screenX >= 0 && screenX < canvasWidth && screenY >= 0 && screenY < canvasHeight) {
        pixelGrid[screenX][screenY] = 200;
      }
    }

    for (int px = 0; px < canvasWidth; px++) {
      for (int py = 0; py < canvasHeight; py++) {
        if (pixelGrid[px][py] > 0) {
          points.add(FractalPoint(px.toDouble(), py.toDouble(), pixelGrid[px][py]));
        }
      }
    }

    return points;
  }
}