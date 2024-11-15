import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'AccountPage.dart';
import 'main.dart';  // A HomePage-t kell importálni, ha onnan jössz vissza

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
  bool _isLoggedIn = false; // To check if the user is logged in
  String _username = ""; // Store the logged-in username

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Check if the user is logged in
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      setState(() {
        _isLoggedIn = true;
      });
      _fetchUserData();
      // Navigate to AccountPage if logged in
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AccountPage()),
        (Route<dynamic> route) => false, // Eltávolítja az összes előző oldalt
      );
    }
  }

  // Fetch User Data from the API
  Future<void> _fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getInt('userId');  // Feltételezve, hogy elmentettük

    if (token != null && token.isNotEmpty && userId != null) {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/userdetails/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Save the user data to SharedPreferences
        await prefs.setString('username', responseData['username']);
        await prefs.setString('email', responseData['email']);
        await prefs.setString('profileImage', responseData['profile_image_url'] ?? 'https://via.placeholder.com/150');

        setState(() {
          _username = responseData['username'];
          _emailController.text = responseData['email'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.reasonPhrase}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoggedIn ? 'Profile' : (_isRegistering ? 'Register' : 'Login')),
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
              if (!_isLoggedIn) ...[
                if (_isRegistering) _buildTextField(_usernameController, 'Username'),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email'),
                const SizedBox(height: 16),
                _buildTextField(_passwordController, 'Password', isPassword: true),
                const SizedBox(height: 20),
                _buildAuthButton(),
                const SizedBox(height: 20),
                _buildToggleAuthButton(),
              ] else ...[
                // Display logged-in user info
                Text('Welcome, $_username', style: TextStyle(color: Colors.white, fontSize: 20)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _logoutUser,
                  child: Text('Logout'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // TextField creation
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

  // Authentication Button for Register or Login
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

  // Registration function
  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/Forum/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (responseData.containsKey('token') && responseData.containsKey('userId')) {
          final token = responseData['token'];
          final userId = responseData['userId'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setInt('userId', userId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid server response. Missing Token or UserID.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${response.body}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $error')),
      );
    }
  }

  // Login function
  Future<void> _loginUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
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
          final token = responseData['token'];
          final userID = responseData['userID'];

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setInt('userID', userID);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (Route<dynamic> route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid server response. Missing Token or UserID.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    }
  }

  // Toggle between Register/Login
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

  // Logout function
  Future<void> _logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userID');
    await prefs.remove('username');
    await prefs.remove('email');
    await prefs.remove('profileImage');

    setState(() {
      _isLoggedIn = false;
    });

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (Route<dynamic> route) => false,
    );
  }
}
