import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:warehouse_project/models/database.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  int type = 2;
  bool isOut = true;
  final AppDatabase database = AppDatabase();
  TextEditingController categoryNameController = TextEditingController();

  Future insert(String name, int type) async {
    DateTime now = DateTime.now();
    final row = await database.into(database.categories).insertReturning(
        CategoriesCompanion.insert(
            name: name, type: type, createdAt: now, updatedAt: now));
    print(row);
  }

  Future<List<Category>> getAllCategory(int type) async {
    return await database.getAllCategoryRepo(type);
  }

  @override
  void initState() {
    // TODO: implement initState
    isOut = true;
    type = (isOut) ? 2 : 1;
    super.initState();
  }

  Future update(int categoryId, String newName) async {
    await database.updateCategoryRepo(categoryId, newName);
  }

  Future<void> confirmDelete(int categoryId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Hapus Kategori"),
          content: const Text("Apakah Anda yakin ingin menghapus kategori ini?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Batal
              },
              child: const Text("Batal"),
            ),
            TextButton(
              onPressed: () async {
                await database.deleteCategoryRepo(categoryId);
                Navigator.of(context).pop(); // Tutup dialog
                setState(() {}); // Memperbarui UI
              },
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );
  }

  void openDialog(Category? category) {
    categoryNameController.clear();
    if (category != null) {
      categoryNameController.text = category.name;
    }
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: SingleChildScrollView(
                child: Center(
                    child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  ((category != null) ? 'Ubah' : '') +
                      ((isOut) ? "Barang Keluar" : "Barang Masuk"),
                  style: GoogleFonts.montserrat(
                      fontSize: 18, color: (isOut) ? Colors.red : Colors.green),
                ),
                const SizedBox(
                  height: 10,
                ),
                TextFormField(
                  controller: categoryNameController,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), hintText: "Nama"),
                ),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton(
                    onPressed: () {
                      (category == null)
                          ? insert(categoryNameController.text, isOut ? 2 : 1)
                          : update(category.id, categoryNameController.text);
                      setState(() {});

                      Navigator.of(context, rootNavigator: true).pop('dialog');
                    },
                    child: const Text("Simpan"))
              ],
            ))),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Switch(
                value: isOut,
                onChanged: (bool value) {
                  setState(() {
                    isOut = value;
                    type = value ? 2 : 1;
                  });
                },
                inactiveThumbColor: Colors.green[200],
                inactiveTrackColor: Colors.green,
                activeColor: Colors.red,
              ),
              Text(
                isOut ? "Barang Keluar" : "Barang Masuk",
                style: GoogleFonts.montserrat(fontSize: 14),
              ),
              IconButton(
                  onPressed: () {
                    openDialog(null);
                  },
                  icon: const Icon(Icons.add))
            ],
          ),
        ),
        FutureBuilder<List<Category>>(
            future: getAllCategory(type),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Card(
                              elevation: 10,
                              child: ListTile(
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete),
                                        onPressed: () => confirmDelete(
                                            snapshot.data![index].id),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          openDialog(snapshot.data![index]);
                                          setState(() {});
                                        },
                                      )
                                    ],
                                  ),
                                  leading: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: (isOut)
                                          ? Icon(Icons.upload,
                                              color: Colors.redAccent[400])
                                          : Icon(
                                              Icons.download,
                                              color: Colors.greenAccent[400],
                                            )),
                                  title: Text(snapshot.data![index].name)),
                            ),
                          );
                        });
                  } else {
                    return const Center(
                      child: Text("Tidak Ada Data"),
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
    ));
  }
}
