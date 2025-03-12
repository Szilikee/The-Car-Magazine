import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'AccountPage.dart';
import 'main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoggedIn = false;
  String _username = "";

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    bool loggedIn = await AuthService().isUserLoggedIn();
    if (loggedIn) {
      setState(() {
        _isLoggedIn = true;
      });
      _fetchUserData();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AccountPage()),
      );
    }
  }

  void _registerUser() {
    // Itt lehetne ellenőrizni az emailt, jelszót és regisztrálni a felhasználót
    setState(() {
      _isLoggedIn = true;
      _username = _emailController.text.split('@')[0]; // Példa: email első része lesz a felhasználónév
    });
  }

  Future<void> _fetchUserData() async {
    final token = await AuthService().getToken();
    final userId = await AuthService().getUserId();

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
      }
    }
  }

  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/Forum/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData.containsKey('token') && responseData.containsKey('userID')) {
          await AuthService().saveUserCredentials(responseData['token'], responseData['userID']);
          _showMessage('Login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        _showMessage('Login failed: ${response.statusCode}');
      }
    } catch (error) {
      _showMessage('Network error: $error');
    }
  }

  Future<void> _logoutUser() async {
    await AuthService().logout();
    setState(() {
      _isLoggedIn = false;
    });
    _showMessage('Logged out successfully');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ProfilePage()),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text(_isLoggedIn ? 'Profile' : (_isRegistering ? 'Register' : 'Login'))),
    body: Center(
      child: _isLoggedIn
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome, $_username'),
                ElevatedButton(onPressed: _logoutUser, child: const Text('Logout')),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTextField(_emailController, 'Email'),
                _buildTextField(_passwordController, 'Password', isPassword: true),
                ElevatedButton(
                  onPressed: _isRegistering ? _registerUser : _loginUser,
                  child: Text(_isRegistering ? 'Register' : 'Login'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                    });
                  },
                  child: Text(_isRegistering ? 'Already have an account? Login' : 'Don’t have an account? Register'),
                ),
              ],
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
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
