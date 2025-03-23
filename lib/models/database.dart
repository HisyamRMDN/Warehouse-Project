import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:warehouse_project/models/item_category.dart';

part 'database.g.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 128)();
  IntColumn get type => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text().withLength(max: 250)();
  IntColumn get category_id => integer()();
  DateTimeColumn get transaction_date => dateTime()();
  IntColumn get amount => integer()();
  DateTimeColumn get created_at => dateTime()();
  DateTimeColumn get updated_at => dateTime()();
  DateTimeColumn get deleted_at => dateTime().nullable()();
}



@DriftDatabase(tables: [Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<Category>> getAllCategoryRepo(int type) async {
    return await (select(categories)..where((tbl) => tbl.type.equals(type)))
        .get();
  }

  Future updateCategoryRepo(int id, String newName) async {
    return (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(newName),
      ),
    );
  }

  Future deleteCategoryRepo(int id) async {
    return (delete(categories)..where((tbl) => tbl.id.equals(id))).go();
  }

  Future deleteTransactionRepo(int id) async {
    return (delete(transactions)..where((tbl) => tbl.id.equals(id))).go();
  }

  Stream<List<TransactionWithCategory>> getTransactionByDateRepo(
      DateTime date) {
    final query = (select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.category_id))
    ])
      ..where(transactions.transaction_date.equals(date)));
    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategory(
          row.readTable(transactions),
          row.readTable(categories),
        );
      }).toList();
    });
  }

  Future updateTransactionRepo(int id, int amount, int categoryId,
      DateTime transactionDate, String name) async {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        description: Value(name),
        amount: Value(amount),
        category_id: Value(categoryId),
        transaction_date: Value(transactionDate),
      ),
    );
  }
}

QueryExecutor _openConnection() {
  // `driftDatabase` from `package:drift_flutter` stores the database in
  // `getApplicationDocumentsDirectory()`.
  return driftDatabase(name: 'my_database');
}
