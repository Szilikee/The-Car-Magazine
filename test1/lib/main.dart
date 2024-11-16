import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AccountPage.dart';
import 'ProfilePage.dart';
import 'ForumPage.dart';
import 'Marketplace.dart';
import 'MagazinePage.dart';

void main() {
  runApp(CarForumApp());
}

class CarForumApp extends StatelessWidget {
  const CarForumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Car Magazin',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        brightness: Brightness.dark,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _tabController = TabController(length: 7, vsync: this);
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }


  @override
  Widget build(BuildContext context) {
    // Get the width of the screen
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 600;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('The Car Magazin'),
        actions: isMobile ? [] : null, // Hide actions in mobile view
      ),
      drawer: isMobile ? _buildDrawer() : null, // Show Drawer only on mobile
      body: isMobile ? _buildMobileBody() : _buildDesktopBody(),
    );
  }

  Widget _buildMobileBody() {
    return TabBarView(
      controller: _tabController,
      children: _isLoggedIn
          ? [
              const Center(child: Text('Home Page')),
              MagazinePage(),
              ForumPage(),
              MarketplacePage(),
              CalendarPage(),
              ComparisonPage(),
              AccountPage(),  // Csak akkor elérhető, ha be van jelentkezve
            ]
          : [
              const Center(child: Text('Home Page')),
              MagazinePage(),
              ForumPage(),
              MarketplacePage(),
              CalendarPage(),
              ComparisonPage(),
              ProfilePage(),  // Ha nincs bejelentkezve, akkor csak a ProfilePage érhető el
            ],
    );
  }

  Widget _buildDesktopBody() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          labelStyle: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          tabs: _isLoggedIn
              ? const [
                  Tab(text: 'Home'),
                  Tab(text: 'Magazine'),
                  Tab(text: 'Forum'),
                  Tab(text: 'Marketplace'),
                  Tab(text: 'Calendar'),
                  Tab(text: 'Comparison'),
                  Tab(text: 'Account'),  // Csak akkor elérhető, ha be van jelentkezve
                ]
              : const [
                  Tab(text: 'Home'),
                  Tab(text: 'Magazine'),
                  Tab(text: 'Forum'),
                  Tab(text: 'Marketplace'),
                  Tab(text: 'Calendar'),
                  Tab(text: 'Comparison'),
                  Tab(text: 'Profile'),  // Ha nincs bejelentkezve, akkor csak a ProfilePage érhető el
                ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _isLoggedIn
                ? [
                    const Center(child: Text('Home Page')),
                    MagazinePage(),
                    ForumPage(),
                    MarketplacePage(),
                    CalendarPage(),
                    ComparisonPage(),
                    AccountPage(),  // Csak akkor elérhető, ha be van jelentkezve
                  ]
                : [
                    const Center(child: Text('Home Page')),
                    MagazinePage(),
                    ForumPage(),
                    MarketplacePage(),
                    CalendarPage(),
                    ComparisonPage(),
                    ProfilePage(),  // Ha nincs bejelentkezve, akkor csak a ProfilePage érhető el
                  ],
          ),
        ),
      ],
    );
  }

  // Drawer a mobilhoz
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/pictures/logo.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Text(
              '',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            title: const Text('Home'),
            onTap: () {
              _tabController.index = 0; // Navigate to Home tab
              Navigator.pop(context); // Close the drawer
            },
          ),
          ListTile(
            title: const Text('Magazine'),
            onTap: () {
              _tabController.index = 1; // Navigate to Magazine tab
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Forum'),
            onTap: () {
              _tabController.index = 2; // Navigate to Forum tab
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Marketplace'),
            onTap: () {
              _tabController.index = 3; // Navigate to Marketplace tab
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Calendar'),
            onTap: () {
              _tabController.index = 4; // Navigate to Calendar tab
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Comparison'),
            onTap: () {
              _tabController.index = 5; // Navigate to Comparison tab
              Navigator.pop(context);
            },
          ),
          if (!_isLoggedIn) ...[
            ListTile(
              title: const Text('Profile'),
              onTap: () {
                _tabController.index = 6; // Navigate to Profile tab
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Calendar Page'));
  }
}

class ComparisonPage extends StatelessWidget {
  const ComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Comparison Page'));
  }
}
