
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_project/models/database.dart';
import 'package:warehouse_project/models/item_category.dart';

class TransactionPage extends StatefulWidget {
  final TransactionWithCategory? transactionsWithCategory;
  const TransactionPage({Key? key, required this.transactionsWithCategory})
      : super(key: key);

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  bool isOut = true;
  late int type;
  final AppDatabase database = AppDatabase();
  Category? selectedCategory;
  TextEditingController dateController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  Future insert(int amount, DateTime date, String name, int categoryId) async {
    DateTime now = DateTime.now();
    final row = await database.into(database.transactions).insertReturning(
        TransactionsCompanion.insert(
            amount: amount,
            category_id: categoryId,
            description: name,
            transaction_date: date,
            created_at: now,
            updated_at: now));
  }

  @override
  void initState() {
    // TODO: implement initState
    if (widget.transactionsWithCategory != null) {
      updateTransaction(widget.transactionsWithCategory!);
    } else {
      type = 2;

      dateController.text = "";
    }
    super.initState();
  }

  Future<List<Category>> getAllCategory(int type) async {
    return await database.getAllCategoryRepo(type);
  }

  Future update(
    int transactionId,
    int amount,
    int categoryId,
    DateTime transactionDate,
    String name,
  ) async {
    await database.updateTransactionRepo(
        transactionId, amount, categoryId, transactionDate, name);
  }

  void updateTransaction(TransactionWithCategory initTransaction) {
    amountController.text = initTransaction.transaction.amount.toString();
    nameController.text = initTransaction.transaction.description.toString();
    dateController.text = DateFormat('yyyy-MM-dd')
        .format(initTransaction.transaction.transaction_date);
    type = initTransaction.category.type;
    (type == 2) ? isOut = true : isOut = false;
    selectedCategory = initTransaction.category;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Barang")),
      body: SingleChildScrollView(
        child: SafeArea(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  // This bool value toggles the switch.
                  value: isOut,
                  inactiveTrackColor: Colors.green[200],
                  inactiveThumbColor: Colors.green,
                  activeColor: Colors.red,
                  onChanged: (bool value) {
                    setState(() {
                      isOut = value;
                      type = (isOut) ? 2 : 1;
                      selectedCategory = null;
                    });
                  },
                ),
                Text(
                  isOut ? "Barang Keluar" : "Barang Masuk",
                  style: GoogleFonts.montserrat(fontSize: 14),
                )
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text("Kategori", style: GoogleFonts.montserrat()),
            ),
            const SizedBox(
              height: 5,
            ),
            FutureBuilder<List<Category>>(
              future: getAllCategory(type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else {
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButton<Category>(
                        isExpanded: true,
                        value: (selectedCategory == null)
                            ? snapshot.data!.first
                            : selectedCategory,
                        icon: const Icon(Icons.arrow_downward),
                        elevation: 16,
                        onChanged: (Category? value) {
                          setState(() {
                            selectedCategory = value;
                          });
                        },
                        items: snapshot.data!.map((Category value) {
                          return DropdownMenuItem<Category>(
                            value: value,
                            child: Text(value.name),
                          );
                        }).toList(),
                      ),
                    );
                  } else {
                    return const Center(child: Text("Belum ada kategori"));
                  }
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Stok',
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const SizedBox(
              height: 10,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: dateController,
                decoration:
                    const InputDecoration(labelText: "Masukkan Tanggal"),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(), 
                      firstDate: DateTime(
                          2000), 
                      lastDate: DateTime(2101));

                  if (pickedDate != null) {
                    print(
                        pickedDate); 
                    String formattedDate = DateFormat('yyyy-MM-dd').format(
                        pickedDate); 
                    print(
                        formattedDate); 

                    setState(() {
                      dateController.text =
                          formattedDate;
                    });
                  } else {
                    print("Tanggal Tidak DiPilih");
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Ukuran',
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Center(
                child: ElevatedButton(
                    onPressed: () async {
                      (widget.transactionsWithCategory == null)
                          ? insert(
                              int.parse(amountController.text),
                              DateTime.parse(dateController.text),
                              nameController.text,
                              selectedCategory!.id,
                            )
                          : await update(
                              widget.transactionsWithCategory!.transaction.id,
                              int.parse(amountController.text),
                              selectedCategory!.id,
                              DateTime.parse(dateController.text),
                              nameController.text);
                      Navigator.pop(context, true);
                    },
                    child: const Text('Simpan')))
          ],
        )),
      ),
    );
  }
}
