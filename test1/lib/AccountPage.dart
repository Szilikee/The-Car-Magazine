import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'main.dart';

// Simple Topic model
class Topic {
  final int id;
  final String title;
  final DateTime createdAt;

  Topic({required this.id, required this.title, required this.createdAt});

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String _username = '';
  String _email = '';
  String _profileImageUrl =
      'https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_1280.png';
  String _bio = '';
  String _status = 'Aktív';
  List<Topic> _createdTopics = [];
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCreatedTopics();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('userID');

    print('Token: $token');
    print('UserID: $userId');

    if (token == null || token.isEmpty || userId == null) {
      _showSnackBar('User not logged in.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/userdetails/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('User Details Response Status Code: ${response.statusCode}');
      print('User Details Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _username = data['username'] ?? 'Guest';
          _email = data['email'] ?? 'No email';
          _profileImageUrl = data['profileImageUrl'] ?? _profileImageUrl;
          _bio = data['bio'] ?? 'No bio available';
          _status = data['status'] ?? 'Unknown';
          _bioController.text = _bio;
          _statusController.text = _status;
        });
      } else {
        _showSnackBar('Error loading user data: ${response.body}');
        print('Error: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Request failed: $e');
      print('Request failed: $e');
    }
  }

  Future<void> _loadCreatedTopics() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? userId = prefs.getString('userID');

    if (token == null || userId == null) {
      _showSnackBar('User not logged in.');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/topics/created/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Topics Response Status Code: ${response.statusCode}');
      print('Topics Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _createdTopics = data.map((json) => Topic.fromJson(json)).toList();
        });
      } else {
        _showSnackBar('Error loading topics: ${response.body}');
        print('Error: ${response.body}');
      }
    } catch (e) {
      _showSnackBar('Failed to load topics: $e');
      print('Failed to load topics: $e');
    }
  }

  Future<void> _changeProfileImage() async {
    if (kIsWeb) {
      _showSnackBar('Image picking is not supported on web.');
      return;
    }
  }

  Future<void> _updateProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userId = prefs.getString('userID');

    if (token == null || userId == null) {
      _showSnackBar('User not logged in.');
      return;
    }

    final response = await http.post(
      Uri.parse('https://localhost:7164/api/forum/userdetails/update'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'userId': userId,
        'username': _username,
        'email': _email,
        'bio': _bioController.text,
        'status': _statusController.text,
      }),
    );

    if (response.statusCode == 200) {
      _showSnackBar('Profile updated successfully!');
      setState(() {
        _bio = _bioController.text;
        _status = _statusController.text;
      });
    } else {
      _showSnackBar('Error: ${response.body}');
      print('Error: ${response.body}');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (Route<dynamic> route) => false,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings'),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _changeProfileImage,
                child: CircleAvatar(
                  radius: 55,
                  backgroundImage: NetworkImage(_profileImageUrl),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _username,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _email,
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(
                'Bio: $_bio',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Topics Created (${_createdTopics.length}):',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _createdTopics.isEmpty
                  ? const Text(
                      'No topics created yet.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    )
                  : Column(
                      children: _createdTopics
                          .map((topic) => ListTile(
                                title: Text(
                                  topic.title,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  'Created: ${topic.createdAt.toLocal().toString().split('.')[0]}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ))
                          .toList(),
                    ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _statusController,
                label: 'Status',
                icon: Icons.tag,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _updateProfileData,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueGrey),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.black45,
      ),
    );
  }
}