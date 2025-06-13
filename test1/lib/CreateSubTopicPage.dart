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
  final String imagePath = 'assets/pictures/backgroundimage.png'; // Hardcoded background image

  return Scaffold(
    body: Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5), // Opacity set to 0.5
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) {
              // Fallback gradient if image fails to load
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
        // Content
        Column(
          children: [
            // Custom Title Bar with Back Button
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueGrey.shade900,
                    Colors.blueGrey.shade700,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Text(
                      _topicTitle != null ? 'Create Subtopic for $_topicTitle' : 'Create New Subtopic',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer to balance back button
                ],
              ),
            ),
            // Main Content
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Field
                      _buildTextField(_titleController, 'Subtopic Title'),
                      const SizedBox(height: 16),
                      // Description Field
                      _buildTextField(_descriptionController, 'Description', maxLines: 3),
                      const SizedBox(height: 20),
                      // Button or Loading Indicator
                      Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                              )
                            : ElevatedButton(
                                onPressed: _createSubtopic,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
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
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      filled: true,
      fillColor: Colors.blueGrey.shade700,
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