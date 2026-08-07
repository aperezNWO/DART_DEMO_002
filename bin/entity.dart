// lib/entity.dart

class AccessLog {
  final int idColumn;
  final String? pageName;
  final String? accessDate;
  final String? ipValue;

  AccessLog({
    required this.idColumn,
    this.pageName,
    this.accessDate,
    this.ipValue,
  });

  // Fábrica para crear el objeto desde una fila de MySQL
  factory AccessLog.fromRow(var row) {
    return AccessLog(
      idColumn: row['ID_column'],
      pageName: row['PageName'],
      accessDate: row['AccessDate']?.toString(), // Convierte DateTime a String si es necesario
      ipValue: row['IpValue'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id_column': idColumn,
        'pageName': pageName,
        'accessDate': accessDate,
        'ipValue': ipValue,
      };
}

class PersonaTable {
  final int idColumn;
  final String? ciudad;
  final String? nombreCompleto;

  PersonaTable({
    required this.idColumn,
    this.ciudad,
    this.nombreCompleto,
  });

  factory PersonaTable.fromRow(var row) {
    return PersonaTable(
      idColumn: row['Id_Column'],
      ciudad: row['Ciudad'],
      nombreCompleto: row['NombreCompleto'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id_column': idColumn,
        'ciudad': ciudad,
        'nombreCompleto': nombreCompleto,
      };
}