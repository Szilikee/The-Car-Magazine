import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_car_forum/Pages/ListingDetails.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../Services/auth_service.dart';
import '../main.dart';
import 'SubTopicDetailsPage.dart';
import '../Models/Models.dart';
import '../Utils/Translations.dart';
import '../Utils/rank_utils.dart';


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
  String? _emailChangeRequestId;
  bool _showEmailVerificationInput = false;
  List<CarListing> _myCarListings = [];
  XFile? _image;
  bool _showTwoFactorInput = false;
  String? _passwordChangeRequestId;

  final _bioController = TextEditingController();
  final _emailVerificationCodeController = TextEditingController();
  final _statusController = TextEditingController();
  final _locationController = TextEditingController();
  final _signatureController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _twoFactorCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _picker = ImagePicker();



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
    _loadMyCarListings();
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



String _translateUserRank(String rawRank) {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  // Kezeljük a régi 'Újonc' értéket
  if (rawRank == 'Újonc') {
    return t['rankLearnerDriver'] ?? 'Learner Driver';
  }
  // A backend értékei alapján fordítunk
  switch (rawRank) {
    case 'Learner Driver':
      return t['rankLearnerDriver'] ?? 'Learner Driver';
    case 'City Driver':
      return t['rankCityDriver'] ?? 'City Driver';
    case 'Highway Cruiser':
      return t['rankHighwayCruiser'] ?? 'Highway Cruiser';
    case 'Track Day Enthusiast':
      return t['rankTrackDayEnthusiast'] ?? 'Track Day Enthusiast';
    case 'Pit Crew Chief':
      return t['rankPitCrewChief'] ?? 'Pit Crew Chief';
    default:
      return t['rankLearnerDriver'] ?? 'Learner Driver'; // Fallback
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
        _userRank = _translateUserRank(data['userRank'] ?? 'Learner Driver');
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

Future<void> _deleteCarListing(int id) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null) {
    _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
    return;
  }

  try {
    final response = await http.delete(
      Uri.parse('https://localhost:7164/api/marketplace/carlistings/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      setState(() {
        _myCarListings.removeWhere((listing) => listing.id == id);
      });
      _showSnackBar(translations[widget.selectedLanguage]!['listingDeleted'] ?? 'Listing deleted!', Colors.green);
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['deleteFailed'] ?? 'Failed to delete.', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
}

void _showEditCarListingDialog(CarListing listing) {
  showDialog(
    context: context,
    builder: (context) => CarListingEditDialog(
      selectedLanguage: widget.selectedLanguage,
      listing: listing,
      onSave: (updatedListing) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');

        if (token == null) {
          _showSnackBar(translations[widget.selectedLanguage]!['loginFailed']!, Colors.red);
          return;
        }

        try {
          final response = await http.put(
            Uri.parse('https://localhost:7164/api/marketplace/carlistings/${listing.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(updatedListing.toJson()),
          );

          if (response.statusCode == 200) {
            setState(() {
              _myCarListings = _myCarListings.map((l) => l.id == listing.id ? updatedListing : l).toList();
            });
            _showSnackBar(translations[widget.selectedLanguage]!['listingUpdated'] ?? 'Listing updated!', Colors.green);
            Navigator.pop(context);
          } else {
            _showSnackBar(translations[widget.selectedLanguage]!['updateFailed'] ?? 'Failed to update.', Colors.red);
          }
        } catch (e) {
          _showSnackBar('Error: $e', Colors.red);
        }
      },
    ),
  );
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
        // A _userRank frissítése külön lekérdezéssel történik
      });
      // Frissítsük a userRank értéket a backendtól
      await _loadUserData();
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
        MaterialPageRoute(builder: (context) => MainPage(authService: AuthService())),
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
                    _buildSection(
                    '${t['myCarListings'] ?? 'My Car Listings'} (${_myCarListings.length})',
                    _myCarListings.isEmpty
                        ? Text(
                            t['noCarListings'] ?? 'No car listings created.',
                            style: const TextStyle(color: Colors.grey, fontSize: 15),
                          )
                        : SizedBox(
                            height: 270,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _myCarListings.length,
                              itemBuilder: (context, i) => _buildCarListingCard(_myCarListings[i]),
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

Widget _buildCarListingCard(CarListing listing) {
  return GestureDetector(
    onTap: () {
      // Convert CarListing to Car
      final car = Car(
        id: listing.id,
        title: listing.name,
        year: listing.year,
        price: listing.sellingPrice,
        mileage: listing.kmDriven,
        fuel: listing.fuel,
        sellerType: listing.sellerType,
        transmission: listing.transmission,
        contact: listing.contact,
        imagePath: listing.imageUrl!,
        // Map other required fields if necessary
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListingDetailsPage(car: car),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: listing.imageUrl!.isNotEmpty
                ? Image.network(
                    listing.imageUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 120,
                      color: Colors.grey,
                      child: const Icon(Icons.error, color: Colors.white),
                    ),
                  )
                : Container(
                    height: 200,
                    color: Colors.grey,
                    child: const Icon(Icons.image, color: Colors.white),
                  ),
          ),
          const SizedBox(height: 15),
          Text(
            listing.name,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '\$${listing.sellingPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 25),
                onPressed: () => _showEditCarListingDialog(listing),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 25),
                onPressed: () => _deleteCarListing(listing.id),
              ),
            ],
          ),
        ],
      ),
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
                    border: Border.all(color: getRankColor(_userRank), width: 2), // Rang alapú szín
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
          style: TextStyle(
            fontSize: 15,
            color: title == (translations[widget.selectedLanguage]!['userRank'] ?? 'Rank')
                ? getRankColor(content, language: widget.selectedLanguage)
                : Colors.white70,
          ),
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

