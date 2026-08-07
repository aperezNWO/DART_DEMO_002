// lib/access_log_dao.dart
import 'package:mysql1/mysql1.dart';
import 'entity.dart';

class AccessLogDAO {
  // Configuration for MySQL connection.
  // TODO: Ensure these credentials and host are correct for your target database.
  final ConnectionSettings _settings = ConnectionSettings(
    host: 'webapiangulardemo.mssql.somee.com',
    port: 3306, // MySQL default port
    user: 'aperezNWO_SQLLogin_1',
    password: 'aperezNWO_SQLLogin_1',
    db: 'webapiangulardemo',
  );

  Future<List<AccessLog>> getAllLogs() async {
    // NOTE: The original SQL syntax was T-SQL (for SQL Server).
    // It has been updated below to standard MySQL syntax (e.g., LIMIT 100 instead of TOP 100).
    const sql = '''
      SELECT
             AL.ID_column     AS id_column
           , AL.PageName      AS pageName
           , AL.AccessDate    AS accessDate
           , AL.IpValue       AS ipValue
      FROM
          accessLogs AL
      WHERE
          AL.LogType = 1
      AND
          (AL.PAGENAME LIKE '%DEMO%'
      AND
          AL.PAGENAME LIKE '%PAGE%')
      AND
          AL.PAGENAME NOT LIKE '%ERROR%'
      AND
          AL.PAGENAME  NOT LIKE '%PAGE_DEMO_INDEX%'
      AND
          UPPER(AL.PAGENAME) NOT LIKE '%CACHE%'
      AND
          AL.IPVALUE <> '::1'
      ORDER BY
          AL.ID_column DESC
      LIMIT 100;
    ''';

    MySqlConnection? conn;
    try {
      conn = await MySqlConnection.connect(_settings);
      
      // FIX: Use query() instead of execute() for SELECT statements in mysql1.
      // execute() is typically used for INSERT/UPDATE/DELETE without results.
      var results = await conn.query(sql);

      List<AccessLog> accessLogs = [];
      
      // Iterate over the result rows and map them to the AccessLog entity.
      for (var row in results) {
        // Assumes AccessLog.fromRow handles the field name mapping correctly.
        accessLogs.add(AccessLog.fromRow(row));
      }
      
      return accessLogs;
    } catch (e) {
      // Log the error for server-side debugging.
      print('Error in AccessLogDAO.getAllLogs: $e');
      // Rethrow the exception so the calling endpoint can catch it and send an HTTP 500.
      rethrow;
    } finally {
      // Ensure the connection is closed to free resources, even if an error occurs.
      await conn?.close();
    }
  }
}