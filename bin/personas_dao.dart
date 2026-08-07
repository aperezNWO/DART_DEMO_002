// lib/personas_dao.dart
import 'package:mysql1/mysql1.dart';
import 'entity.dart';

class PersonasDAO {
  // Configuration for MySQL connection
  // TODO: Replace with your actual database credentials
  final ConnectionSettings _settings = ConnectionSettings(
    host: 'webapiangulardemo.mssql.somee.com', // Host address
    port: 3306,                              // MySQL default port
    user: 'aperezNWO_SQLLogin_1',            // Username
    password: 'aperezNWO_SQLLogin_1',        // Password
    db: 'webapiangulardemo',                 // Database name
  );

  Future<List<PersonaTable>> getAllPersons() async {
    const sql = '''
      SELECT Id_Column, Ciudad, NombreCompleto
      FROM Persona
      ORDER BY Id_Column ASC
    ''';

    MySqlConnection? conn;
    try {
      conn = await MySqlConnection.connect(_settings);
      
      // FIX: Use query() instead of execute() for SELECT statements in mysql1
      var results = await conn.query(sql);

      List<PersonaTable> personas = [];
      
      // Iterate over the rows and map them to the Entity model
      for (var row in results) {
        personas.add(PersonaTable.fromRow(row));
      }
      
      return personas;
    } catch (e) {
      // Log the error server-side
      print('Error in PersonasDAO.getAllPersons: $e');
      // Rethrow to let the calling endpoint handle the error response
      rethrow;
    } finally {
      // Ensure connection is closed even if an error occurs
      await conn?.close();
    }
  }
}