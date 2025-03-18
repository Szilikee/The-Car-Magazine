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

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/Forum/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      print('Login Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Parsed Response Data: $responseData');
        print('Token: ${responseData['token']}');
        print('UserID: ${responseData['userID']}');
        print('Has Token: ${responseData['token'] != null}');
        print('Has UserID: ${responseData['userID'] != null}');

        if (responseData['token'] != null && responseData['userID'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, responseData['token']);
          await prefs.setString(_userIdKey, responseData['userID'].toString());
          String language = responseData['language']?.toString() ?? 'en';
          await prefs.setString(_languageKey, language);
          print('Login Success: Token and UserID stored');
          return true;
        } else {
          print('Login Failed: Missing token or userID');
          return false;
        }
      } else {
        print('Login Failed: Status Code ${response.statusCode}');
        return false;
      }
    } catch (error) {
      print('Login Error: $error');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_languageKey);
  }

    Future<bool> register(String email, String password) async {
    // Implement your register API call here
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/Forum/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    return response.statusCode == 201; // Assuming 201 for successful registration
  }

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }
}