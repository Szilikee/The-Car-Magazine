import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'SubTopicDetailsPage.dart';
import 'Models.dart';
import 'Translations.dart';


class AccountPage extends StatefulWidget {
  final String selectedLanguage;
  const AccountPage({super.key, required this.selectedLanguage});

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _username = '';
  String _email = '';
  String _profileImageUrl =
      'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';
  String _bio = '';
  String _status = '';
  String _location = '';
  Map<String, String> _socialMediaLinks = {};
  DateTime? _registrationDate;
  int _postCount = 0;
  DateTime? _lastActivity;
  String _userRank = '';
  String _signature = '';
  Map<String, String> _personalLinks = {};
  List<String> _hobbies = [];
  List<Subtopic> _createdSubtopics = [];
  List<Post> _topPosts = [];
  String? _emailChangeRequestId; // Az email-változtatási kérés azonosítója
  final _emailVerificationCodeController = TextEditingController(); // Új vezérlő az email megerősítő kódhoz
  bool _showEmailVerificationInput = false; // Flag az email megerősítő mező megjelenítéséhez

  final _bioController = TextEditingController();
  final _statusController = TextEditingController();
  final _locationController = TextEditingController();
  final _signatureController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _twoFactorCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  bool _showTwoFactorInput = false;
  String? _passwordChangeRequestId;

  @override
  void initState() {
    super.initState();
      if (!translations.containsKey(widget.selectedLanguage)) {
    debugPrint('Érvénytelen nyelv: ${widget.selectedLanguage}, fallback: en');
  }
    _loadUserData();
    _loadCreatedTopics();
    _loadCreatedSubtopics();
    _loadTopPosts();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _statusController.dispose();
    _locationController.dispose();
    _signatureController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _twoFactorCodeController.dispose();
    _emailController.dispose();
    _emailVerificationCodeController.dispose();
    super.dispose();
  }


String _calculateUserRank(int postCount) {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  if (postCount <= 5) {
    return t['rankLearnerDriver'] ?? 'Learner Driver'; // Kezdő, még tanul
  } else if (postCount <= 10) {
    return t['rankCityDriver'] ?? 'City Driver'; // Alap tapasztalat
  } else if (postCount <= 25) {
    return t['rankHighwayCruiser'] ?? 'Highway Cruiser'; // Tapasztaltabb, sokat posztol
  } else if (postCount <= 50) {
    return t['rankTrackDayEnthusiast'] ?? 'Track Day Enthusiast'; // Haladó, aktív tag
  } else {
    return t['rankPitCrewChief'] ?? 'Pit Crew Chief'; // Szakértő, top szint
  }
}
 Future<void> _loadUserData() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    return;
  }

  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _username = data['username'] ?? 'Guest';
        _email = data['email'] ?? 'No email';
        _profileImageUrl = data['profileImageUrl'] ?? _profileImageUrl;
        _bio = data['bio'] ?? '';
        // Map status to valid dropdown values
        final rawStatus = data['status']?.toString().toLowerCase();
        _status = rawStatus == 'online' || rawStatus == 'true' ? 'Online' :
                  rawStatus == 'offline' || rawStatus == 'false' ? 'Offline' : '';
        _location = data['location'] ?? '';
        _socialMediaLinks = Map<String, String>.from(data['socialMediaLinks'] ?? {});
        _registrationDate = data['registrationDate'] != null ? DateTime.parse(data['registrationDate']) : null;
        _postCount = data['postCount'] ?? 0;
        _lastActivity = data['lastActivity'] != null ? DateTime.parse(data['lastActivity']) : null;
        _userRank = _calculateUserRank(_postCount);
        _signature = data['signature'] ?? '';
        _personalLinks = Map<String, String>.from(data['personalLinks'] ?? {});
        _hobbies = List<String>.from(data['hobbies'] ?? []);

        _bioController.text = _bio;
        _statusController.text = _status;
        _locationController.text = _location;
        _signatureController.text = _signature;
        _emailController.text = _email;
      });
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}

  Future<void> _loadCreatedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userID');

    if (token == null || userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/topics/created/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
        });
      }
    } catch (e) {
      _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
    }
  }

  Future<void> _loadCreatedSubtopics() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userID');

    if (token == null || userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/Forum/subtopics/created/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _createdSubtopics = data.map((json) => Subtopic.fromJson(json)).toList();
        });
      } else {
        _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
      }
    } catch (e) {
      debugPrint('Error loading subtopics: $e');
      _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
    }
  }

