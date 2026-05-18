import 'package:sqflite/sqflite.dart' hide Batch, Transaction;
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/medicine.dart';
import '../models/batch.dart';
import '../models/transaction.dart';
import '../models/transaction_detail.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_pharmacy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Category table
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    // Create Medicine table
    await db.execute('''
      CREATE TABLE medicines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        price REAL NOT NULL,
        stock_total INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Create Batch table
    await db.execute('''
      CREATE TABLE batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_id INTEGER NOT NULL,
        batch_number TEXT NOT NULL,
        stock INTEGER NOT NULL,
        expired_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
      )
    ''');

    // Create Transaction table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        payment REAL NOT NULL,
        change REAL NOT NULL
      )
    ''');

    // Create Transaction Detail table
    await db.execute('''
      CREATE TABLE transaction_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        medicine_id INTEGER NOT NULL,
        batch_id INTEGER NOT NULL,
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE,
        FOREIGN KEY (medicine_id) REFERENCES medicines (id),
        FOREIGN KEY (batch_id) REFERENCES batches (id)
      )
    ''');

    // Insert default categories
    await db.insert('categories', {'name': 'Obat Bebas'});
    await db.insert('categories', {'name': 'Obat Resep'});
    await db.insert('categories', {'name': 'Vitamin'});
    await db.insert('categories', {'name': 'Alat Kesehatan'});
  }

  Future<void> initDatabase() async {
    await database;
  }

  // Category CRUD
  Future<List<Category>> getCategories() async {
    final db = await database;
    final result = await db.query('categories');
    return result.map((json) => Category.fromMap(json)).toList();
  }

  // Medicine CRUD
  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine.toMap());
  }

  Future<List<Medicine>> getMedicines() async {
    final db = await database;
    final result = await db.query('medicines');
    return result.map((json) => Medicine.fromMap(json)).toList();
  }

  Future<Medicine?> getMedicine(int id) async {
    final db = await database;
    final result =
        await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return Medicine.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return await db.update('medicines', medicine.toMap(),
        where: 'id = ?', whereArgs: [medicine.id]);
  }

  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // Batch CRUD
  Future<int> insertBatch(Batch batch) async {
    final db = await database;
    return await db.insert('batches', batch.toMap());
  }

  Future<List<Batch>> getBatchesByMedicine(int medicineId) async {
    final db = await database;
    final result = await db
        .query('batches', where: 'medicine_id = ?', whereArgs: [medicineId]);
    return result.map((json) => Batch.fromMap(json)).toList();
  }

  Future<List<Batch>> getAllBatches() async {
    final db = await database;
    final result = await db.query('batches');
    return result.map((json) => Batch.fromMap(json)).toList();
  }

  Future<List<Batch>> getAvailableBatches(int medicineId) async {
    final db = await database;
    final result = await db.query('batches',
        where: 'medicine_id = ? AND stock > 0', whereArgs: [medicineId]);
    return result.map((json) => Batch.fromMap(json)).toList();
  }

  Future<int> updateBatchStock(int batchId, int newStock) async {
    final db = await database;
    return await db.update('batches', {'stock': newStock},
        where: 'id = ?', whereArgs: [batchId]);
  }

  // Transaction CRUD
  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'date DESC');
    return result.map((json) => Transaction.fromMap(json)).toList();
  }

  Future<int> insertTransactionDetail(TransactionDetail detail) async {
    final db = await database;
    return await db.insert('transaction_details', detail.toMap());
  }

  Future<List<TransactionDetail>> getTransactionDetails(
      int transactionId) async {
    final db = await database;
    final result = await db.query('transaction_details',
        where: 'transaction_id = ?', whereArgs: [transactionId]);
    return result.map((json) => TransactionDetail.fromMap(json)).toList();
  }

  // Update medicine total stock
  Future<void> updateMedicineStock(int medicineId) async {
    final db = await database;
    final batches = await getBatchesByMedicine(medicineId);
    final totalStock = batches.fold<int>(0, (sum, batch) => sum + batch.stock);
    await db.update('medicines', {'stock_total': totalStock},
        where: 'id = ?', whereArgs: [medicineId]);
  }

  // Get expired batches
  Future<List<Batch>> getExpiredBatches() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result =
        await db.query('batches', where: 'expired_date < ?', whereArgs: [now]);
    return result.map((json) => Batch.fromMap(json)).toList();
  }

  Future<List<Batch>> getNearExpiredBatches() async {
    final db = await database;
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30)).toIso8601String();
    final nowStr = now.toIso8601String();
    final result = await db.query('batches',
        where: 'expired_date BETWEEN ? AND ?',
        whereArgs: [nowStr, thirtyDaysLater]);
    return result.map((json) => Batch.fromMap(json)).toList();
  }

  Future<List<Map<String, dynamic>>> getLowStockMedicines() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT m.*, c.name as category_name 
      FROM medicines m
      JOIN categories c ON m.category_id = c.id
      WHERE m.stock_total < 10
    ''');
    return result;
  }
}
