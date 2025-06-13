import 'dart:convert';
import 'dart:io'; // HttpOverrides számára
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_car_forum/AIModelSite.dart';
import 'package:my_car_forum/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AccountPage.dart';
import 'ProfilePage.dart';
import 'ForumPage.dart';
import 'Marketplace.dart';
import 'MagazinePage.dart';
import 'ComparisonPage.dart';
import 'HomePage.dart';
import 'AdminPanelPage.dart';
import 'Translations.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await dotenv.load();

  // Inicializáljuk az AuthService-t
  final authService = AuthService();
  try {
    await authService.initGoogleSignIn();
  } catch (error) {
    print('Inicializálási hiba a main.dart-ban: $error');
  }

  runApp(CarForumApp(authService: authService));
}
class CarForumApp extends StatelessWidget {
  final AuthService authService;

  const CarForumApp({super.key, required this.authService});

  Future<bool> _checkApiAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('https://localhost:7164/api/Admin/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('API health check failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkApiAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError || !snapshot.data!) {
          return MaterialApp(
            theme: ThemeData(
              primarySwatch: Colors.orange,
              brightness: Brightness.dark,
            ),
            home: MaintenanceScreen(),
          );
        } else {
          return MaterialApp(
            title: 'The Car Magazin',
            theme: ThemeData(
              primarySwatch: Colors.orange,
              brightness: Brightness.dark,
            ),
            home: MainPage(authService: authService),
          );
        }
      },
    );
  }
}

class MaintenanceScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: Colors.orange,
              ),
              SizedBox(height: 20),
              Text(
                'Maintenance in Progress',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Our servers are currently undergoing maintenance. '
                'Please try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CarForumApp(authService: AuthService()),
                    ),
                  );
                },
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  final AuthService authService;

  const MainPage({super.key, required this.authService});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoggedIn = false;
  String _selectedLanguage = 'en';
  String? _userRole;

  final Map<String, String> languages = {
    'en': 'English',
    'hu': 'Magyar',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (mounted) {
      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
      });
    }
    if (_isLoggedIn) {
      await _fetchUserRole();
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final token = await widget.authService.getToken();
      if (token == null) {
        print('No auth token found. User is likely not logged in.');
        if (mounted) setState(() => _userRole = 'user');
        return;
      }

      final userIdStr = await widget.authService.getUserId();
      final userId = int.tryParse(userIdStr ?? '');
      if (userId == null) {
        if (mounted) setState(() => _userRole = 'user');
        return;
      }

      final response = await http.get(
        Uri.parse('https://localhost:7164/api/User/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final userData = json.decode(response.body);
        if (userData == null || userData['id'] == null || userData['role'] == null) {
          print('Invalid user data: $userData');
          if (mounted) setState(() => _userRole = 'user');
          return;
        }
        if (mounted) {
          setState(() {
            _userRole = userData['role'].toString();
            final newLength = _userRole == 'admin' ? 8 : 7;
            if (_tabController.length != newLength) {
              final currentIndex = _tabController.index;
              _tabController.dispose();
              _tabController = TabController(
                length: newLength,
                vsync: this,
                initialIndex: currentIndex < newLength ? currentIndex : 0,
              );
            }
          });
        }
      } else {
        print('Error fetching user role: ${response.statusCode} - ${response.body}');
        if (mounted) setState(() => _userRole = 'user');
      }
    } catch (e) {
      print('Exception during fetchUserRole: $e');
      if (mounted) setState(() => _userRole = 'user');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeLanguage(String languageCode) {
    if (mounted) setState(() => _selectedLanguage = languageCode);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 600;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(translations[_selectedLanguage]!['appTitle']!),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white),
            onSelected: _changeLanguage,
            itemBuilder: (BuildContext context) {
              return languages.keys
                  .map((key) => PopupMenuItem<String>(
                        value: key,
                        child: Text(languages[key]!),
                      ))
                  .toList();
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
              HomePage(selectedLanguage: _selectedLanguage),
              MagazinePage(),
              ForumPage(selectedLanguage: _selectedLanguage),
              MarketplacePage(),
              ComparisonPage(selectedLanguage: _selectedLanguage),
              AIModelSite(selectedLanguage: _selectedLanguage),
              AccountPage(selectedLanguage: _selectedLanguage),
              if (_userRole == 'admin') AdminPanelPage(selectedLanguage: _selectedLanguage),
            ]
          : [
              HomePage(selectedLanguage: _selectedLanguage),
              MagazinePage(),
              ForumPage(selectedLanguage: _selectedLanguage),
              MarketplacePage(),
              ComparisonPage(selectedLanguage: _selectedLanguage),
              AIModelSite(selectedLanguage: _selectedLanguage),
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
          labelStyle: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          tabs: _isLoggedIn
              ? [
                  Tab(text: translations[_selectedLanguage]!['home']),
                  Tab(text: translations[_selectedLanguage]!['magazine']),
                  Tab(text: translations[_selectedLanguage]!['forum']),
                  Tab(text: translations[_selectedLanguage]!['marketplace']),
                  Tab(text: translations[_selectedLanguage]!['comparison']),
                  Tab(text: translations[_selectedLanguage]!['aipredict']),
                  Tab(text: translations[_selectedLanguage]!['account']),
                  if (_userRole == 'admin') Tab(text: translations[_selectedLanguage]!['adminPanel']),
                ]
              : [
                  Tab(text: translations[_selectedLanguage]!['home']),
                  Tab(text: translations[_selectedLanguage]!['magazine']),
                  Tab(text: translations[_selectedLanguage]!['forum']),
                  Tab(text: translations[_selectedLanguage]!['marketplace']),
                  Tab(text: translations[_selectedLanguage]!['comparison']),
                  Tab(text: translations[_selectedLanguage]!['aipredict']),
                  Tab(text: translations[_selectedLanguage]!['profile']),
                ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _isLoggedIn
                ? [
                    HomePage(selectedLanguage: _selectedLanguage),
                    MagazinePage(),
                    ForumPage(selectedLanguage: _selectedLanguage),
                    MarketplacePage(),
                    ComparisonPage(selectedLanguage: _selectedLanguage),
                    AIModelSite(selectedLanguage: _selectedLanguage),
                    AccountPage(selectedLanguage: _selectedLanguage),
                    if (_userRole == 'admin') AdminPanelPage(selectedLanguage: _selectedLanguage),
                  ]
                : [
                    HomePage(selectedLanguage: _selectedLanguage),
                    MagazinePage(),
                    ForumPage(selectedLanguage: _selectedLanguage),
                    MarketplacePage(),
                    ComparisonPage(selectedLanguage: _selectedLanguage),
                    AIModelSite(selectedLanguage: _selectedLanguage),
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
                fit: BoxFit.contain,
              ),
            ),
            child: Text('', style: TextStyle(color: Colors.orange, fontSize: 24)),
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
            title: Text(translations[_selectedLanguage]!['comparison']!),
            onTap: () {
              _tabController.index = 4;
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: Text(translations[_selectedLanguage]!['aipredict']!),
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
            if (_userRole == 'admin') ...[
              ListTile(
                title: Text(translations[_selectedLanguage]!['adminPanel']!),
                onTap: () {
                  _tabController.index = 7;
                  Navigator.pop(context);
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}