Future<void> _loadTopPosts() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) return;

  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/User/userdetails/$userId/top-posts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _topPosts = data.map((json) => Post.fromJson(json)).toList();
      });
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
    }
  } catch (e) {
    debugPrint('Error loading posts: $e');
    _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
  }
}
  Future<void> _pickImage() async {
    try {
      final pickedImage = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedImage != null) {
        setState(() => _image = pickedImage);
        final imageUrl = await _uploadImageToCloudinary();
        if (imageUrl != null) await _updateProfileImage(imageUrl);
      }
    } catch (e) {
      _showSnackBar(translations[widget.selectedLanguage]!['changeProfileImageFail']!, Colors.red);
    }
  }

  Future<String?> _uploadImageToCloudinary() async {
    if (_image == null) return null;

    const url = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..fields['api_key'] = '156576676194584'
      ..fields['upload_preset'] = 'marketplace_preset';

    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes('file', await _image!.readAsBytes(), filename: _image!.name));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
    }

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        return jsonDecode(responseData)['secure_url'];
      }
    } catch (e) {
      _showSnackBar(translations[widget.selectedLanguage]!['changeProfileImageFail']!, Colors.red);
    }
    return null;
  }

  Future<void> _updateProfileImage(String imageUrl) async {
    await _updateProfile({'profileImageUrl': imageUrl});
    if (mounted) setState(() => _profileImageUrl = imageUrl);
  }

  bool isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}


  Future<void> _updateProfile(Map<String, dynamic> updates) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/userdetails/update'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: json.encode({
        'userId': userId,
        'username': _username,
        'email': _email,
        'bio': _bioController.text,
        'status': _statusController.text,
        'profileImageUrl': _profileImageUrl,
        'location': _locationController.text,
        'socialMediaLinks': _socialMediaLinks,
        'userRank': _calculateUserRank(_postCount), // Use calculated rank
        'signature': _signatureController.text,
        'personalLinks': _personalLinks,
        'hobbies': _hobbies,
        ...updates,
      }),
    );
    if (!isValidEmail(_emailController.text)) {
      _showSnackBar('Invalid email format.', Colors.red);
      return;
    }
    if (response.statusCode == 200) {
      _showSnackBar(translations[widget.selectedLanguage]!['updateSuccess']!, Colors.green);
      setState(() {
        _bio = _bioController.text;
        _status = _statusController.text;
        _location = _locationController.text;
        _email = _emailController.text;
        _signature = _signatureController.text;
        _userRank = _calculateUserRank(_postCount); // Update local rank
      });
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['updateFailed']!, Colors.red);
    }
  } catch (e) {
    _showSnackBar(translations[widget.selectedLanguage]!['updateFailed']!, Colors.red);
  }
}

  void _showPasswordChangeDialog() {
  showDialog(
    context: context,
    builder: (context) => SettingsDialog(
      selectedLanguage: widget.selectedLanguage,
      bioController: _bioController,
      statusController: _statusController,
      locationController: _locationController,
      emailController: _emailController,
      signatureController: _signatureController,
      newPasswordController: _newPasswordController,
      confirmPasswordController: _confirmPasswordController,
      twoFactorCodeController: _twoFactorCodeController,
      emailVerificationCodeController: _emailVerificationCodeController,
      socialMediaLinks: _socialMediaLinks,
      personalLinks: _personalLinks,
      hobbies: _hobbies,
      showTwoFactorInput: _showTwoFactorInput,
      showEmailVerificationInput: _showEmailVerificationInput, // Add this
      onSave: (socialMedia, personalLinks, hobbies) {
        setState(() {
          _socialMediaLinks = socialMedia;
          _personalLinks = personalLinks;
          _hobbies = hobbies;
        });
        _updateProfile({});
      },
      onInitiatePasswordChange: _initiatePasswordChange,
      onVerifyPasswordChange: _verifyAndChangePassword,
      onInitiateEmailChange: _initiateEmailChange, // Add this
      onVerifyEmailChange: _verifyAndChangeEmail, // Add this
    ),
  );
}

 Future<void> _initiatePasswordChange() async {
  if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
    _showSnackBar(translations[widget.selectedLanguage]!['passwordsDoNotMatch']!, Colors.red);
    return;
  }
  if (_newPasswordController.text != _confirmPasswordController.text) {
    _showSnackBar(translations[widget.selectedLanguage]!['passwordsDoNotMatch']!, Colors.red);
    return;
  }
  if (_newPasswordController.text.length < 8) {
    _showSnackBar(translations[widget.selectedLanguage]!['passwordTooShort']!, Colors.red);
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    debugPrint('Hiba: Hiányzó token vagy userId.');
    return;
  }

  final requestBody = {
    'userId': userId,
    'newPassword': _newPasswordController.text,
  };
  debugPrint('Jelszóváltoztatási kérés: ${json.encode(requestBody)}');

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/password/change/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    debugPrint('Szerver válasza (Initiate): StatusCode: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final requestId = data['requestId'] as String?;
      if (requestId == null) {
        _showSnackBar('Hiba: A szerver nem küldött requestId-t.', Colors.red);
        debugPrint('Hiba: Hiányzó requestId a válaszban.');
        return;
      }
      setState(() {
        _showTwoFactorInput = true;
        _passwordChangeRequestId = requestId;
      });
      debugPrint('Mentett requestId: $requestId');
      _showSnackBar(translations[widget.selectedLanguage]!['codeSent']!, Colors.green);
      if (mounted) {
        Navigator.pop(context); // Bezárja az aktuális dialogot
        _showPasswordChangeDialog(); // Új dialog megnyitása a 2FA mezővel
      }
    } else {
      _showSnackBar('Failed to initiate password change: ${response.body}', Colors.red);
      debugPrint('Hiba az inicializálás során: ${response.body}');
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
    debugPrint('Kivétel: $e');
  }
}


