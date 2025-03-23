import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:warehouse_project/models/item_category.dart';
import 'package:warehouse_project/models/database.dart';
import 'package:warehouse_project/Pages/form_page.dart';

class HomePage extends StatefulWidget {
  final DateTime selectedDate;
  const HomePage({Key? key, required this.selectedDate}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppDatabase database = AppDatabase();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text Transaksi
            Padding(
              padding: const EdgeInsets.all(15),
              child: Text("Data Barang",
                  style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),

            StreamBuilder<List<TransactionWithCategory>>(
                stream: database.getTransactionByDateRepo(widget.selectedDate),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else {
                    if (snapshot.hasData) {
                      if (snapshot.data!.isNotEmpty) {
                        return ListView.builder(
                            shrinkWrap: true,
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Card(
                                  elevation: 10,
                                  child: ListTile(
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () async {
                                            await database
                                                .deleteTransactionRepo(snapshot
                                                    .data![index]
                                                    .transaction
                                                    .id);
                                            setState(() {});
                                          },
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        TransactionPage(
                                                          transactionsWithCategory:
                                                              snapshot
                                                                  .data![index],
                                                        )));
                                          },
                                        )
                                      ],
                                    ),
                                    title: Text(
                                        "${snapshot.data![index].category.name}(${snapshot.data![index].transaction
                                                .description})"),
                                    subtitle: Text("${snapshot
                                            .data![index].transaction.amount} Pcs"),
                                    leading: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: (snapshot
                                                  .data![index].category.type ==
                                              2)
                                          ? Icon(Icons.upload,
                                              color: Colors.red)
                                          : Icon(Icons.download,
                                              color: Colors.green),
                                    ),
                                  ),
                                ),
                              );
                            });
                      } else {
                        return const Center(
                          child: Text("Data Transaksi Masih Kosong"),
                        );
                      }
                    } else {
                      return const Center(
                        child: Text("Tidak Ada Data"),
                      );
                    }
                  }
                }),
          ],
        ),
      ),
    );
  }
}
