import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_car_forum/ForumPage.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'AccountPage.dart';
import 'main.dart';
import 'HomePage.dart';

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
      'registrationSuccess': 'Registration successfull! Please log in.',
      'registrationFailed': 'Registration failed!',
      'fillFields': 'Please fill in all fields.',
      'fetchUserError': 'Fetch User Data Failed',
      'username' : 'Username'
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
      'registrationSuccess': 'Regisztráció sikeres! Kérjük, lépjen be.',
      'registrationFailed': 'Regisztráció sikertelen!',
      'loginFailed': 'Sikertelen bejelentkezés. Ellenőrizd a hitelesítő adatokat.',
      'fillFields': 'Töltsd ki az összes mezőt!',
      'fetchUserError': 'Felhasználói adatok lekérése sikertelen',
      'username' : 'Felhasználónév'
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
          MaterialPageRoute(builder: (context) => MainPage(),
          ),
        );
      }
    }
  }

Future<void> _fetchUserData() async {
  final token = await _authService.getToken();
  final userId = await _authService.getUserId();

  if (token != null && userId != null) {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (mounted) {  // Ellenőrizd, hogy a widget még aktív
        setState(() {
          _username = responseData['username'];
          _emailController.text = responseData['email'];
        });
      }
    } else {
      if (mounted) {  // Ha a widget még aktív, akkor mutasd az error üzenetet
        showFailed(context, translations[widget.selectedLanguage]!['fetchUserError']!);
      }
    }
  }
}

Future<void> _loginUser() async {
  final username = _usernameController.text.trim();
  final password = _passwordController.text.trim();

  if (username.isEmpty || password.isEmpty) {
    showWarning(context, translations[widget.selectedLanguage]!['fillFields']!);
    return;
  }

  bool success = await _authService.login(username, password);

  if (success) {
    setState(() => _isLoggedIn = true);
    showSuccess(context, translations[widget.selectedLanguage]!['loginSuccess']!);
    await _checkLoginStatus(); // Trigger navigation via _checkLoginStatus
  } else {
    showFailed(context, translations[widget.selectedLanguage]!['loginFailed']!);
  }
}


final TextEditingController _usernameController = TextEditingController(); // Új kontroller a felhasználónévhez

Future<void> _registerUser() async {
  final username = _usernameController.text.trim(); // Felhasználónév bekérése
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (username.isEmpty || email.isEmpty || password.isEmpty) {
  showWarning(context, translations[widget.selectedLanguage]!['fillFields']!);
  return;
  }

  final response = await http.post(
    Uri.parse('https://localhost:7164/api/User/register'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"username": username, "email": email, "password": password}),
  );

  print("API Response: ${response.statusCode} - ${response.body}");

  if (response.statusCode == 201) {
    showSuccess(context, translations[widget.selectedLanguage]!['registrationSuccess']!);
    setState(() => _isRegistering = false);
  } else {
    showFailed(context, translations[widget.selectedLanguage]!['registrationSuccess']!);
  }
}

@override
Widget build(BuildContext context) {
  String lang = _locale?.languageCode ?? 'en';
  Map<String, String> t = translations[lang] ?? translations['en']!;

  return Scaffold(
    appBar: AppBar(
      title: Text(_isLoggedIn
          ? '${t['welcome']}, $_username'
          : (_isRegistering ? t['chooseCategory']! : t['chooseYear']!)),
        backgroundColor: Colors.blueGrey.shade900,
        centerTitle: true,
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
                        showSuccess(context, translations[widget.selectedLanguage]!['logoutSuccess']!);
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
                        
                        // Csak regisztrációkor kérjük az e-mailt
                        if (_isRegistering) _buildTextField(_emailController, t['email']!),

                        _buildTextField(_usernameController, t['username']!), // Felhasználónév mező
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