Future<void> _verifyAndChangePassword() async {
  if (_twoFactorCodeController.text.isEmpty) {
    _showSnackBar(translations[widget.selectedLanguage]!['invalidCode']!, Colors.red);
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    debugPrint('Hiba: Hiányzó token vagy userId.');
    return;
  }

  final requestBody = {
    'userId': userId,
    'requestId': _passwordChangeRequestId,
    'code': _twoFactorCodeController.text,
    'newPassword': _newPasswordController.text, // Új jelszó elküldése
  };
  debugPrint('Küldött kérés (Verify): ${json.encode(requestBody)}');

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/password/change/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    debugPrint('Szerver válasza (Verify): StatusCode: ${response.statusCode}, Body: ${response.body}');

    if (response.statusCode == 200) {
      _showSnackBar(translations[widget.selectedLanguage]!['passwordChanged']!, Colors.green);
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Bezárja a dialogot
          if (Navigator.canPop(context)) {
            Navigator.pop(context); // Vissza az előző képernyőre
          }
        }
        _logout(); // Kijelentkezés a sikeres jelszóváltoztatás után
      } else {
        debugPrint('A dialog nem volt nyitva, vagy már bezárták.'); 
      }
    } else {
      String errorMessage = 'Failed to verify password change.';
      try {
        final responseData = json.decode(response.body);
        errorMessage = responseData['message'] ?? response.body;
      } catch (_) {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }
      _showSnackBar(errorMessage, Colors.red);
      debugPrint('Hiba a verifikáció során: $errorMessage');
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
    debugPrint('Kivétel: $e');
  }
}

