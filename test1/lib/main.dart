import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AccountPage.dart';
import 'ProfilePage.dart';
import 'ForumPage.dart';
import 'Marketplace.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'MagazinePage.dart';
import 'CalendarPage.dart';
import 'ComparisonPage.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(CarForumApp());
}

String getApiKey() {
  return dotenv.env['PEXELS_API_KEY'] ?? 'ERROR: PEXELS API KEY IS NOT AVAILABLE!';
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
  String _selectedLanguage = 'en'; // Default language

  // Language selector state
  final Map<String, String> languages = {
    'en': 'English',
    'hu': 'Magyar',
  };

  // Translations
  final Map<String, Map<String, String>> translations = {
    'en': {
      'appTitle': 'The Car Magazin',
      'home': 'Home',
      'magazine': 'Magazine',
      'forum': 'Forum',
      'marketplace': 'Marketplace',
      'raceSchedule': 'Race Schedule',
      'comparison': 'Comparison',
      'account': 'Account',
      'profile': 'Profile',
      'welcome': 'Welcome to The Car Magazin!',
      'featuredCars': 'Featured Cars',
      'recentPosts': 'Recent Forum Posts',
      'languageChanged': 'Language changed to ',
    },
    'hu': {
      'appTitle': 'The Car Magazin',
      'home': 'Főoldal',
      'magazine': 'Magazin',
      'forum': 'Fórum',
      'marketplace': 'Piactér',
      'raceSchedule': 'Verseny Naptár',
      'comparison': 'Összehasonlítás',
      'account': 'Fiók',
      'profile': 'Profil',
      'welcome': 'Üdvözöljük az Autó Magazinban!',
      'featuredCars': 'Kiemelt Autók',
      'recentPosts': 'Legutóbbi Fórum Bejegyzések',
      'languageChanged': 'Nyelv megváltoztatva ',
    },
  };
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

    // Language selector state
    final Map<String, String> languages = {
      'en': 'English',
      'hu': 'Magyar',
    };



    void _changeLanguage(String languageCode) {
      setState(() {
        _selectedLanguage = languageCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${translations[_selectedLanguage]!['languageChanged']}${languages[languageCode]}')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(translations[_selectedLanguage]!['appTitle']!),
        actions: isMobile
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.language, color: Colors.white),
                  onSelected: _changeLanguage,
                  itemBuilder: (BuildContext context) {
                    return languages.keys.map((String key) {
                      return PopupMenuItem<String>(
                        value: key,
                        child: Text(languages[key]!),
                      );
                    }).toList();
                  },
                ),
              ]
            : [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.language, color: Colors.white),
                  onSelected: _changeLanguage,
                  itemBuilder: (BuildContext context) {
                    return languages.keys.map((String key) {
                      return PopupMenuItem<String>(
                        value: key,
                        child: Text(languages[key]!),
                      );
                    }).toList();
                  },
                ),
                const SizedBox(width: 16),
              ],
      ),
      drawer: isMobile ? _buildDrawer() : null,
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
              CalendarPage(selectedLanguage: _selectedLanguage),
              ComparisonPage(selectedLanguage: _selectedLanguage),
              AccountPage(),
            ]
          : [
              const Center(child: Text('Home Page')),
              MagazinePage(),
              ForumPage(),
              MarketplacePage(),
              CalendarPage(selectedLanguage: _selectedLanguage),
              ComparisonPage(selectedLanguage: _selectedLanguage),
              ProfilePage(selectedLanguage: _selectedLanguage),
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
              ? [
                  Tab(text: translations[_selectedLanguage]!['home']),
                  Tab(text: translations[_selectedLanguage]!['magazine']),
                  Tab(text: translations[_selectedLanguage]!['forum']),
                  Tab(text: translations[_selectedLanguage]!['marketplace']),
                  Tab(text: translations[_selectedLanguage]!['raceSchedule']),
                  Tab(text: translations[_selectedLanguage]!['comparison']),
                  Tab(text: translations[_selectedLanguage]!['account']),
                ]
              : [
                  Tab(text: translations[_selectedLanguage]!['home']),
                  Tab(text: translations[_selectedLanguage]!['magazine']),
                  Tab(text: translations[_selectedLanguage]!['forum']),
                  Tab(text: translations[_selectedLanguage]!['marketplace']),
                  Tab(text: translations[_selectedLanguage]!['raceSchedule']),
                  Tab(text: translations[_selectedLanguage]!['comparison']),
                  Tab(text: translations[_selectedLanguage]!['profile']),
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
                    CalendarPage(selectedLanguage: _selectedLanguage),
                    ComparisonPage(selectedLanguage: _selectedLanguage),
                    AccountPage(),
                  ]
                : [
                    const Center(child: Text('Home Page')),
                    MagazinePage(),
                    ForumPage(),
                    MarketplacePage(),
                    CalendarPage(selectedLanguage: _selectedLanguage),
                    ComparisonPage(selectedLanguage: _selectedLanguage),
                    ProfilePage(selectedLanguage: _selectedLanguage),
                  ],
          ),
        ),
      ],
    );
  }

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
            title: Text(translations[_selectedLanguage]!['home']!),
            onTap: () {
              _tabController.index = 0;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['magazine']!),
            onTap: () {
              _tabController.index = 1;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['forum']!),
            onTap: () {
              _tabController.index = 2;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['marketplace']!),
            onTap: () {
              _tabController.index = 3;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['raceSchedule']!),
            onTap: () {
              _tabController.index = 4;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['comparison']!),
            onTap: () {
              _tabController.index = 5;
              Navigator.pop(context);
            },
          ),
          if (!_isLoggedIn) ...[
            ListTile(
              title: Text(translations[_selectedLanguage]!['profile']!),
              onTap: () {
                _tabController.index = 6;
                Navigator.pop(context);
              },
            ),
          ],
          if (_isLoggedIn) ...[
            ListTile(
              title: Text(translations[_selectedLanguage]!['account']!),
              onTap: () {
                _tabController.index = 6;
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }
}