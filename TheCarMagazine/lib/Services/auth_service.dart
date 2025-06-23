import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http show IOClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userID';
  static const String _languageKey = 'language';
  final HttpClient? customHttpClient = kIsWeb ? null : (HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true));
  final http.Client customClient = kIsWeb ? http.Client() : http.IOClient(HttpClient()..badCertificateCallback = ((X509Certificate cert, String host, int port) => true));

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

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

Future<bool> login(String username, String password) async {
  try {
    final response = await customClient.post(
      Uri.parse('https://localhost:7164/api/User/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username, 'password': password}),
    );

    print('Login response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('Response data: $responseData');

      if (responseData['token'] != null && responseData['userID'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, responseData['token']);
        await prefs.setString(_userIdKey, responseData['userID'].toString());
        await prefs.setString('username', responseData['username'] ?? 'Unknown');
        String language = responseData['language']?.toString() ?? 'hu';
        await prefs.setString(_languageKey, language);
        return true;
      } else {
        throw Exception('Invalid response data: missing token or userID');
      }
    } else if (response.statusCode == 401) {
      // Nem próbáljuk meg JSON-ként dekódolni, ha a válasz szöveges
      throw Exception(response.body.isNotEmpty ? response.body : 'Invalid credentials');
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  } on SocketException {
    throw Exception('No internet connection');
  } catch (error) {
    print('Login error: $error');
    throw Exception(error.toString());
  }
}

Future<Map<String, dynamic>> register(
  String email,
  String password,
  String username, {
  String language = 'en',
}) async {
  if (username.trim().length < 5) {
    print('Validation error: Username too short ($username)');
    return {
      'success': false,
      'error': 'Username must be at least 5 characters long',
    };
  }

  final passwordRegExp = RegExp(r'^(?=.*[A-Z])(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$');
  if (!passwordRegExp.hasMatch(password)) {
    print('Validation error: Invalid password');
    return {
      'success': false,
      'error': 'Password must be at least 8 characters long, contain 1 uppercase letter and 1 special character',
    };
  }

  try {
    print('Registration request sent: ${DateTime.now().toLocal()} (EEST)');
    final response = await customClient.post(
      Uri.parse('https://localhost:7164/api/User/register-argon2'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    print('Registration response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 201) {
      final responseData = json.decode(response.body);
      return {
        'success': true,
        'userId': responseData['userId']?.toString(),
      };
    } else {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['message'] ?? 'Registration failed';
      return {'success': false, 'error': errorMessage};
    }
  } on SocketException {
    return {
      'success': false,
      'error': 'No internet connection',
    };
  } catch (error) {
    print('Registration error: $error');
    return {
      'success': false,
      'error': 'Registration failed: $error',
    };
  }
}

  String? _parseErrorResponse(String responseBody) {
    try {
      final data = json.decode(responseBody);
      final error = data['error'] ?? data['message'];
      if (error != null) {
        switch (error.toString().toLowerCase()) {
          case 'username too short':
            return 'Username must be at least 5 characters long';
          case 'invalid password':
            return 'Password must be at least 8 characters long, contain 1 uppercase letter and 1 special character';
          case 'email already exists':
            return 'Email is already registered';
          case 'username already exists':
            return 'Username is already taken';
          default:
            return error.toString();
        }
      }
    } catch (e) {
      print('Error parsing error response: $e');
    }
    return null;
  }

  

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_tokenKey),
      prefs.remove(_userIdKey),
      prefs.remove('username'),
    ]);
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'hu';
  }
}


void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}

void showFailed(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: Colors.white)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ),
  );
}

void showWarning(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.warning, color: Colors.black),
          const SizedBox(width: 10),
          Text(message, style: const TextStyle(color: Colors.black)),
        ],
      ),
      backgroundColor: Colors.yellow,
      duration: const Duration(seconds: 3),
    ),
  );
}