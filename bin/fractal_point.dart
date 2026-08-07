class FractalPoint {
  final double x;
  final double y;
  final int intensity;

  const FractalPoint(this.x, this.y, this.intensity);

  // Required for server.dart to serialize data for Angular
  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'intensity': intensity,
      };
}