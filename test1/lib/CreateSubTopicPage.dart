import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';

class CreateSubtopicPage extends StatefulWidget {
  final int topicId;

  const CreateSubtopicPage({super.key, required this.topicId});

  @override
  _CreateSubtopicPageState createState() => _CreateSubtopicPageState();
}

class _CreateSubtopicPageState extends State<CreateSubtopicPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _topicTitle;

  @override
  void initState() {
    super.initState();
    _fetchTopic();
  }

  Future<void> _fetchTopic() async {
    try {
      final uri = Uri.parse('https://localhost:7164/api/forum/topics/${widget.topicId}');
      print('Fetching topic from: $uri');
      final response = await http.get(uri); // Időzítés eltávolítva

      print('Fetch Topic Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && mounted) {
        final topic = json.decode(response.body);
        setState(() {
          _topicTitle = topic['topic'];
        });
      } else if (mounted) {
        showFailed(context, 'Failed to fetch topic: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception while fetching topic: $e');
      if (mounted) {
        showFailed(context, 'Error fetching topic: $e');
      }
    }
  }

  Future<void> _createSubtopic() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final token = await _authService.getToken();

    print('Creating subtopic with title: $title, description: $description, topicId: ${widget.topicId}');
    print('Title length: ${title.length}, Description length: ${description.length}');
    print('Token: $token');

    if (title.isEmpty || description.isEmpty) {
      showWarning(context, 'Please fill in all fields.');
      return;
    }

    if (title.length > 255) {
      showWarning(context, 'Title must be 255 characters or less.');
      return;
    }

    if (token == null) {
      showFailed(context, 'You must be logged in to create a subtopic.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('https://localhost:7164/api/forum/topics/${widget.topicId}/subtopics');
      print('Request URL: $uri');
      print('Request Headers: {Content-Type: application/json, Authorization: Bearer $token}');
      print('Request Body: ${json.encode({'title': title, 'description': description})}');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': title,
          'description': description,
        }),
      ); // Időzítés eltávolítva

      print('Create Subtopic Response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201 && mounted) {
        showSuccess(context, 'Subtopic created successfully!');
        final responseBody = json.decode(response.body);
        final subtopicId = responseBody['id'];
        _titleController.clear();
        _descriptionController.clear();
        Navigator.pop(context, subtopicId);
      } else if (mounted) {
        showFailed(context, 'Failed to create subtopic: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception while creating subtopic: $e');
      if (mounted) {
        showFailed(context, 'Error creating subtopic: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        _topicTitle != null ? 'Create Subtopic for $_topicTitle' : 'Create New Subtopic',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.black87,
      elevation: 4,
    ),
    body: Center(
      child: Container(
        width: 350, // Kocka ablak szélessége
        padding: const EdgeInsets.all(20.0),
        margin: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: Colors.grey[900], // Sötét háttér a modern megjelenéshez
          borderRadius: BorderRadius.circular(15), // Lekerekített sarkok
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4), // Árnyék a mélységérzethez
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // A konténer csak akkora legyen, amekkora szükséges
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cím mező
            _buildTextField(_titleController, 'Subtopic Title'),
            const SizedBox(height: 16),
            // Leírás mező
            _buildTextField(_descriptionController, 'Description', maxLines: 3),
            const SizedBox(height: 20),
            // Gomb vagy betöltésjelző
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                    )
                  : ElevatedButton(
                      onPressed: _createSubtopic,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Create Subtopic',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
    backgroundColor: Colors.grey[850], // Sötét háttér a kontraszt érdekében
  );
}

Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white), // Fehér szöveg a sötét háttérhez
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.lightBlueAccent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: Colors.black54, // Enyhén világosabb sötét háttér a mezőknek
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
  );
}

@override
void dispose() {
  _titleController.dispose();
  _descriptionController.dispose();
  super.dispose();
}
}
void showFailed(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red),
  );
}

void showWarning(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.orange),
  );
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.green),
  );
}