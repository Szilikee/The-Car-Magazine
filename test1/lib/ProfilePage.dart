import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isRegistering = false; // Toggle for register/login

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Register' : 'Login'),
        backgroundColor: Colors.black87,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black54, Colors.grey[850]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_isRegistering) _buildTextField(_usernameController, 'Username'),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email'),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'Password', isPassword: true),
              const SizedBox(height: 20),
              _buildAuthButton(),
              const SizedBox(height: 20),
              _buildToggleAuthButton(),
            ],
          ),
        ),
      ),
    );
  }

  // TextField készítése
  Widget _buildTextField(TextEditingController controller, String label, {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
        filled: true,
        fillColor: Colors.black38,
      ),
    );
  }

  // Gomb regisztrációhoz vagy bejelentkezéshez
  Widget _buildAuthButton() {
    return ElevatedButton(
      onPressed: _isRegistering ? _registerUser : _loginUser,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
      ),
      child: Text(
        _isRegistering ? 'Register' : 'Login',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // Felhasználói adatok mentése az adatbázisba
  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Ellenőrizd, hogy a mezők nem üresek
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    // API hívás a felhasználó regisztrálásához
    final response = await http.post(
      Uri.parse('http://localhost:7164/api/forum/register'), // Frissített URL
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')),
      );
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${response.body}')),
      );
    }
  }

  // Bejelentkezés
  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    // API hívás a felhasználó bejelentkezéséhez
    final response = await http.post(
      Uri.parse('http://127.0.0.1:7164/api/forum/login'), // Frissített URL
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful!')),
      );
      _emailController.clear();
      _passwordController.clear();
      // Navigálj a főoldalra vagy végezd el a további lépéseket
    } else {
      // Kiíratás a válasz ellenőrzéséhez
      print('Login failed: ${response.statusCode} - ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${response.body}')),
      );
    }
  }

  // Gomb a bejelentkezés és regisztráció közötti váltáshoz
  Widget _buildToggleAuthButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          _isRegistering = !_isRegistering;
        });
      },
      child: Text(
        _isRegistering ? 'Already have an account? Login' : 'Don\'t have an account? Register',
        style: const TextStyle(color: Colors.lightBlueAccent),
      ),
    );
  }
}
