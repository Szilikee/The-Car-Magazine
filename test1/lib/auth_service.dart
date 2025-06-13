import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart' as web;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class AuthService {
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'userID';
  static const String _languageKey = 'language';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '1002849795684-cmhmaht11g5qib9ik08atb02ut36bdkj.apps.googleusercontent.com'
        : null, // Mobil esetén natív konfiguráció
    scopes: ['email', 'profile', 'openid'],
  );

  final web.GoogleSignInPlugin _webGoogleSignIn = web.GoogleSignInPlugin();
  bool _isInitialized = false;

  Future<void> initGoogleSignIn() async {
    if (_isInitialized) return; // Prevent multiple initializations
    try {
      if (kIsWeb) {
        await _webGoogleSignIn.init(
          clientId: '1002849795684-cmhmaht11g5qib9ik08atb02ut36bdkj.apps.googleusercontent.com',
          scopes: ['email', 'profile', 'openid'],
        );
        final userData = await _webGoogleSignIn.signInSilently();
        if (userData != null) {
          print('Webes felhasználó csendben bejelentkezett: ${userData.email}');
          print('GoogleSignInUserData: idToken=${userData.idToken}, email=${userData.email}, displayName=${userData.displayName}, serverAuthCode=${userData.serverAuthCode}');
          await _sendTokenToBackend(userData, null);
        }
      } else {
        _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
          if (account != null) {
            print('Mobil felhasználó bejelentkezett: ${account.email}');
            await _sendTokenToBackend(account, null);
          }
        });
        await _googleSignIn.signInSilently();
      }
      _isInitialized = true;
    } catch (error) {
      print('Google Sign-In inicializálási hiba: $error');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<bool> get isInitialized async {
    if (!_isInitialized) {
      try {
        await initGoogleSignIn();
      } catch (_) {
        return false;
      }
    }
    return _isInitialized;
  }

  Widget buildGoogleSignInButton(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<bool>(
        future: isInitialized,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasError || !snapshot.data!) {
            return ElevatedButton(
              onPressed: () => showFailed(context, 'Google Sign-In inicializálási hiba'),
              child: const Text('Google Bejelentkezés Hiba'),
            );
          }
          return _webGoogleSignIn.renderButton(
            configuration: web.GSIButtonConfiguration(
              type: web.GSIButtonType.standard,
              theme: web.GSIButtonTheme.filledBlue,
              size: web.GSIButtonSize.large,
              shape: web.GSIButtonShape.pill,
            ),
          );
        },
      );
    } else {
      return ElevatedButton(
        onPressed: () async {
          try {
            final GoogleSignInAccount? account = await _googleSignIn.signIn();
            if (account != null) {
              await _sendTokenToBackend(account, context);
              showSuccess(context, 'Sikeres Google bejelentkezés');
            }
          } catch (error) {
            print('Google bejelentkezési hiba: $error');
            showFailed(context, 'Google bejelentkezés sikertelen: $error');
          }
        },
        child: const Text('Bejelentkezés Google-lal'),
      );
    }
  }

 Future<void> _sendTokenToBackend(dynamic account, BuildContext? context) async {
  String? idToken;
  String? displayName;
  String? email;

  try {
    if (kIsWeb) {
      // Webes típus
  final web.GoogleSignInUserData userData = account as GoogleSignInUserData;

    idToken = userData.idToken;
    displayName = userData.displayName;
    email = userData.email;



    } else {
      // Mobilos típus
      final GoogleSignInAccount googleAccount = account as GoogleSignInAccount;
      final auth = await googleAccount.authentication;

      idToken = auth.idToken;
      displayName = googleAccount.displayName;
      email = googleAccount.email;
    }

    if (idToken == null) {
      final errorMessage = 'Nem sikerült megszerezni a Google ID tokent.';
      if (context != null) {
      }
      throw Exception(errorMessage);
    }

    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/google-sign-in'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      await saveToken(responseData['token']);
      await saveUserId(responseData['userId'].toString());
      await saveUsername(displayName ?? email.split('@')[0]);
      if (context != null) {
        showSuccess(context, 'Sikeres Google bejelentkezés');
      }
      print('Backend válasz: ${response.body}');
    } else {
      if (context != null) {
        showFailed(context, 'Backend hiba: ${response.body}');
      }
      throw Exception('Backend hiba: ${response.statusCode} - ${response.body}');
    }
  } catch (error) {
    print('Hiba a _sendTokenToBackend-ben: $error');
    if (context != null) {
    }
    rethrow;
  }
}


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

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/User/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      );

      print('Bejelentkezési válasz: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Válasz adatok: $responseData');

        if (responseData['token'] != null && responseData['userID'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenKey, responseData['token']);
          await prefs.setString(_userIdKey, responseData['userID'].toString());
          await prefs.setString('username', responseData['username'] ?? 'Ismeretlen');
          String language = responseData['language']?.toString() ?? 'hu';
          await prefs.setString(_languageKey, language);
          return true;
        } else {
          throw Exception('Érvénytelen válaszadatok: hiányzó token vagy userID');
        }
      } else if (response.statusCode == 401 && response.body.contains('Your account is banned')) {
        throw Exception('A fiókod tiltva van');
      } else {
        throw Exception(response.body);
      }
    } catch (error) {
      print('Bejelentkezési hiba: $error');
      throw Exception(error.toString());
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String username) async {
    try {
      print("Regisztrációs kérés küldése: ${DateTime.now().toLocal()} (EEST)");
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/User/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print('Regisztrációs válasz: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'userId': responseData['userId'].toString(),
        };
      } else {
        throw Exception(response.body);
      }
    } catch (error) {
      print('Regisztrációs hiba: $error');
      throw Exception(error.toString());
    }
  }

  Future<Map<String, dynamic>> googleSignIn(BuildContext context) async {
    try {
      if (kIsWeb) {
        if (!_isInitialized) await initGoogleSignIn();
        final userData = await _webGoogleSignIn.signIn();
        if (userData == null) {
          throw Exception('Google bejelentkezés megszakítva a felhasználó által');
        }
        await _sendTokenToBackend(userData, context);
        return {
          'success': true,
          'userId': await getUserId(),
          'username': userData.displayName ?? userData.email.split('@')[0],
          'email': userData.email,
        };
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Google bejelentkezés megszakítva a felhasználó által');
        }
        await _sendTokenToBackend(googleUser, context);
        return {
          'success': true,
          'userId': await getUserId(),
          'username': googleUser.displayName ?? googleUser.email.split('@')[0],
          'email': googleUser.email,
        };
      }
    } catch (error) {
      print('Google bejelentkezési hiba: $error');
      throw Exception(error.toString());
    }
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    if (kIsWeb) {
      await _webGoogleSignIn.signOut();
    } else {
      await _googleSignIn.signOut();
    }
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