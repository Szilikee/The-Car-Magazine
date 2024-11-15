import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'CreateTopicPage.dart';  // Importáld a CreateTopicPage-t!

// Az összes többi kód itt következik...
import 'package:flutter/material.dart';

class CreateTopicPage extends StatefulWidget {
  @override
  _CreateTopicPageState createState() => _CreateTopicPageState();
}

class _CreateTopicPageState extends State<CreateTopicPage> {
  final TextEditingController _topicTitleController = TextEditingController();
  final TextEditingController _topicContentController = TextEditingController();

  // Az autentikált felhasználó tokenjét itt kellene lekérni (pl. SharedPreferences)
  // var _authToken = 'your_token';  // Token, amit a login során mentettél el

  Future<void> _createTopic() async {
    final title = _topicTitleController.text.trim();
    final content = _topicContentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields.')),
      );
      return;
    }

    // API hívás a fórumtéma létrehozásához
    final response = await http.post(
      Uri.parse('http://localhost:7164/api/forum/createTopic'),
      headers: {
        'Content-Type': 'application/json',
        // 'Authorization': 'Bearer $_authToken',  // Ha szükséges a token
      },
      body: json.encode({
        'title': title,
        'content': content,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topic created successfully!')),
      );
      _topicTitleController.clear();
      _topicContentController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create topic: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Topic'),
        backgroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTextField(_topicTitleController, 'Topic Title'),
            const SizedBox(height: 16),
            _buildTextField(_topicContentController, 'Topic Content'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _createTopic,
              child: const Text('Create Topic'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.blueGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.lightBlueAccent),
        ),
        filled: true,
        fillColor: Colors.black38,
      ),
    );
  }
}
