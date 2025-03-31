import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userID';
  static const String _languageKey = 'language';

  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) != null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

Future<bool> login(String username, String password) async {
  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/login'),  // Replace with actual IP
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    print('Login Response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('Response Data: $responseData');
      
      if (responseData['token'] != null && responseData['userID'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, responseData['token']);
        await prefs.setString(_userIdKey, responseData['userID'].toString());
        await prefs.setString('username', responseData['username'] ?? 'Unknown'); // Add username
        String language = responseData['language']?.toString() ?? 'en';
        await prefs.setString(_languageKey, language);
        return true;
      }
    }
    print('Login Failed: Status Code ${response.statusCode}');
    return false;
  } catch (error) {
    print('Login Error: $error');
    return false;
  }
}


Future<String?> getUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('username');
}

Future<void> logout() async {
  // Get the shared preferences instance
  final prefs = await SharedPreferences.getInstance();

  // Remove the stored token, user ID, and language
  await Future.wait([
    prefs.remove(_tokenKey),    // Remove token
    prefs.remove(_userIdKey),   // Remove user ID
    prefs.remove(_languageKey),  // Remove language preference
  ]);
}


Future<bool> register(String email, String password, String username) async {
  final response = await http.post(
    Uri.parse('https://localhost:7164/api/User/register'),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'username': username,
      'email': email,
      'password': password,
    }),
  );
  return response.statusCode == 201;
}


  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }
}


void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text(message, style: TextStyle(color: Colors.white)),
        ],
      ),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
    ),
  );
}


void showFailed(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.error, color: Colors.white),
          SizedBox(width: 10),
          Text(message, style: TextStyle(color: Colors.white)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 5),
    ),
  );
}


void showWarning(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(Icons.warning, color: Colors.black),
          SizedBox(width: 10),
          Text(message, style: TextStyle(color: Colors.black)),
        ],
      ),
      backgroundColor: Colors.yellow,
      duration: Duration(seconds: 3),
    ),
  );
}
