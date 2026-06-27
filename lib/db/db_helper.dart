import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:aapni_dairy/models/customer.dart';
import 'package:aapni_dairy/models/milk_entry.dart';
import 'package:aapni_dairy/models/product.dart';
import 'package:aapni_dairy/constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Initialize database
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'milk_management.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute("PRAGMA foreign_keys = ON"); // Enable cascade delete
        await _ensureKhataProductSaleColumns(db);
      },
    );
  }

  Future<void> _ensureKhataProductSaleColumns(Database db) async {
    // Defensive migration: some existing installs may have an older schema
    // while the db version is already >= 6.
    final result = await db.rawQuery("PRAGMA table_info(khata_product_sale)");

    final existingColumns = <String>{};
    for (final row in result) {
      final name = row['name'];
      if (name is String) existingColumns.add(name);
    }

    Future<void> addColumnIfMissing(String columnName, String columnDef) async {
      if (existingColumns.contains(columnName)) return;
      await db.execute('ALTER TABLE khata_product_sale ADD COLUMN $columnDef');
    }

    await addColumnIfMissing(
      'product_id',
      'product_id INTEGER NOT NULL DEFAULT 0',
    );
    await addColumnIfMissing(
      'product_name',
      "product_name TEXT NOT NULL DEFAULT 'Unknown'",
    );
    await addColumnIfMissing(
      'product_rate',
      'product_rate REAL NOT NULL DEFAULT 0',
    );
    await addColumnIfMissing('quantity', 'quantity REAL NOT NULL DEFAULT 0');
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''

      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE milk_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        shift TEXT NOT NULL,
        quantity REAL NOT NULL,
        fat REAL NOT NULL,
        snf REAL DEFAULT 8.5,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        snf_katoti REAL DEFAULT 0.0,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        rate REAL NOT NULL
      )
    ''');

    // Khata tables should exist even on a brand-new DB.
    // Use IF NOT EXISTS for extra safety with partially created DBs.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS khata_you_got (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        amount REAL NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS khata_you_gave (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        amount REAL NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    // Base table (v5) columns. v6 adds product detail columns via ALTER.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS khata_product_sale (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        amount REAL NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
      )
    ''');

    if (version >= 2) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  // Upgrade database
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }

    // Add products table
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          rate REAL NOT NULL
        )
      ''');
    }

    // Khata tables (v5)
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS khata_you_got (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          amount REAL NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS khata_you_gave (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          amount REAL NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS khata_product_sale (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          amount REAL NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
        )
      ''');
    }

    // Khata product sale (v6): store product details for ledger UI
    if (oldVersion < 6) {
      // If table already exists from older versions, add columns.
      await db.execute('''
        ALTER TABLE khata_product_sale ADD COLUMN product_id INTEGER NOT NULL DEFAULT 0;
      ''');

      await db.execute('''
        ALTER TABLE khata_product_sale ADD COLUMN product_name TEXT NOT NULL DEFAULT 'Unknown';
      ''');

      await db.execute('''
        ALTER TABLE khata_product_sale ADD COLUMN product_rate REAL NOT NULL DEFAULT 0;
      ''');

      await db.execute('''
        ALTER TABLE khata_product_sale ADD COLUMN quantity REAL NOT NULL DEFAULT 0;
      ''');
    }
  }

  // CUSTOMER OPERATIONS
  Future<int> insertCustomer(Customer customer) async {
    final db = await database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers() async {
    final db = await database;
    final result = await db.query('customers', orderBy: 'id ASC');
    return result.map((map) => Customer.fromMap(map)).toList();
  }

  Future<int> updateCustomer(int id, String newName) async {
    final db = await database;
    return await db.update(
      'customers',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<String?> getCustomerNameById(int id) async {
    final db = await database;
    final result = await db.query(
      'customers',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return result.first['name'] as String;
    }
    return null;
  }

  // MILK ENTRY OPERATIONS
  Future<int> insertMilkEntry(MilkEntry entry) async {
    final db = await database;

    // New logic: snfKatoti is per-liter ₹ deduction, so it reduces rate directly.
    double rate =
        (Constants.rateConstantA * entry.fat) +
        Constants.rateConstantB -
        entry.snfKatoti;
    double amount = rate * entry.quantity;

    final data = entry.toMap()
      ..['rate'] = rate
      ..['amount'] = amount;

    // IMPORTANT:
    // Customer ledger detail screen me milk entries ka sign handle hota hai
    // directly (milk => running -= amount). So khata_you_gave me automatic insert
    // nahi karna chahiye, warna “YOU GAVE” duplicate/auto add ho jata hai.

    return await db.transaction<int>((txn) async {
      final milkId = await txn.insert('milk_entries', data);
      return milkId;
    });
  }

  Future<List<MilkEntry>> getAllMilkEntries() async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      orderBy: 'date DESC, shift ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  Future<List<MilkEntry>> getMilkEntriesByDate(String date) async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'shift ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  /// Selected date ke liye milk entries (same-day) customer name/id ke saath.
  /// UI me: Name + Code, Quantity, Fat, Rate display ke liye.
  Future<List<Map<String, dynamic>>> getMilkEntriesWithCustomerByDate(
    String date,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT
        me.id as milk_entry_id,
        me.customer_id,
        c.name as customer_name,
        me.quantity,
        me.fat,
        me.rate,
        me.shift,
        me.date,
        me.amount
      FROM milk_entries me
      INNER JOIN customers c ON c.id = me.customer_id
      WHERE me.date = ?
      ORDER BY me.shift ASC, me.id ASC
      ''',
      [date],
    );
  }

  Future<List<MilkEntry>> getMilkEntriesByCustomer(int customerId) async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  Future<List<MilkEntry>> getMilkEntriesByCustomerAndRange(
    int customerId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      where: 'customer_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [customerId, startDate, endDate],
      orderBy: 'date ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  Future<List<MilkEntry>> getMilkEntriesInRange(
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  Future<List<MilkEntry>> getMilkEntries({String? date}) async {
    final db = await database;
    List<Map<String, dynamic>> result;
    if (date != null) {
      result = await db.query(
        'milk_entries',
        where: 'date = ?',
        whereArgs: [date],
        orderBy: 'shift ASC',
      );
    } else {
      result = await db.query('milk_entries', orderBy: 'date DESC, shift ASC');
    }
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  Future<int> updateMilkEntry(MilkEntry entry) async {
    final db = await database;

    // New logic: snfKatoti is per-liter ₹ deduction, so it reduces rate directly.
    double rate =
        (Constants.rateConstantA * entry.fat) +
        Constants.rateConstantB -
        entry.snfKatoti;
    double amount = rate * entry.quantity;

    final data = entry.toMap()
      ..['rate'] = rate
      ..['amount'] = amount;

    return await db.transaction<int>((txn) async {
      // Update milk
      final milkUpdateId = await txn.update(
        'milk_entries',
        data,
        where: 'id = ?',
        whereArgs: [entry.id],
      );

      return milkUpdateId;
    });
  }

  Future<int> deleteMilkEntry(int id) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      // Find the milk entry first to delete related khata row
      final rows = await txn.query(
        'milk_entries',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        return 0;
      }

      final row = rows.first;
      final customerId = row['customer_id'] as int;
      final date = row['date'] as String;
      final shift = row['shift'] as String;

      await txn.delete(
        'khata_you_gave',
        where: 'customer_id = ? AND date = ? AND note = ?',
        whereArgs: [customerId, date, 'Milk Entry ($shift)'],
      );

      return await txn.delete('milk_entries', where: 'id = ?', whereArgs: [id]);
    });
  }

  // Get all customers who have milk entries for a specific date
  Future<List<Map<String, dynamic>>> getCustomersWithEntriesForDate(
    String date,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT c.id, c.name
      FROM customers c
      INNER JOIN milk_entries me ON c.id = me.customer_id
      WHERE me.date = ?
      ORDER BY c.id ASC
    ''',
      [date],
    );
    return result;
  }

  // Get milk entries for a specific customer on a specific date
  Future<List<MilkEntry>> getMilkEntriesByCustomerAndDate(
    int customerId,
    String date,
  ) async {
    final db = await database;
    final result = await db.query(
      'milk_entries',
      where: 'customer_id = ? AND date = ?',
      whereArgs: [customerId, date],
      orderBy: 'shift ASC',
    );
    return result.map((map) => MilkEntry.fromMap(map)).toList();
  }

  // SETTINGS OPERATIONS
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  // DAIRY DETAILS OPERATIONS
  Future<void> saveDairyDetails({
    required String dairyName,
    required String ownerName,
    required String mobileNumber,
  }) async {
    await saveSetting('dairyName', dairyName);
    await saveSetting('ownerName', ownerName);
    await saveSetting('mobileNumber', mobileNumber);
  }

  Future<Map<String, String?>> getDairyDetails() async {
    final dairyName = await getSetting('dairyName');
    final ownerName = await getSetting('ownerName');
    final mobileNumber = await getSetting('mobileNumber');

    return {
      'dairyName': dairyName,
      'ownerName': ownerName,
      'mobileNumber': mobileNumber,
    };
  }

  // Update customer name (overloaded method)
  Future<int> updateCustomerByObject(Customer customer) async {
    final db = await database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  // Delete customer (overloaded method)
  Future<int> deleteCustomerAndResetIds(int id) async {
    final db = await database;
    int result = await db.delete('customers', where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      await resetCustomerIds();
    }
    return result;
  }

  // Reset customer IDs to sequential after delete
  Future<void> resetCustomerIds() async {
    final db = await database;

    await db.execute("PRAGMA foreign_keys = OFF");

    await db.execute('''
      CREATE TABLE customers_temp (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO customers_temp (name)
      SELECT name FROM customers ORDER BY id ASC
    ''');

    await db.execute('''
      UPDATE milk_entries
      SET customer_id = (
        SELECT ct.id
        FROM customers_temp ct
        WHERE ct.name = (SELECT c.name FROM customers c WHERE c.id = milk_entries.customer_id)
      )
    ''');

    await db.execute('DROP TABLE customers');
    await db.execute('ALTER TABLE customers_temp RENAME TO customers');

    await db.execute("PRAGMA foreign_keys = ON");
  }

  // BACKUP & RESTORE
  Future<Map<String, dynamic>> getAllDataForBackup() async {
    final db = await database;
    return {
      'customers': await db.query('customers'),
      'milk_entries': await db.query('milk_entries'),
      'products': await db.query('products'),
      'khata_you_got': await db.query('khata_you_got'),
      'khata_you_gave': await db.query('khata_you_gave'),
      'khata_product_sale': await db.query('khata_product_sale'),
      'settings': await db.query('settings'),
      'backup_date': DateTime.now().toIso8601String(),
    };
  }

  Future<void> restoreFromBackup(Map<String, dynamic> backupData) async {
    final db = await database;
    await db.transaction((txn) async {
      // If user ke existing DB me tables missing hain, DELETE fail ho jata hai.
      // So pehle table existence check karte hain.
      Future<bool> _tableExists(String table) async {
        final result = await txn.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        return result.isNotEmpty;
      }

      if (await _tableExists('customers')) await txn.delete('customers');
      if (await _tableExists('milk_entries')) await txn.delete('milk_entries');
      if (await _tableExists('products')) await txn.delete('products');
      if (await _tableExists('khata_you_got'))
        await txn.delete('khata_you_got');
      if (await _tableExists('khata_you_gave'))
        await txn.delete('khata_you_gave');
      if (await _tableExists('khata_product_sale'))
        await txn.delete('khata_product_sale');
      if (await _tableExists('settings')) await txn.delete('settings');

      if (backupData['customers'] != null) {
        for (var row in backupData['customers']) {
          await txn.insert('customers', row);
        }
      }

      if (backupData['milk_entries'] != null) {
        for (var row in backupData['milk_entries']) {
          await txn.insert('milk_entries', row);
        }
      }

      if (backupData['products'] != null) {
        for (var row in backupData['products']) {
          await txn.insert('products', row);
        }
      }

      if (backupData['khata_you_got'] != null) {
        for (var row in backupData['khata_you_got']) {
          await txn.insert('khata_you_got', row);
        }
      }

      if (backupData['khata_you_gave'] != null) {
        for (var row in backupData['khata_you_gave']) {
          await txn.insert('khata_you_gave', row);
        }
      }

      if (backupData['khata_product_sale'] != null) {
        for (var row in backupData['khata_product_sale']) {
          await txn.insert('khata_product_sale', row);
        }
      }

      if (backupData['settings'] != null) {
        for (var row in backupData['settings']) {
          await txn.insert('settings', row);
        }
      }
    });
  }

  // ================= KHATA LEDGER OPERATIONS =================
  Future<int> insertYouGot({
    required int customerId,
    required String date,
    String? note,
    required double amount,
  }) async {
    final db = await database;
    return await db.insert('khata_you_got', {
      'customer_id': customerId,
      'date': date,
      'note': note,
      'amount': amount,
    });
  }

  Future<List<Map<String, dynamic>>> getYouGotEntriesByCustomer(
    int customerId,
  ) async {
    final db = await database;
    return await db.query(
      'khata_you_got',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );
  }

  Future<int> updateYouGotEntry({
    required int entryId,
    required double amount,
    String? note,
    required String date,
  }) async {
    final db = await database;
    return await db.update(
      'khata_you_got',
      {'amount': amount, 'date': date, if (note != null) 'note': note},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> deleteYouGotEntry(int entryId) async {
    final db = await database;
    return await db.delete(
      'khata_you_got',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> insertYouGave({
    required int customerId,
    required String date,
    String? note,
    required double amount,
  }) async {
    final db = await database;
    return await db.insert('khata_you_gave', {
      'customer_id': customerId,
      'date': date,
      'note': note,
      'amount': amount,
    });
  }

  Future<List<Map<String, dynamic>>> getYouGaveEntriesByCustomer(
    int customerId,
  ) async {
    final db = await database;
    return await db.query(
      'khata_you_gave',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );
  }

  Future<int> updateYouGaveEntry({
    required int entryId,
    required double amount,
    String? note,
    required String date,
  }) async {
    final db = await database;
    return await db.update(
      'khata_you_gave',
      {'amount': amount, 'date': date, if (note != null) 'note': note},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> deleteYouGaveEntry(int entryId) async {
    final db = await database;
    return await db.delete(
      'khata_you_gave',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> insertProductSale({
    required int customerId,
    required String date,
    String? note,
    required double amount,
  }) async {
    // Backward compatible insert (older calls will keep Unknown/0 values)
    return await insertProductSaleDetailed(
      customerId: customerId,
      date: date,
      note: note,
      productId: 0,
      productName: 'Unknown',
      productRate: 0,
      quantity: 0,
      amount: amount,
    );
  }

  Future<int> insertProductSaleDetailed({
    required int customerId,
    required String date,
    String? note,
    required int productId,
    required String productName,
    required double productRate,
    required double quantity,
    required double amount,
  }) async {
    final db = await database;
    return await db.insert('khata_product_sale', {
      'customer_id': customerId,
      'date': date,
      'note': note,
      'amount': amount,
      'product_id': productId,
      'product_name': productName,
      'product_rate': productRate,
      'quantity': quantity,
    });
  }

  /// Fetch product sale entries with product details for a customer (chronological)
  Future<List<Map<String, dynamic>>> getProductSaleEntriesByCustomer(
    int customerId,
  ) async {
    final db = await database;
    final result = await db.query(
      'khata_product_sale',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date ASC',
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getYouGotEntriesByCustomerAndRange(
    int customerId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'khata_you_got',
      where: 'customer_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [customerId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getYouGaveEntriesByCustomerAndRange(
    int customerId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'khata_you_gave',
      where: 'customer_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [customerId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getProductSaleEntriesByCustomerAndRange(
    int customerId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'khata_product_sale',
      where: 'customer_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [customerId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }

  Future<int> updateProductSaleDetailed({
    required int entryId,
    required int productId,
    required String productName,
    required double productRate,
    required double quantity,
    required double amount,
    String? note,
  }) async {
    final db = await database;
    return await db.update(
      'khata_product_sale',
      {
        'product_id': productId,
        'product_name': productName,
        'product_rate': productRate,
        'quantity': quantity,
        'amount': amount,
        if (note != null) 'note': note,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> deleteProductSale(int entryId) async {
    final db = await database;
    return await db.delete(
      'khata_product_sale',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  /// Aggregations for a customer (all time)
  Future<double> getMilkTotal(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    // Note: If you need "opening" (before some date), pass startDate=null
    // and endDate=null is not enough; instead query via the dedicated
    // getMilkTotalBeforeCustomerDate methods.

    final db = await database;

    List<dynamic> args = [customerId];
    String where = 'customer_id = ?';

    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.addAll([startDate, endDate]);
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM milk_entries WHERE $where',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getMilkTotalBeforeCustomerDate(
    int customerId,
    String startDate,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM milk_entries WHERE customer_id = ? AND date < ?',
      [customerId, startDate],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYouGotTotalBeforeCustomerDate(
    int customerId,
    String startDate,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM khata_you_got WHERE customer_id = ? AND date < ?',
      [customerId, startDate],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYouGaveTotalBeforeCustomerDate(
    int customerId,
    String startDate,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM khata_you_gave WHERE customer_id = ? AND date < ?',
      [customerId, startDate],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getProductSaleTotalBeforeCustomerDate(
    int customerId,
    String startDate,
  ) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM khata_product_sale WHERE customer_id = ? AND date < ?',
      [customerId, startDate],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getProductSaleTotal(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    List<dynamic> args = [customerId];
    String where = 'customer_id = ?';

    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.addAll([startDate, endDate]);
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM khata_product_sale WHERE $where',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYouGotTotal(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    List<dynamic> args = [customerId];
    String where = 'customer_id = ?';

    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.addAll([startDate, endDate]);
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM khata_you_got WHERE $where',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getYouGaveTotal(
    int customerId, {
    String? startDate,
    String? endDate,
  }) async {
    final db = await database;

    List<dynamic> args = [customerId];
    String where = 'customer_id = ?';

    if (startDate != null && endDate != null) {
      where += ' AND date BETWEEN ? AND ?';
      args.addAll([startDate, endDate]);
    }

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM khata_you_gave WHERE $where',
      args,
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getCustomersForKhataBook() async {
    final db = await database;

    // KhataBook me sabhi Registered customers dikhne chahiye.
    // (Milk entry / khata entries wale filter nahi hone chahiye.)
    return await db.rawQuery('''
      SELECT id, name
      FROM customers
      ORDER BY id ASC
    ''');
  }

  /// Final customer balance logic
  ///
  /// You Got:
  /// Customer paid money to user
  ///
  /// You Gave:
  /// User paid money to customer
  ///
  /// Product Sale:
  /// Customer has to pay user for products
  ///
  /// Milk entries are already inserted automatically
  /// inside khata_you_gave table,
  /// so milkTotal should NOT be added again.
  ///
  /// FINAL FORMULA:
  ///
  /// finalBalance =
  /// youGot - (youGave + productSale)
  ///
  Future<double> getFinalBalance(int customerId) async {
    // Keep this logic EXACTLY same as CustomerLedgerDetailScreen._finalBalance()
    // CustomerLedgerDetailScreen returns:
    //   milk + youGot - youGave - productSale
    final milkTotal = await getMilkTotal(customerId);
    final youGot = await getYouGotTotal(customerId);
    final youGave = await getYouGaveTotal(customerId);
    final productSale = await getProductSaleTotal(customerId);

    return milkTotal + youGot - youGave - productSale;
  }

  // ================= PRODUCTS OPERATIONS =================
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'id DESC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    if (product.id == null) {
      throw ArgumentError('Product.id is required for update');
    }
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }
}
