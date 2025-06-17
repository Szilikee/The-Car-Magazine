import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../Services/auth_service.dart';
import 'SubTopicDetailsPage.dart';
import 'CreateSubTopicPage.dart';

class TopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> topic;

  const TopicDetailsPage({super.key, required this.topic});

  @override
  _TopicDetailsPageState createState() => _TopicDetailsPageState();
}

class _TopicDetailsPageState extends State<TopicDetailsPage> {
  List<Map<String, dynamic>> _subtopics = [];
  List<Map<String, dynamic>> _filteredSubtopics = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _sortOption = 'Newest First';
  bool _hasInitialized = false;


  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSubtopics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialized) {
      _hasInitialized = true;
      _initializeData();
    }
  }

  Future<void> _initializeData() async {
    await _checkLoginStatus();
    await _fetchSubtopics();
  }

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authService.isUserLoggedIn();
    if (mounted) setState(() => _isLoggedIn = loggedIn);
  }

   Future<void> _fetchSubtopics() async {
    final topicId = widget.topic['id'];
    debugPrint('Fetching subtopics for topicId: $topicId'); // Naplózás hozzáadása
    if (topicId == null) {
      showFailed(context, 'Invalid topic ID');
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse('https://localhost:7164/api/forum/topics/$topicId/subtopics'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      debugPrint('Fetch subtopics response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && mounted) {
        List<Map<String, dynamic>> subtopics = List<Map<String, dynamic>>.from(json.decode(response.body));
        for (var subtopic in subtopics) {
          final userId = subtopic['userId'];
          if (userId != null) {
            try {
              final userResponse = await http.get(
                Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
                headers: {
                  if (token != null) 'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              );
              debugPrint('Fetch user details for userId $userId: ${userResponse.statusCode}');
              if (userResponse.statusCode == 200) {
                final userData = json.decode(userResponse.body);
                final profileImageUrl = userData['profileImageUrl'] ?? '';
                subtopic['profile_image_url'] = profileImageUrl;
              } else {
                subtopic['profile_image_url'] = '';
              }
            } catch (e) {
              debugPrint('Error fetching user details for userId $userId: $e');
              subtopic['profile_image_url'] = '';
            }
          } else {
            subtopic['profile_image_url'] = '';
          }
        }
        if (mounted) {
          setState(() {
            _subtopics = subtopics;
            _filteredSubtopics = List.from(_subtopics);
            _sortSubtopics();
            _isLoading = false;
          });
        }
      } else {
        showFailed(context, 'Failed to load subtopics: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching subtopics: $e');
      showFailed(context, 'Error fetching subtopics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortSubtopics() {
    _filteredSubtopics.sort((a, b) {
      if (_sortOption == 'Newest First') {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      } else if (_sortOption == 'Oldest First') {
        final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
        return dateA.compareTo(dateB);
      } else if (_sortOption == 'Title A-Z') {
        final titleA = a['title']?.toString().toLowerCase() ?? '';
        final titleB = b['title']?.toString().toLowerCase() ?? '';
        return titleA.compareTo(titleB);
      } else {
        final titleA = a['title']?.toString().toLowerCase() ?? '';
        final titleB = b['title']?.toString().toLowerCase() ?? '';
        return titleB.compareTo(titleA);
      }
    });
  }

  void _filterSubtopics() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSubtopics = List.from(_subtopics);
      } else {
        _filteredSubtopics = _subtopics.where((subtopic) {
          final title = subtopic['title']?.toString().toLowerCase() ?? '';
          final description = subtopic['description']?.toString().toLowerCase() ?? '';
          return title.contains(query) || description.contains(query);
        }).toList();
      }
      _sortSubtopics();
    });
  }

 @override
Widget build(BuildContext context) {
  final String imagePath = 'assets/pictures/backgroundimage.png';

  return Scaffold(
    body: Stack(
      children: [
        // Háttérkép
        Positioned.fill(
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) => Container(
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
            ),
          ),
        ),
        // Tartalom
        Column(
          children: [
            // Címsor vissza gombokkal
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
                      widget.topic['topic'] ?? 'Topic Details',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Hely a vissza gomb egyensúlyozására
                ],
              ),
            ),
            // Fő tartalom
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category: ${widget.topic['category'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.topic['description'] ?? 'No description',
                      style: TextStyle(fontSize: 16, color: Colors.grey[200]),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtopics',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_isLoggedIn)
                          ElevatedButton(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateSubtopicPage(
                                    topicId: widget.topic['id'],
                                    selectedLanguage: "en",
                                  ),
                                ),
                              );
                              if (result == true && mounted) {
                                await _fetchSubtopics();
                                showSuccess(context, 'Subtopic created successfully');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.tealAccent,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Create New Subtopic',
                              style: TextStyle(fontSize: 14, color: Colors.black),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search subtopics by title or description...',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(Icons.search, color: Colors.tealAccent),
                              filled: true,
                              fillColor: Colors.blueGrey.shade700,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueGrey.shade700,
                                Colors.blueGrey.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortOption,
                              dropdownColor: Colors.blueGrey.shade800,
                              icon: const Icon(Icons.sort, color: Colors.tealAccent),
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              items: ['Newest First', 'Oldest First', 'Title A-Z', 'Title Z-A']
                                  .map((String value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _sortOption = value;
                                    _sortSubtopics();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                        : _filteredSubtopics.isEmpty
                            ? Text('No subtopics found', style: TextStyle(color: Colors.grey[400]))
                            : Expanded(
                                child: ListView.builder(
                                  itemCount: _filteredSubtopics.length,
                                  itemBuilder: (context, index) {
                                    final subtopic = _filteredSubtopics[index];
                                    final title = subtopic['title'] ?? 'No title';
                                    final description = subtopic['description'] != null
                                        ? subtopic['description'].length > 50
                                            ? '${subtopic['description'].substring(0, 50)}...'
                                            : subtopic['description']
                                        : 'No description';
                                    String formattedDate = 'N/A';
                                    if (subtopic['createdAt'] != null) {
                                      try {
                                        final parsedDate = DateTime.parse(subtopic['createdAt']);
                                        formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);
                                      } catch (e) {
                                        debugPrint('Date parsing error: ${subtopic['createdAt']} - $e');
                                      }
                                    }
                                    return Card(
                                      elevation: 2,
                                      color: Colors.blueGrey.shade900.withOpacity(0.9),
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        leading: CircleAvatar(
                                          radius: 14,
                                          backgroundImage: subtopic['profile_image_url'] != null &&
                                                  subtopic['profile_image_url'].isNotEmpty
                                              ? NetworkImage(subtopic['profile_image_url'])
                                              : null,
                                          backgroundColor: Colors.blueGrey.shade800,
                                          child: subtopic['profile_image_url'] == null ||
                                                  subtopic['profile_image_url'].isEmpty
                                              ? Icon(Icons.person, size: 14, color: Colors.grey[400])
                                              : null,
                                        ),
                                        title: Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              description,
                                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Posted on: $formattedDate by ${subtopic['username'] ?? 'Unknown'}',
                                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.tealAccent,
                                        ),
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => SubtopicDetailsPage(subtopic: subtopic),
                                            ),
                                          );
                                          if (result == true && mounted) {
                                            await _fetchSubtopics();
                                            showSuccess(context, 'Subtopic deleted successfully');
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}