Future<void> _loadMyCarListings() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final userId = prefs.getString('userID');

  if (token == null || userId == null) return;

  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/marketplace/my-listings'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      setState(() {
        _myCarListings = data.map((json) => CarListing.fromJson(json)).toList();
      });
    } else {
      _showSnackBar(translations[widget.selectedLanguage]!['errorLoadingData']!, Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error: $e', Colors.red);
  }
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
class CarListingEditDialog extends StatefulWidget {
  final String selectedLanguage;
  final CarListing listing;
  final void Function(CarListing) onSave;

  const CarListingEditDialog({
    super.key,
    required this.selectedLanguage,
    required this.listing,
    required this.onSave,
  });

  @override
  _CarListingEditDialogState createState() => _CarListingEditDialogState();
}

class _CarListingEditDialogState extends State<CarListingEditDialog> {
  // Controllers for text fields
  late TextEditingController nameController;
  late TextEditingController yearController;
  late TextEditingController priceController;
  late TextEditingController kmController;
  late TextEditingController contactController;
  late TextEditingController vinController;
  late TextEditingController engineCapacityController;
  late TextEditingController horsepowerController;
  late TextEditingController bodyTypeController;
  late TextEditingController customColorController;
  late TextEditingController descriptionController;

  // Dropdown values
  String? selectedFuel;
  String? selectedSellerType;
  String? selectedTransmission;
  String? selectedColor;
  String? selectedCondition;
  String? selectedSteeringSide;
  String? selectedRegistrationStatus;
  String? selectedNumberOfDoors;

  // Dropdown options
  final List<String> fuelOptions = ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid'];
  final List<String> sellerTypeOptions = ['Private Person', 'Dealer'];
  final List<String> transmissionOptions = ['Manual', 'Automatic'];
  final List<String> colorOptions = ['White', 'Black', 'Gray', 'Red', 'Blue', 'Green', 'Other'];
  final List<String> conditionOptions = ['New', 'Used'];
  final List<String> steeringSideOptions = ['Left Side', 'Right Side'];
  final List<String> registrationStatusOptions = ['Registered', 'Unregistered'];
  final List<String> numberOfDoorsOptions = ['2', '3', '4', '5'];

  // Image handling
  final List<XFile?> _images = [null, null, null, null, null]; // Store up to 5 images
  final List<Uint8List?> _imageBytes = [null, null, null, null, null]; // For web image bytes
  final ImagePicker _picker = ImagePicker();
  List<String?> _imageUrls = [null, null, null, null, null]; // Store Cloudinary URLs
  final List<bool> _isUploadingImages = [false, false, false, false, false]; // Image upload states
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing listing data
    nameController = TextEditingController(text: widget.listing.name);
    yearController = TextEditingController(text: widget.listing.year.toString());
    priceController = TextEditingController(text: widget.listing.sellingPrice.toString());
    kmController = TextEditingController(text: widget.listing.kmDriven.toString());
    contactController = TextEditingController(text: widget.listing.contact);
    vinController = TextEditingController(text: widget.listing.vin ?? '');
    engineCapacityController = TextEditingController(text: widget.listing.engineCapacity?.toString() ?? '');
    horsepowerController = TextEditingController(text: widget.listing.horsepower?.toString() ?? '');
    bodyTypeController = TextEditingController(text: widget.listing.bodyType ?? '');
    customColorController = TextEditingController(text: widget.listing.color == 'Other' ? widget.listing.color : '');
    descriptionController = TextEditingController(text: widget.listing.description ?? '');

    // Initialize dropdowns
    selectedFuel = fuelOptions.contains(widget.listing.fuel) ? widget.listing.fuel : null;
    selectedSellerType = sellerTypeOptions.contains(widget.listing.sellerType) ? widget.listing.sellerType : null;
    selectedTransmission = transmissionOptions.contains(widget.listing.transmission) ? widget.listing.transmission : null;
    selectedColor = colorOptions.contains(widget.listing.color) ? widget.listing.color : 'Other';
    selectedCondition = conditionOptions.contains(widget.listing.condition) ? widget.listing.condition : null;
    selectedSteeringSide = steeringSideOptions.contains(widget.listing.steeringSide) ? widget.listing.steeringSide : null;
    selectedRegistrationStatus = registrationStatusOptions.contains(widget.listing.registrationStatus) ? widget.listing.registrationStatus : null;
    selectedNumberOfDoors = widget.listing.numberOfDoors?.toString();

    // Initialize image URLs
    _imageUrls = [
      widget.listing.imageUrl!.isNotEmpty ? widget.listing.imageUrl : null,
      widget.listing.imageUrl2?.isNotEmpty == true ? widget.listing.imageUrl2 : null,
      widget.listing.imageUrl3?.isNotEmpty == true ? widget.listing.imageUrl3 : null,
      widget.listing.imageUrl4?.isNotEmpty == true ? widget.listing.imageUrl4 : null,
      widget.listing.imageUrl5?.isNotEmpty == true ? widget.listing.imageUrl5 : null,
    ];
  }

  @override
  void dispose() {
    // Dispose controllers
    nameController.dispose();
    yearController.dispose();
    priceController.dispose();
    kmController.dispose();
    contactController.dispose();
    vinController.dispose();
    engineCapacityController.dispose();
    horsepowerController.dispose();
    bodyTypeController.dispose();
    customColorController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  // Function to pick an image for a specific index
  Future<void> _pickImage(int index) async {
    if (index < 0 || index >= 5) return;
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _images[index] = pickedFile;
          _imageBytes[index] = bytes;
          _imageUrls[index] = null; // Reset URL until uploaded
        });
      } else {
        setState(() {
          _images[index] = pickedFile;
          _imageUrls[index] = null; // Reset URL until uploaded
        });
      }
    }
  }

  // Function to upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary(XFile? image, int index) async {
    if (image == null) return null;

    setState(() => _isUploadingImages[index] = true);

    const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
    const String apiKey = '156576676194584'; // Use same API key as in _uploadImageToCloudinary
    const String uploadPreset = 'marketplace_preset'; // Use same preset

    try {
      var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
      request.fields['api_key'] = apiKey;
      request.fields['upload_preset'] = uploadPreset;
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          await image.readAsBytes(),
          filename: image.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', image.path));
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        var jsonData = jsonDecode(responseData);
        return jsonData['secure_url'];
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Image upload error: $e', Colors.red);
      return null;
    } finally {
      setState(() => _isUploadingImages[index] = false);
    }
  }

  // Function to save the updated listing
  Future<void> _saveListing() async {
    final t = translations[widget.selectedLanguage] ?? translations['en']!;

    if (nameController.text.isEmpty ||
        yearController.text.isEmpty ||
        priceController.text.isEmpty ||
        kmController.text.isEmpty ||
        contactController.text.isEmpty ||
        selectedFuel == null ||
        selectedSellerType == null ||
        selectedTransmission == null ||
        selectedNumberOfDoors == null) {
      _showSnackBar(t['fillAllFields'] ?? 'All required fields must be filled!', Colors.red);
      return;
    }

    final year = int.tryParse(yearController.text);
    final price = double.tryParse(priceController.text);
    final kmDriven = int.tryParse(kmController.text);
    if (year == null || price == null || kmDriven == null) {
      _showSnackBar(t['invalidNumber'] ?? 'Invalid number format!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload new images
      for (int i = 0; i < _images.length; i++) {
        if (_images[i] != null && _imageUrls[i] == null) {
          _imageUrls[i] = await _uploadImageToCloudinary(_images[i], i);
          if (_imageUrls[i] == null) {
            _showSnackBar('${t['imageUploadFailed'] ?? 'Failed to upload image'} ${i + 1}', Colors.red);
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      final updatedListing = CarListing(
        id: widget.listing.id,
        userId: widget.listing.userId,
        name: nameController.text,
        year: year,
        sellingPrice: price,
        kmDriven: kmDriven,
        fuel: selectedFuel!,
        sellerType: selectedSellerType!,
        transmission: selectedTransmission!,
        contact: contactController.text,
        imageUrl: _imageUrls[0] ?? '',
        imageUrl2: _imageUrls[1],
        imageUrl3: _imageUrls[2],
        imageUrl4: _imageUrls[3],
        imageUrl5: _imageUrls[4],
        vin: vinController.text.isEmpty ? null : vinController.text,
        engineCapacity: int.tryParse(engineCapacityController.text),
        horsepower: int.tryParse(horsepowerController.text),
        bodyType: bodyTypeController.text.isEmpty ? null : bodyTypeController.text,
        color: selectedColor == 'Other' ? customColorController.text : selectedColor,
        numberOfDoors: int.tryParse(selectedNumberOfDoors ?? '') ?? 0,
        condition: selectedCondition,
        steeringSide: selectedSteeringSide,
        registrationStatus: selectedRegistrationStatus,
        description: descriptionController.text.isEmpty ? null : descriptionController.text,
      );

      widget.onSave(updatedListing);
    } catch (e) {
      _showSnackBar('${t['error'] ?? 'Error'}: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
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

 @override
Widget build(BuildContext context) {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    backgroundColor: Colors.blueGrey[900],
    title: Text(
      t['editListing'] ?? 'Edit Car Listing',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    content: SingleChildScrollView(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(nameController, t['carName'] ?? 'Car Name'),
            _buildTextField(yearController, t['year'] ?? 'Year', isNumber: true),
            _buildTextField(priceController, t['price'] ?? 'Selling Price (€)', isNumber: true),
            _buildTextField(kmController, t['mileage'] ?? 'Kilometers Driven', isNumber: true),
            _buildDropdownField(
              label: t['fuel'] ?? 'Fuel Type',
              value: selectedFuel,
              items: fuelOptions,
              onChanged: (value) => setState(() => selectedFuel = value),
            ),
            _buildDropdownField(
              label: t['sellerType'] ?? 'Seller Type',
              value: selectedSellerType,
              items: sellerTypeOptions,
              onChanged: (value) => setState(() => selectedSellerType = value),
            ),
            _buildDropdownField(
              label: t['transmission'] ?? 'Transmission',
              value: selectedTransmission,
              items: transmissionOptions,
              onChanged: (value) => setState(() => selectedTransmission = value),
            ),
            _buildTextField(contactController, t['contact'] ?? 'Contact (Phone/Email)'),
            _buildTextField(vinController, t['vin'] ?? 'VIN (Optional)'),
            _buildTextField(engineCapacityController, t['engineCapacity'] ?? 'Engine Capacity (cm³)', isNumber: true),
            _buildTextField(horsepowerController, t['horsepower'] ?? 'Horsepower (CP)', isNumber: true),
            _buildTextField(bodyTypeController, t['bodyType'] ?? 'Body Type (Optional)'),
            _buildDropdownField(
              label: t['color'] ?? 'Color',
              value: selectedColor,
              items: colorOptions,
              onChanged: (value) => setState(() {
                selectedColor = value;
                if (value != 'Other') customColorController.clear();
              }),
            ),
            if (selectedColor == 'Other')
              _buildTextField(customColorController, t['customColor'] ?? 'Custom Color (Optional)'),
            _buildDropdownField(
              label: t['numberOfDoors'] ?? 'Number of Doors',
              value: selectedNumberOfDoors,
              items: numberOfDoorsOptions,
              onChanged: (value) => setState(() => selectedNumberOfDoors = value),
            ),
            _buildDropdownField(
              label: t['condition'] ?? 'Condition',
              value: selectedCondition,
              items: conditionOptions,
              onChanged: (value) => setState(() => selectedCondition = value),
            ),
            _buildDropdownField(
              label: t['steeringSide'] ?? 'Steering Side',
              value: selectedSteeringSide,
              items: steeringSideOptions,
              onChanged: (value) => setState(() => selectedSteeringSide = value),
            ),
            _buildDropdownField(
              label: t['registrationStatus'] ?? 'Registration Status',
              value: selectedRegistrationStatus,
              items: registrationStatusOptions,
              onChanged: (value) => setState(() => selectedRegistrationStatus = value),
            ),
            _buildTextField(descriptionController, t['description'] ?? 'Description (Optional)', maxLines: 5),
            const SizedBox(height: 20),
            // Changed from Row to Column for vertical stacking
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      _images[index] != null
                          ? Stack(
                              children: [
                                Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: kIsWeb
                                        ? Image.memory(
                                            _imageBytes[index]!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 50,
                                            ),
                                          )
                                        : Image.file(
                                            io.File(_images[index]!.path),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 50,
                                            ),
                                          ),
                                  ),
                                ),
                                if (_isUploadingImages[index])
                                  const Positioned.fill(
                                    child: Center(
                                      child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
                                    ),
                                  ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _images[index] = null;
                                        _imageBytes[index] = null;
                                        _imageUrls[index] = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          : _imageUrls[index] != null
                              ? Stack(
                                  children: [
                                    Container(
                                      height: 100,
                                      width: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          _imageUrls[index]!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 50,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _imageUrls[index] = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  height: 100,
                                  width: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _pickImage(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(t['pickImage'] ?? 'Pick Image ${index + 1}', style: const TextStyle(fontSize: 14)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t['cancel'] ?? 'Cancel', style: const TextStyle(color: Colors.white70)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isLoading ? null : _saveListing,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(t['save'] ?? 'Save', style: const TextStyle(color: Colors.white)),
      ),
    ],
  );
}

  // Text field builder
  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.blueGrey[800],
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // Dropdown field builder
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.blueGrey[800],
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        style: const TextStyle(color: Colors.white),
        dropdownColor: Colors.blueGrey[800],
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}