Future<void> _initiateEmailChange(String newEmail) async {
  if (newEmail.isEmpty || !isValidEmail(newEmail)) {
    _showSnackBar(translations[widget.selectedLanguage]!['invalidEmail'] ?? 'Invalid email address', Colors.red);
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed'] ?? 'Please log in again', Colors.red);
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/email/change/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
        'newEmail': newEmail,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _emailChangeRequestId = data['requestId'];
        _showEmailVerificationInput = true;
      });
      _showSnackBar(translations[widget.selectedLanguage]!['codeSent'] ?? 'Verification code sent to your current email', Colors.green);
      Navigator.pop(context); // Bezárja az aktuális dialogot
      _showSettings(); // Új dialog megnyitása a megerősítő mezővel
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['emailChangeFailed'] ?? 'Failed to initiate email change', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}

Future<void> _verifyAndChangeEmail(String newEmail) async {
  if (_emailVerificationCodeController.text.isEmpty) {
    _showSnackBar(translations[widget.selectedLanguage]!['invalidCode'] ?? 'Please enter the verification code', Colors.red);
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed'] ?? 'Please log in again', Colors.red);
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/email/change/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
        'requestId': _emailChangeRequestId,
        'code': _emailVerificationCodeController.text,
        'newEmail': newEmail,
      }),
    );

    if (response.statusCode == 200) {
      _showSnackBar(translations[widget.selectedLanguage]!['emailChanged'] ?? 'Email changed successfully', Colors.green);
      setState(() {
        _email = newEmail;
        _emailController.text = newEmail;
        _showEmailVerificationInput = false;
        _emailChangeRequestId = null;
      });
      Navigator.pop(context); // Bezárja a dialogot
      _logout(); // Kijelentkezés a sikeres email-változtatás után
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['emailChangeFailed'] ?? 'Failed to verify email change', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
        (route) => false,
      );
    }
  }

