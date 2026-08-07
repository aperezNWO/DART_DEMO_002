import 'dart:math';

class AlgorithmManager {
  // ─────────────────────────────────────────────────────────────────────────
  // ENTRY POINT
  // ─────────────────────────────────────────────────────────────────────────

  static String generateRandomPoints(
      int vertexSize, int sampleSizeRaw, int sourcePoint) {
    // REMOVE CO-ORDINATE EXTREMES (Assuming -2 logic from original intent)
    final sampleSize = sampleSizeRaw - 2;

    // Initialize VxV matrix with 0s
    List<List<int>> graph =
        List.generate(vertexSize, (_) => List.filled(vertexSize, 0));

    // Use DateTime.now().microsecondsSinceEpoch for a decent seed basis
    final timeSeed = DateTime.now().microsecondsSinceEpoch;
    final randX = Random(timeSeed ~/ 2);
    final randY = Random(timeSeed * 2);

    // Generate shuffled coordinates
    final vertexX = fisherYates(sampleSize, randX);
    final vertexY = fisherYates(sampleSize, randY);

    // Build coordinate strings: [x,y]
    List<String> vertexArray = [];
    for (int index = 0; index < vertexSize; index++) {
      final separator = (index < vertexSize - 1) ? "|" : "";
      vertexArray.add("[${vertexX[index]},${vertexY[index]}]$separator");
    }

    final vertexArrayString = vertexArray.join("");

    const separator2 = "■";
    // Note: generateRandomMatrix modifies 'graph' in place
    final vertexMatrix = generateRandomMatrix(vertexArray, graph, vertexSize);
    final vertexList =
        dijkstra(vertexArray, graph, vertexSize, sampleSize, sourcePoint);

    // Format output string: replace tabs and commas
    final sortedListEncoded =
        vertexList.replaceAll(",", "<br/>").replaceAll("\t", "&nbsp;");

    return "$vertexArrayString$separator2$vertexMatrix$separator2$sortedListEncoded";
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RANDOM ADJACENCY MATRIX
  // ─────────────────────────────────────────────────────────────────────────

  static String generateRandomMatrix(
      List<String> vertexString, List<List<int>> graph, int vertexSize) {
    // Diagonal = 0 (already initialized, but good to ensure)
    for (int index = 0; index < vertexSize; index++) {
      graph[index][index] = 0;
    }

    final rnd = Random(DateTime.now().millisecondsSinceEpoch % 1000);

    // Assign random edges (upper triangle, mirrored to lower)
    for (int indexX = 0; indexX < vertexSize; indexX++) {
      for (int indexY = (indexX + 1); indexY < vertexSize; indexY++) {
        // rnd.nextInt(2) gives 0 or 1
        var randomValue = rnd.nextInt(2).toDouble();
        if (randomValue == 1.0) {
          randomValue = getHipotemuza(vertexString, indexX, indexY);
        }
        int valInt = randomValue.toInt();
        graph[indexX][indexY] = valInt;
        graph[indexY][indexX] = valInt;
      }
    }

    // Guarantee connectivity — if a vertex has no edges at all, connect
    // its last zero-neighbour with the Euclidean distance weight
    for (int indexX = 0; indexX < vertexSize; indexX++) {
      var zeroCount = 0;
      for (int indexY = 0; indexY < vertexSize; indexY++) {
        if (indexX != indexY && graph[indexX][indexY] == 0) {
          zeroCount++;
          if (zeroCount == vertexSize - 1) {
            final hipotemuza = getHipotemuza(vertexString, indexX, indexY).toInt();
            graph[indexX][indexY] = hipotemuza;
            graph[indexY][indexX] = hipotemuza;
          }
        }
      }
    }

    // Serialise matrix to string: {a,b,c}|{d,e,f}|…
    StringBuffer sb = StringBuffer();
    for (int indexX = 0; indexX < vertexSize; indexX++) {
      final separator1 = (indexX < vertexSize - 1) ? "|" : "";
      
      // Generate comma-separated values for the row
      String rowValues = "";
      for (int indexY = 0; indexY < vertexSize; indexY++) {
        rowValues += "${graph[indexX][indexY]}";
        if (indexY < vertexSize - 1) rowValues += ",";
      }
      
      sb.write("{$rowValues}$separator1");
    }
    return sb.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EUCLIDEAN DISTANCE (hypotenuse)
  // ─────────────────────────────────────────────────────────────────────────

  static double getHipotemuza(
      List<String> vertexString, int indexX, int indexY) {
    // RegEx in Dart: use double backslash for escape
    final coordSource =
        vertexString[indexY].replaceAll(RegExp(r'[|\[\]]'), "").split(",");
    final coordDest =
        vertexString[indexX].replaceAll(RegExp(r'[|\[\]]'), "").split(",");

    final sourceX = double.parse(coordSource[0]);
    final sourceY = double.parse(coordSource[1]);
    final destX = double.parse(coordDest[0]);
    final destY = double.parse(coordDest[1]);

    // pythagorean(dx, dy)
    return pythagorean((destX - sourceX).abs(), (destY - sourceY).abs());
  }

  static double pythagorean(double coordX, double coordY) =>
      sqrt(pow(coordX, 2) + pow(coordY, 2));

  // ─────────────────────────────────────────────────────────────────────────
  // FISHER-YATES SHUFFLE
  // ─────────────────────────────────────────────────────────────────────────

  static List<int> fisherYates(int count, Random rand) {
    // [1, 2, … count]
    List<int> deck = List.generate(count, (i) => i + 1);

    // First pass (forward)
    for (int i = 0; i <= count - 2; i++) {
      final j = rand.nextInt(count - i);
      if (j > 0) {
        final tmp = deck[i];
        deck[i] = deck[i + j];
        deck[i + j] = tmp;
      }
    }

    // Second pass (backward)
    for (int i = count - 1; i >= 1; i--) {
      final j = rand.nextInt(i + 1);
      if (j != i) {
        final tmp = deck[i];
        deck[i] = deck[j];
        deck[j] = tmp;
      }
    }

    return deck;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIJKSTRA RUNNER
  // ─────────────────────────────────────────────────────────────────────────

  static String dijkstra(
      List<String> vertex,
      List<List<int>> graph,
      int vertexSize,
      int sampleSize,
      int sourcePoint) {
    
    // Instantiating the top-level private class
    final gfg = _Gfg(); 
    gfg.dijkstra(graph, sourcePoint, vertexSize);

    StringBuffer sb = StringBuffer();
    for (int index = 0; index < gfg.dist.length; index++) {
      // Clamp unreachable nodes (2147483647 in Java/Kotlin) to 0
      if (gfg.dist[index] >= 2147483647) {
        gfg.dist[index] = 0;
      }

      final separator = (index < gfg.dist.length - 1) ? "," : "";

      // Dart doesn't have String.format(). Using interpolation.
      // Ensures 2-digit zero padding for index and distance
      sb.write(
        "${index.toString().padLeft(2, '0')}"
        "<${vertex[index].replaceAll(",", ";").replaceAll("|", "")}>"
        "-${gfg.dist[index].toString().padLeft(2, '0')}-"
        "${gfg.path[index].replaceAll(",", ";")}"
        "$separator"
      );
    }
    return sb.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────
// GFG — Dijkstra core (MOVED TO TOP-LEVEL AND SYNTAX FIXED)
// ─────────────────────────────────────────────────────────────────────────

// Renamed with _ prefix to denote it is library-private
class _Gfg {
  List<int> dist = [];
  List<String> path = [];

  void dijkstra(List<List<int>> graph, int src, int vertexSize) {
    const javaMaxInt = 2147483647; 
    
    dist = List.generate(vertexSize, (_) => javaMaxInt);
    path = List.generate(vertexSize, (_) => "");

    List<bool> visited = List.filled(vertexSize, false);
    List<int> previous = List.filled(vertexSize, -1);

    dist[src] = 0;

    for (int count = 0; count < vertexSize; count++) {
      // Pick the unvisited vertex with the smallest known distance
      int? u;
      int minD = javaMaxInt;

      for (int i = 0; i < vertexSize; i++) {
        if (!visited[i] && dist[i] <= minD) {
          minD = dist[i];
          u = i;
        }
      }

      if (u == null) break; // No more reachable nodes

      visited[u] = true;

      // Relax neighbours
      for (int v = 0; v < vertexSize; v++) {
        final weight = graph[u!][v];
        // weight > 0 implies edge exists
        if (!visited[v] && weight > 0 && dist[u!] != javaMaxInt) {
          final newDist = dist[u!] + weight;
          if (newDist < dist[v]) {
            dist[v] = newDist;
            previous[v] = u!;
          }
        }
      }
    }

    // Reconstruct path strings
    for (int v = 0; v < vertexSize; v++) {
      path[v] = buildPathString(previous, src, v);
    }
  }

  String buildPathString(List<int> previous, int src, int dest) {
    if (dest == src) return "";

    List<int> steps = [];
    int? cur = dest;
    while (cur != -1 && cur != null) {
      steps.add(cur);
      cur = previous[cur];
    }
    
    // FIX: Dart List doesn't have in-place .reverse(). Use .reversed getter.
    steps = steps.reversed.toList(); 

    if (steps.isEmpty || steps.first != src) return ""; // unreachable

    StringBuffer sb = StringBuffer();
    for (int i = 0; i < steps.length - 1; i++) {
      sb.write("[${steps[i]};${steps[i + 1]}]≡");
    }
    return sb.toString();
  }
}