import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'AccountPage.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  final String selectedLanguage;
  const ProfilePage({super.key, required this.selectedLanguage});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoggedIn = false;
  String _username = "";
  Locale? _locale;
  final AuthService _authService = AuthService();

  final Map<String, Map<String, String>> translations = {
    'en': {
      'appBarTitle': 'Profile',
      'chooseCategory': 'Register',
      'chooseYear': 'Login',
      'welcome': 'Welcome',
      'logout': 'Logout',
      'createAccount': 'Create an Account',
      'loginAccount': 'Login to Your Account',
      'email': 'Email',
      'password': 'Password',
      'register': 'Register',
      'login': 'Login',
      'alreadyHaveAccount': 'Already have an account? Login',
      'dontHaveAccount': 'Don’t have an account? Register',
      'logoutSuccess': 'Logged out successfully',
      'loginSuccess': 'Login successful!',
      'loginFailed': 'Login failed. Check your credentials.',
      'fillFields': 'Please fill in all fields.',
      'fetchUserError': 'Fetch User Data Failed',
    },
    'hu': {
      'appBarTitle': 'Profil',
      'chooseCategory': 'Regisztráció',
      'chooseYear': 'Bejelentkezés',
      'welcome': 'Üdvözlünk',
      'logout': 'Kijelentkezés',
      'createAccount': 'Fiók létrehozása',
      'loginAccount': 'Bejelentkezés a fiókba',
      'email': 'Email',
      'password': 'Jelszó',
      'register': 'Regisztráció',
      'login': 'Bejelentkezés',
      'alreadyHaveAccount': 'Van már fiókod? Jelentkezz be',
      'dontHaveAccount': 'Nincs még fiókod? Regisztrálj',
      'logoutSuccess': 'Sikeres kijelentkezés',
      'loginSuccess': 'Sikeres bejelentkezés!',
      'loginFailed': 'Sikertelen bejelentkezés. Ellenőrizd a hitelesítő adatokat.',
      'fillFields': 'Töltsd ki az összes mezőt!',
      'fetchUserError': 'Felhasználói adatok lekérése sikertelen',
    },
  };

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.selectedLanguage);
    _checkLoginStatus();
  }

  @override
  void didUpdateWidget(ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      setState(() {
        _locale = Locale(widget.selectedLanguage);
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    bool loggedIn = await _authService.isUserLoggedIn();
    setState(() {
      _isLoggedIn = loggedIn;
    });
    if (loggedIn) {
      await _fetchUserData();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountPage()),
        );
      }
    }
  }

  Future<void> _fetchUserData() async {
    final token = await _authService.getToken();
    final userId = await _authService.getUserId();

    if (token != null && userId != null) {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/userdetails/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        setState(() {
          _username = responseData['username'];
          _emailController.text = responseData['email'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translations[widget.selectedLanguage]!['fetchUserError']!)),
        );
      }
    }
  }

  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['fillFields']!)),
      );
      return;
    }
    bool success = await _authService.login(email, password);
    if (success) {
      setState(() => _isLoggedIn = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['loginSuccess']!)),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['loginFailed']!)),
      );
    }
  }

  Future<void> _registerUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['fillFields']!)),
      );
      return;
    }
    // Assuming AuthService has a register method; adjust as per your implementation
    bool success = await _authService.register(email, password);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['loginSuccess']!)),
      );
      setState(() => _isRegistering = false); // Switch back to login mode after successful registration
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(translations[widget.selectedLanguage]!['loginFailed']!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String lang = _locale?.languageCode ?? 'en';
    Map<String, String> t = translations[lang] ?? translations['en']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoggedIn ? '${t['welcome']}, $_username' : (_isRegistering ? t['chooseCategory']! : t['chooseYear']!)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoggedIn)
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.logout();
                          setState(() => _isLoggedIn = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t['logoutSuccess']!)),
                          );
                        },
                        child: Text(t['logout']!),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            _isRegistering ? t['createAccount']! : t['loginAccount']!,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(_emailController, t['email']!),
                          _buildTextField(_passwordController, t['password']!, isPassword: true),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isRegistering ? _registerUser : _loginUser,
                            child: Text(_isRegistering ? t['register']! : t['login']!),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isRegistering = !_isRegistering;
                              });
                            },
                            child: Text(
                              _isRegistering ? t['alreadyHaveAccount']! : t['dontHaveAccount']!,
                              style: const TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}