void _showSettings() {
  showDialog(
    context: context,
    builder: (context) => SettingsDialog(
      selectedLanguage: widget.selectedLanguage,
      bioController: _bioController,
      statusController: _statusController,
      locationController: _locationController,
      emailController: _emailController,
      signatureController: _signatureController,
      newPasswordController: _newPasswordController,
      confirmPasswordController: _confirmPasswordController,
      twoFactorCodeController: _twoFactorCodeController,
      emailVerificationCodeController: _emailVerificationCodeController,
      socialMediaLinks: _socialMediaLinks,
      personalLinks: _personalLinks,
      hobbies: _hobbies,
      showTwoFactorInput: _showTwoFactorInput,
      showEmailVerificationInput: _showEmailVerificationInput, // Add this
      onSave: (socialMedia, personalLinks, hobbies) {
        setState(() {
          _socialMediaLinks = socialMedia;
          _personalLinks = personalLinks;
          _hobbies = hobbies;
        });
        _updateProfile({});
      },
      onInitiatePasswordChange: _initiatePasswordChange,
      onVerifyPasswordChange: _verifyAndChangePassword,
      onInitiateEmailChange: _initiateEmailChange, // Add this
      onVerifyEmailChange: _verifyAndChangeEmail, // Add this
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final String language = translations.containsKey(widget.selectedLanguage) 
        ? widget.selectedLanguage 
        : 'en'; // Fallback nyelv: angol
    final t = translations[language]!; // Biztonságos, mert a nyelv létezik
    final String imagePath = 'assets/pictures/backgroundimage.png';

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueGrey.shade900,
                        Colors.blueGrey.shade700,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
           // A build metódus AppBar részének módosítása
          appBar: AppBar(
            title: Text(
              t['AccountPageTitle']!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            backgroundColor: Colors.blueGrey[800],
            elevation: 4,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.support_agent, color: Colors.white70),
                onPressed: _showSupportDialog,
                tooltip: 'Contact Support',
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: _showSettings,
                tooltip: t['settings'],
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                onPressed: _logout,
                tooltip: t['logout'],
              ),
            ],
          ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileCard(),
                    const SizedBox(height: 18),
                    _buildInfoGrid(t),
                    const SizedBox(height: 18),
                    _buildSection(
                      '${t['subtopicsCreated']} (${_createdSubtopics.length})',
                      _createdSubtopics.isEmpty
                          ? Text(
                              t['noSubtopics']!,
                              style: const TextStyle(color: Colors.grey, fontSize: 15),
                            )
                          : SizedBox(
                              height: 150,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _createdSubtopics.length,
                                itemBuilder: (context, i) => _buildSubtopicCard(_createdSubtopics[i]),
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    _buildSection(
                      '${t['topPosts']} (${_topPosts.length})',
                      _topPosts.isEmpty
                          ? Text(
                              t['noPosts']!,
                              style: const TextStyle(color: Colors.grey, fontSize: 15),
                            )
                          : SizedBox(
                              height: 150,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _topPosts.length,
                                itemBuilder: (context, i) => _buildPostCard(_topPosts[i]),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800]!.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(_profileImageUrl),
                    onBackgroundImageError: (e, s) => debugPrint('Kép hiba: $e'),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


void _showSupportDialog() {
  showDialog(
    context: context,
    builder: (context) => SupportDialog(
      selectedLanguage: widget.selectedLanguage,
      username: _username,
      email: _email,
      onSubmit: _submitSupportTicket,
    ),
  );
}

// Support ticket beküldése
Future<void> _submitSupportTicket(String message) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    return;
  }

  if (message.trim().isEmpty) {
    _showSnackBar(translations[widget.selectedLanguage]!['enterMessage']!, Colors.red);
    return;
  }

  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/User/ticket'), // Helyes végpont
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
        'username': _username,
        'email': _email,
        'subject': 'Support Request',
        'message': message,
      }),
    );

    if (response.statusCode == 200) {
      _showSnackBar(translations[widget.selectedLanguage]!['ticketSuccess']!, Colors.green);
      Navigator.pop(context); // Dialog bezárása
    } else {
      // Részletesebb hibakezelés
      final errorMessage = json.decode(response.body)['error'] ?? translations[widget.selectedLanguage]!['ticketFailed'];
      _showSnackBar('$errorMessage)', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}


  Widget _buildInfoGrid(Map<String, String> t) {
    final items = [
      _buildInfoItem(t['bio']!, _bio.isEmpty ? 'N/A' : _bio, Icons.person, Colors.blueAccent),
      _buildInfoItem(t['status']!, _status.isEmpty ? 'N/A' : _status, Icons.tag, Colors.greenAccent),
      _buildInfoItem(t['location']!, _location.isEmpty ? 'N/A' : _location, Icons.location_on, Colors.redAccent),
      _buildInfoItem(t['email']!, _email.isEmpty ? 'N/A' : _email, Icons.email, Colors.purpleAccent),
      _buildInfoItem(t['registrationDate']!, _registrationDate?.toLocal().toString().split('.')[0] ?? 'N/A', Icons.calendar_today, Colors.amberAccent),
      _buildInfoItem(t['postCount']!, '$_postCount', Icons.post_add, Colors.tealAccent),
      _buildInfoItem(t['lastActivity']!, _lastActivity?.toLocal().toString().split('.')[0] ?? 'N/A', Icons.access_time, Colors.orangeAccent),
      _buildInfoItem(t['userRank']!, _userRank.isEmpty ? 'N/A' : _userRank, Icons.star, Colors.yellowAccent),
      _buildLinksItem(t['socialMedia']!, _socialMediaLinks),
      _buildInfoItem(t['signature']!, _signature.isEmpty ? 'N/A' : _signature, Icons.edit, Colors.cyanAccent),
      _buildLinksItem(t['personalLinks']!, _personalLinks),
      _buildHobbiesItem(t['hobbies']!, _hobbies),
    ];

    final firstRow = items.sublist(0, 6);
    final secondRow = items.sublist(6, 12);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: firstRow,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: secondRow,
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String content, IconData icon, Color iconColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: (MediaQuery.of(context).size.width - 80) / 6,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blueGrey[800]!.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 25),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(fontSize: 15, color: Colors.white70),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLinksItem(String title, Map<String, String> links) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: (MediaQuery.of(context).size.width - 80) / 6,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blueGrey[800]!.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.link, color: Colors.blueAccent, size: 25),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (links.isEmpty)
            const Text('N/A', style: TextStyle(fontSize: 15, color: Colors.white70))
          else
            Column(
              children: links.entries.take(2).map((e) {
                return GestureDetector(
                  onTap: () => _launchUrl(e.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHobbiesItem(String title, List<String> hobbies) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: (MediaQuery.of(context).size.width - 80) / 6,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blueGrey[800]!.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 25),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (hobbies.isEmpty)
            const Text('N/A', style: TextStyle(fontSize: 15, color: Colors.white70))
          else
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: hobbies.take(2).map((hobby) {
                return Chip(
                  label: Text(
                    hobby,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                  backgroundColor: Colors.blueGrey[700],
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[800]!.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildSubtopicCard(Subtopic subtopic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubtopicDetailsPage(
              subtopic: subtopic.toJson(),
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.blueGrey[700]!.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              subtopic.title,
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              subtopic.createdAt.toLocal().toString().split('.')[0],
              style: const TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[700]!.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            post.content.length > 60 ? '${post.content.substring(0, 60)}...' : post.content,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            post.createdAt.toLocal().toString().split('.')[0],
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot open: $url', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  final String selectedLanguage;
  final TextEditingController bioController, statusController, locationController, emailController, signatureController;
  final TextEditingController newPasswordController, confirmPasswordController, twoFactorCodeController;
  final Map<String, String> socialMediaLinks, personalLinks;
  final List<String> hobbies;
  final bool showTwoFactorInput;
  final void Function(Map<String, String>, Map<String, String>, List<String>) onSave;
  final VoidCallback onInitiatePasswordChange;
  final VoidCallback onVerifyPasswordChange;
  final TextEditingController emailVerificationCodeController;  
  final bool showEmailVerificationInput;
  final void Function(String) onInitiateEmailChange; // Add this
  final void Function(String) onVerifyEmailChange; // Add this

  const SettingsDialog({
    super.key,
    required this.selectedLanguage,
    required this.bioController,
    required this.statusController,
    required this.locationController,
    required this.emailController,
    required this.signatureController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.twoFactorCodeController,
    required this.emailVerificationCodeController,
    required this.socialMediaLinks,
    required this.personalLinks,
    required this.hobbies,
    required this.showTwoFactorInput,
    required this.showEmailVerificationInput,
    required this.onSave,
    required this.onInitiatePasswordChange,
    required this.onVerifyPasswordChange,
    required this.onInitiateEmailChange, // Add this
    required this.onVerifyEmailChange, // Add this
    
  });

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late Map<String, String> _socialMediaLinks, _personalLinks;
  late List<String> _hobbies;
  final _socialKey = TextEditingController();
  final _socialUrl = TextEditingController();
  final _personalKey = TextEditingController();
  final _personalUrl = TextEditingController();
  final _hobby = TextEditingController();

  @override
  void initState() {
    super.initState();
    _socialMediaLinks = Map.from(widget.socialMediaLinks);
    _personalLinks = Map.from(widget.personalLinks);
    _hobbies = List.from(widget.hobbies);
  }

  @override
  void dispose() {
    _socialKey.dispose();
    _socialUrl.dispose();
    _personalKey.dispose();
    _personalUrl.dispose();
    _hobby.dispose();
    super.dispose();
  }

  void _addSocialMediaLink() {
    if (_socialKey.text.isNotEmpty && _socialUrl.text.isNotEmpty) {
      setState(() {
        _socialMediaLinks[_socialKey.text] = _socialUrl.text;
        _socialKey.clear();
        _socialUrl.clear();
      });
    }
  }

  void _addPersonalLink() {
    if (_personalKey.text.isNotEmpty && _personalUrl.text.isNotEmpty) {
      setState(() {
        _personalLinks[_personalKey.text] = _personalUrl.text;
        _personalKey.clear();
        _personalUrl.clear();
      });
    }
  }

  void _addHobby() {
    if (_hobby.text.isNotEmpty) {
      setState(() {
        _hobbies.add(_hobby.text);
        _hobby.clear();
      });
    }
  }

@override
Widget build(BuildContext context) {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: Colors.blueGrey[900],
    title: Text(
      t['settings'] ?? 'Settings',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    content: SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(t['bio'] ?? 'Bio'),
            _buildTextField(widget.bioController, t['bio'] ?? 'Bio', Icons.person),
            const SizedBox(height: 8),
            _buildSectionHeader(t['status'] ?? 'Status'),
            DropdownButtonFormField<String>(
              value: ['Online', 'Offline'].contains(widget.statusController.text) ? widget.statusController.text : null,
              items: [
                DropdownMenuItem(
                  value: 'Online',
                  child: Text(t['statusOnline'] ?? 'Online', style: const TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: 'Offline',
                  child: Text(t['statusOffline'] ?? 'Offline', style: const TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  widget.statusController.text = value;
                }
              },
              decoration: InputDecoration(
                labelText: t['status'] ?? 'Status',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.tag, color: Colors.white70),
                filled: true,
                fillColor: Colors.blueGrey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
              dropdownColor: Colors.blueGrey[800],
              isExpanded: true,
            ),
            const SizedBox(height: 8),
            _buildSectionHeader(t['location'] ?? 'Location'),
            _buildTextField(widget.locationController, t['location'] ?? 'Location', Icons.location_on),
            const SizedBox(height: 8),
            _buildSectionHeader(t['signature'] ?? 'Signature'),
            _buildTextField(widget.signatureController, t['signature'] ?? 'Signature', Icons.edit),
            // Email change
            const SizedBox(height: 16),
            _buildSectionHeader(t['changeEmail'] ?? 'Change Email'),
            _buildTextField(widget.emailController, t['newEmail'] ?? 'New Email', Icons.email),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => widget.onInitiateEmailChange(widget.emailController.text),
              child: Text(t['requestEmailChange'] ?? 'Request Email Change', style: const TextStyle(color: Colors.white)),
            ),
            if (widget.showEmailVerificationInput) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(t['emailVerificationCode'] ?? 'Email Verification Code'),
              _buildTextField(widget.emailVerificationCodeController, t['emailVerificationCode'] ?? 'Verification Code', Icons.security),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => widget.onVerifyEmailChange(widget.emailController.text),
                child: Text(t['verifyAndChangeEmail'] ?? 'Verify and Change Email', style: const TextStyle(color: Colors.white)),
              ),
            ],
            // Password change
            const SizedBox(height: 16),
            _buildSectionHeader(t['changePassword'] ?? 'Change Password'),
            _buildTextField(widget.newPasswordController, t['newPassword'] ?? 'New Password', Icons.lock, obscureText: true),
            const SizedBox(height: 8),
            _buildTextField(widget.confirmPasswordController, t['confirmPassword'] ?? 'Confirm Password', Icons.lock, obscureText: true),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: widget.onInitiatePasswordChange,
              child: Text(t['requestPasswordChange'] ?? 'Request Password Change', style: const TextStyle(color: Colors.white)),
            ),
            if (widget.showTwoFactorInput) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(t['twoFactorCode'] ?? 'Two-Factor Code'),
              _buildTextField(widget.twoFactorCodeController, t['twoFactorCode'] ?? 'Two-Factor Code', Icons.security),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onVerifyPasswordChange,
                child: Text(t['verifyAndChange'] ?? 'Verify and Change Password', style: const TextStyle(color: Colors.white)),
              ),
            ],
            // Social media, links, hobbies
            const SizedBox(height: 16),
            _buildSectionHeader(t['socialMediaLinks'] ?? 'Social Media Links'),
            _buildSocialMediaInput(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _socialMediaLinks.entries.map((e) {
                return Chip(
                  label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.blueGrey[700],
                  deleteIcon: const Icon(Icons.delete, size: 16, color: Colors.white70),
                  onDeleted: () => setState(() => _socialMediaLinks.remove(e.key)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(t['personalLinks'] ?? 'Personal Links'),
            _buildLinkInput(_personalKey, _personalUrl, 'Name', 'URL', _addPersonalLink),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _personalLinks.entries.map((e) {
                return Chip(
                  label: Text('${e.key}: ${e.value}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.blueGrey[700],
                  deleteIcon: const Icon(Icons.delete, size: 16, color: Colors.white70),
                  onDeleted: () => setState(() => _personalLinks.remove(e.key)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader(t['hobbies'] ?? 'Hobbies'),
            _buildHobbyInput(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hobbies.map((hobby) {
                return Chip(
                  label: Text(hobby, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: Colors.blueGrey[700],
                  deleteIcon: const Icon(Icons.delete, size: 16, color: Colors.white70),
                  onDeleted: () => setState(() => _hobbies.remove(hobby)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          t['cancel'] ?? 'Cancel',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () {
          widget.onSave(_socialMediaLinks, _personalLinks, _hobbies);
          Navigator.pop(context);
        },
        child: Text(t['saveChanges'] ?? 'Save Changes', style: const TextStyle(color: Colors.white)),
      ),
    ],
  );
}
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.blueGrey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSocialMediaInput() {
    const platforms = ['Twitter', 'Facebook', 'Instagram', 'LinkedIn', 'Other'];
    String selectedPlatform = platforms.first;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            value: selectedPlatform,
            items: platforms.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedPlatform = value;
                  _socialKey.text = value == 'Other' ? '' : value;
                });
              }
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.blueGrey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            dropdownColor: Colors.blueGrey[800],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: _socialUrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'URL',
              filled: true,
              fillColor: Colors.blueGrey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _addSocialMediaLink,
        ),
      ],
    );
  }

  Widget _buildLinkInput(
    TextEditingController keyController,
    TextEditingController urlController,
    String keyLabel,
    String urlLabel,
    VoidCallback onAdd,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: keyController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: keyLabel,
              filled: true,
              fillColor: Colors.blueGrey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: urlLabel,
              filled: true,
              fillColor: Colors.blueGrey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: onAdd),
      ],
    );
  }

  Widget _buildHobbyInput() {
    return TextField(
      controller: _hobby,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: translations[widget.selectedLanguage]!['addHobby'],
        filled: true,
        fillColor: Colors.blueGrey[800],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _addHobby,
        ),
      ),
    );
  }
}

class SupportDialog extends StatefulWidget {
  final String selectedLanguage;
  final String username;
  final String email;
  final void Function(String) onSubmit;

  const SupportDialog({
    super.key,
    required this.selectedLanguage,
    required this.username,
    required this.email,
    required this.onSubmit,
  });

  @override
  _SupportDialogState createState() => _SupportDialogState();
}

class _SupportDialogState extends State<SupportDialog> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = translations[widget.selectedLanguage]!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.blueGrey[900],
      title: Text(
        t['contactSupport']!,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: t['supportMessage']!,
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.message, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.blueGrey[800],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t['cancel']!,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            widget.onSubmit(_messageController.text);
          },
          child: Text(t['submitTicket']!, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}