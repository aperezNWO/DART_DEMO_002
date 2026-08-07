enum FractalKind {
  mandelbrot(1),
  julia(2),
  leaf(3);

  final int code;
  const FractalKind(this.code);

  static FractalKind fromValue(int value) {
    return FractalKind.values.firstWhere(
      (kind) => kind.code == value,
      orElse: () => throw ArgumentError("Tipo de fractal inválido: $value"),
    );
  }
}