import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'main.dart';
import 'Translations.dart';

class ProfilePage extends StatefulWidget {
  final String selectedLanguage;
  const ProfilePage({super.key, required this.selectedLanguage});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _supportUserIdController = TextEditingController();
  final TextEditingController _supportUsernameController = TextEditingController();
  final TextEditingController _supportEmailController = TextEditingController();
  final TextEditingController _supportSubjectController = TextEditingController();
  final TextEditingController _supportMessageController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoggedIn = false;
  String _username = "";
  String? _userId;
  Locale? _locale;
  final AuthService _authService = AuthService();

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
          MaterialPageRoute(builder: (context) => MainPage(authService: AuthService())),
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
        if (mounted) {
          setState(() {
            _username = responseData['username'];
            _emailController.text = responseData['email'];
          });
        }
      } else {
        if (mounted) {
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

    try {
      bool success = await _authService.login(username, password);
      if (success) {
        setState(() => _isLoggedIn = true);
        showSuccess(context, translations[widget.selectedLanguage]!['loginSuccess']!);
        await _checkLoginStatus();
      }
    } catch (e) {
      showFailed(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _registerUser() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      showWarning(context, translations[widget.selectedLanguage]!['fillFields']!);
      return;
    }

    try {
      final result = await _authService.register(email, password, username);
      if (result['success']) {
        setState(() {
          _userId = result['userId'];
        });
        showSuccess(context, translations[widget.selectedLanguage]!['registrationSuccess']!);
        _showVerificationDialog();
      }
    } catch (e) {
      showFailed(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

    Future<void> _googleSignIn() async {
    try {
      final result = await _authService.googleSignIn(context);
      if (result['success'] == true) { // Biztosíték a típusellenőrzéshez
        setState(() {
          _isLoggedIn = true;
          _username = result['username'];
          _emailController.text = result['email'] ?? '';
        });
        showSuccess(context, translations[widget.selectedLanguage]!['googleSignInSuccess']!);
        await _checkLoginStatus(); // Frissítsd az állapotot
      }
    } catch (e) {
      showFailed(context, translations[widget.selectedLanguage]!['googleSignInFailed']!);
    }
  }


  Future<void> _verifyCode(String code) async {
    if (_userId == null) {
      showFailed(context, translations[widget.selectedLanguage]!['verificationFailed']!);
      return;
    }

    final uppercaseCode = code.trim().toUpperCase();
    final int? parsedUserId = int.tryParse(_userId!);
    if (parsedUserId == null) {
      showFailed(context, translations[widget.selectedLanguage]!['verificationFailed']!);
      return;
    }
    print("Sending Verification Request: userId: $parsedUserId, code: $uppercaseCode");

    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/verify'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": parsedUserId, "code": uppercaseCode}),
    );

    print("Verification Response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final token = responseData['token'];
      final userId = responseData['userId'].toString();

      await _authService.saveToken(token);
      await _authService.saveUserId(userId);

      Navigator.pop(context);
      setState(() {
        _isRegistering = false;
      });
      showSuccess(context, translations[widget.selectedLanguage]!['verificationSuccess']!);
    } else {
      String errorMessage;
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['message'] ?? translations[widget.selectedLanguage]!['invalidCode']!;
      } catch (_) {
        errorMessage = response.body.isNotEmpty ? response.body : translations[widget.selectedLanguage]!['invalidCode']!;
      }
      showFailed(context, errorMessage);
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String lang = _locale?.languageCode ?? 'en';
        Map<String, String> t = translations[lang] ?? translations['en']!;

        return AlertDialog(
          title: Text(t['verifyCodeTitle']!),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t['verifyCodeMessage']!),
              const SizedBox(height: 20),
              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: t['verifyCodeLabel'],
                  border: const OutlineInputBorder(),
                ),
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final code = _codeController.text.trim();
                if (code.length != 5) {
                  showWarning(context, t['fillFields']!);
                  return;
                }
                await _verifyCode(code);
                _codeController.clear();
              },
              child: Text(t['verifyButton']!),
            ),
          ],
        );
      },
    );
  }

  void _showContactUsDialog() async {
    print("Showing Contact Us Dialog at: ${DateTime.now().toLocal()} (EEST)");
    if (_isLoggedIn) {
      _supportUserIdController.text = _userId ?? '';
      _supportUsernameController.text = _username;
      _supportEmailController.text = _emailController.text;
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String lang = _locale?.languageCode ?? 'en';
        Map<String, String> t = translations[lang] ?? translations['en']!;

        return AlertDialog(
          title: Text(t['contactUsTitle']!),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t['contactUsMessage']!),
                const SizedBox(height: 20),
                _buildTextField(_supportUserIdController, t['userId']!),
                _buildTextField(_supportUsernameController, t['username']!),
                _buildTextField(_supportEmailController, t['email']!),
                _buildTextField(_supportSubjectController, t['subject']!),
                _buildTextField(_supportMessageController, t['message']!, isMultiline: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final userId = _supportUserIdController.text.trim();
                final username = _supportUsernameController.text.trim();
                final email = _supportEmailController.text.trim();
                final subject = _supportSubjectController.text.trim();
                final message = _supportMessageController.text.trim();

                if (userId.isEmpty && username.isEmpty && email.isEmpty) {
                  showWarning(context, t['atLeastOneRequired']!);
                  return;
                }
                if (subject.isEmpty || message.isEmpty) {
                  showWarning(context, t['fillFields']!);
                  return;
                }
                if (userId.isNotEmpty && int.tryParse(userId) == null) {
                  showWarning(context, 'User ID must be a valid number');
                  return;
                }

                await _submitContactMessage(userId, username, email, subject, message);
                _supportUserIdController.clear();
                _supportUsernameController.clear();
                _supportEmailController.clear();
                _supportSubjectController.clear();
                _supportMessageController.clear();
              },
              child: Text(t['submit']!),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitContactMessage(String userId, String username, String email, String subject, String message) async {
    try {
      final token = await _authService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final effectiveUserId = userId.isNotEmpty ? userId : (_isLoggedIn ? _userId : null);
      final effectiveUsername = username.isNotEmpty ? username : (_isLoggedIn ? _username : 'Not Specified');
      final effectiveEmail = email.isNotEmpty ? email : (_isLoggedIn ? _emailController.text : 'Not Specified');

      final requestBody = {
        'userId': effectiveUserId,
        'username': effectiveUsername,
        'email': effectiveEmail,
        'subject': subject,
        'message': message,
      };

      final response = await http.post(
        Uri.parse('https://localhost:7164/api/User/support/message'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        showSuccess(context, translations[widget.selectedLanguage]!['contactSuccess']!);
        Navigator.pop(context);
      } else {
        String errorMessage;
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? translations[widget.selectedLanguage]!['contactFailed']!;
        } catch (_) {
          errorMessage = response.body.isNotEmpty ? response.body : translations[widget.selectedLanguage]!['contactFailed']!;
        }
        showFailed(context, errorMessage);
      }
    } catch (e) {
      showFailed(context, translations[widget.selectedLanguage]!['contactFailed']!);
      print('Error submitting contact message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    String lang = _locale?.languageCode ?? 'en';
    Map<String, String> t = translations[lang] ?? translations['en']!;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://res.cloudinary.com/dshksou7u/image/upload/v1749132799/bawp-90-media-hd.jpg.asset.1744033531565_hpfgnm.webp'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black54,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Journey Beyond',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Explore the new Ferrari lineup.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Colors.white),
                        ),
                        child: const Text('Explore'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 60.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Image.network(
                          'https://res.cloudinary.com/dshksou7u/image/upload/v1749132078/logo-removebg-preview_rnkt6f.png',
                          height: 250,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _isRegistering ? t['createAccount']! : t['loginAccount']!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (_isRegistering)
                        _buildTextField(_emailController, t['email']!),
                      _buildTextField(_usernameController, t['username']!),
                      _buildTextField(_passwordController, t['password']!, isPassword: true),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isRegistering ? _registerUser : _loginUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            _isRegistering ? t['register']! : t['login']!,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (!_isRegistering) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _googleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'pictures/googlefavicon.jpg',
                                  height: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  t['googleSignIn']!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isRegistering = !_isRegistering;
                              });
                            },
                            child: Text(
                              _isRegistering ? t['alreadyHaveAccount']! : t['dontHaveAccount']!,
                              style: const TextStyle(
                                color: Colors.red,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showContactUsDialog,
                            child: Text(
                              t['contactUs']!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isPassword = false, bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLines: isMultiline ? 4 : 1,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey.shade800,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}