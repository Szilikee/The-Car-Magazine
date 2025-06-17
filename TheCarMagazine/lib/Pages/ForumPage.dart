import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'TopicDetailsPage.dart';

class ForumPage extends StatefulWidget {
  final String selectedLanguage;

  const ForumPage({
    super.key,
    required this.selectedLanguage,
  });
  
  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _filteredTopics = [];
  String _searchQuery = '';
  String imagePath = 'assets/pictures/backgroundimage.png'; // Ensure this image exists in your assets
  String selectedLanguage = 'en'; // Default language

  @override
  void initState() {
        fetchTopics();
    super.initState();

  }

  final Map<String, Map<String, String>> translations = {
    'en': {
      'forumPageTitle': 'Forum',
      'searchHint': 'Search topics...',
       },
    'hu': {
      'forumPageTitle': 'Fórum',
      'searchHint': 'Keresés témák között...',
    },
  };


Future<void> fetchTopics() async {
  try {
    final response = await http.get(Uri.parse('https://localhost:7164/api/forum/topics'));
    if (response.statusCode == 200 && mounted) {
      setState(() {
        _topics = List<Map<String, dynamic>>.from(json.decode(response.body));
        _filteredTopics = List.from(_topics);
      });
    } else {
      print('Error fetching topics: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception during fetchTopics: $e');
  }
}

  void _filterTopics(String query) {
    setState(() {
      _searchQuery = query;
      if (_searchQuery.isNotEmpty) {
        _filteredTopics = _topics.where((topic) {
          final topicTitle = topic['topic']?.toLowerCase() ?? '';
          return topicTitle.contains(_searchQuery.toLowerCase());
        }).toList();
      } else {
        _filteredTopics = List.from(_topics);
      }
    });
  }
 @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              imagePath, // Ensure this image exists in your assets
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.4),
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
              // Custom Title Bar
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
                      color: Colors.black.withOpacity(1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        translations[widget.selectedLanguage]?['forumPageTitle'] ?? 'Forum',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                  child: Column(
                    children: [
                      _buildSearchField(),
                      const SizedBox(height: 10),
                      _buildFeaturedText(),
                      const SizedBox(height: 10),
                      Expanded(child: _buildTopicsList()),
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


  Widget _buildSearchField() {
    return TextField(
      onChanged: _filterTopics,
      decoration: const InputDecoration(
        hintText: 'Search topics...',
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
        suffixIcon: Icon(Icons.search),
      ),
    );
  }

  Widget _buildFeaturedText() {
    return const Text(
      'Featured Topics',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

 Widget _buildTopicsList() {
  return ListView.builder(
    itemCount: _filteredTopics.length,
    itemBuilder: (context, index) {
      final topic = _filteredTopics[index];
      final title = topic['topic'] ?? 'N/A';
      final description = topic['description'] ?? 'No description';
      String formattedDate = 'N/A';

      final createdAt = topic['createdAt'];
      if (createdAt != null) {
        try {
          final parsedDate = DateTime.parse(createdAt.toString());
          formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
        } catch (e) {
          formattedDate = 'Invalid Date';
        }
      }

      return MouseRegion(
        onEnter: (_) => setState(() => _filteredTopics[index]['isHovered'] = true),
        onExit: (_) => setState(() => _filteredTopics[index]['isHovered'] = false),
        child: Opacity(
          opacity: _filteredTopics[index]['isHovered'] == true ? 1.0 : 0.8, // 20% átlátszóság (0.8) alapból, 0% (1.0) hover esetén
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.forum, color: Colors.blueAccent),
              title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TopicDetailsPage(topic: topic),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
}