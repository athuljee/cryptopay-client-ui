import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'trending_page.dart';
import 'transaction_history.dart';
import 'offline_wallet_screen.dart';

/// Main shell: bottom nav (Home | Trending | Transactions | Offline Wallet),
/// horizontal swipe between tabs, and app-wide theme.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _isDark = true;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          children: [
            HomeScreen(
              embedded: true,
              isDark: _isDark,
              onThemeChanged: (v) => setState(() => _isDark = v),
            ),
            const TrendingPage(),
            const TransactionHistory(),
            const OfflineWalletScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF5CFFB0),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: "Trending"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "Transactions"),
            BottomNavigationBarItem(icon: Icon(Icons.phone_android), label: "Offline Wallet"),
          ],
        ),
      ),
    );
  }
}
