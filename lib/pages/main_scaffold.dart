import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scraps_to_snacks/pages/home_page.dart';
import 'package:scraps_to_snacks/pages/cookbook_page.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = [const HomePage(), const CookbookPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          indicatorColor: Colors.green.withOpacity(0.1),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.kitchen_outlined),
              selectedIcon: const Icon(Icons.kitchen, color: Colors.green),
              label: 'Pantry',
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book, color: Colors.green),
              label: 'Cookbook',
            ),
          ],
        ),
      ),
    );
  }
}
