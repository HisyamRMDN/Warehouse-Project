import 'package:calendar_appbar/calendar_appbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_project/Pages/home_page.dart';
import 'package:warehouse_project/Pages/category_page.dart';
import 'package:warehouse_project/Pages/form_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  late DateTime selectedDate;
  late List<Widget> _children;
  late int currentIndex;

  void updateView(int index, DateTime? date) {
    setState(() {
      if (date != null) {
        selectedDate = DateTime.parse(DateFormat('yyyy-MM-dd').format(date));
      }
      currentIndex = index;
      _children = [
        HomePage(
          selectedDate: selectedDate,
        ),
        const CategoryPage()
      ];
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    updateView(0, DateTime.now());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (currentIndex == 0)
          ? CalendarAppBar(
              accent: Colors.blue,
              locale: 'id',
              backButton: false,
              onDateChanged: (value) {
                setState(() {
                  selectedDate = value;
                  updateView(0, selectedDate);
                });
              },
              firstDate: DateTime.now().subtract(const Duration(days: 140)),
              lastDate: DateTime.now(),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Container(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 36, horizontal: 25),
                  child: Text(
                    'Kategori',
                    style: GoogleFonts.montserrat(fontSize: 25),
                  ),
                ),
              )),
      floatingActionButton: Visibility(
        visible: (currentIndex == 0) ? true : false,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context)
                .push(MaterialPageRoute(
              builder: (context) => const TransactionPage(
                transactionsWithCategory: null,
              ),
            ))
                .then((value) {
              setState(() {});
            });
          },
          backgroundColor: Colors.blue,
          child: const Icon(Icons.add),
        ),
      ),
      body: _children[currentIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
                onPressed: () {
                  updateView(0, DateTime.now());
                },
                icon: const Icon(Icons.home)),
            const SizedBox(
              width: 20,
            ),
            IconButton(
                onPressed: () {
                  updateView(1, null);
                },
                icon: const Icon(Icons.list))
          ],
        ),
      ),
    );
  }
}
