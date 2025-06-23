import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../Services/auth_service.dart';
import '../Utils/rank_utils.dart';
import '../Utils/Translations.dart';
import 'package:async/async.dart';

class SubtopicDetailsPage extends StatefulWidget {
  final Map<String, dynamic> subtopic;
  final double imageHeight;

  const SubtopicDetailsPage({
    super.key,
    required this.subtopic,
    this.imageHeight = 100.0,
  });

  @override
  _SubtopicDetailsPageState createState() => _SubtopicDetailsPageState();
}

class _SubtopicDetailsPageState extends State<SubtopicDetailsPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  bool _isLoggedIn = false;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _reportReasonController = TextEditingController();
  final AuthService _authService = AuthService();
  int? _replyingToPostId;
  final Map<int, bool> _collapseStates = {};
  final String _selectedLanguage = 'en';
  late AnimationController _imageFadeController;
  late Animation<double> _imageFadeAnimation;
  late AnimationController _avatarHoverController;
  late Animation<double> _avatarScaleAnimation;
  Map<String, dynamic>? _creatorDetails;
  bool _hasInitialized = false;
   String _userRole = 'user'; // Új változó a szerepkör tárolására
  int? _userId; // Új változó a felhasználó ID tárolására


  @override
  void initState() {
    super.initState();
    _imageFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _imageFadeAnimation = CurvedAnimation(
      parent: _imageFadeController,
      curve: Curves.easeInOut,
    );
    _avatarHoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _avatarScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _avatarHoverController, curve: Curves.easeInOut),
    );
    _imageFadeController.forward();
  }

  @override
  void dispose() {
    _postController.dispose();
    _reportReasonController.dispose();
    _imageFadeController.dispose();
    _avatarHoverController.dispose();
    super.dispose();
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
  
  await _checkLoginStatus(); // Várjuk meg a bejelentkezési állapot ellenőrzését
  await _fetchUserRole(); // Hívjuk meg a szerepkör lekérdezését
  if (mounted) {
    await _fetchCreatorDetails();
    await _fetchPosts();
  }
}

Future<void> _fetchUserRole() async {
  try {
    final token = await _authService.getToken();
    if (token == null) {
      debugPrint('No auth token found. User is likely not logged in.');
      setState(() {
        _userRole = 'user';
        _userId = null;
      });
      return;
    }

    final userIdStr = await _authService.getUserId();
    final userId = int.tryParse(userIdStr ?? '');
    if (userId == null) {
      debugPrint('No user ID found in SharedPreferences.');
      setState(() {
        _userRole = 'user';
        _userId = null;
      });
      return;
    }

    final response = await http.get(
      Uri.parse('https://localhost:7164/api/User/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200 && mounted) {
      final userData = json.decode(response.body);
      if (userData == null || userData['id'] == null || userData['role'] == null) {
        debugPrint('Invalid user data: $userData');
        setState(() {
          _userRole = 'user';
          _userId = userId;
        });
        return;
      }
      setState(() {
        _userRole = userData['role'].toString();
        _userId = int.tryParse(userData['id'].toString()) ?? userId;
      });
    } else {
      debugPrint('Error fetching user role: ${response.statusCode} - ${response.body}');
      setState(() {
        _userRole = 'user';
        _userId = userId;
      });
    }
  } catch (e) {
    debugPrint('Exception during fetchUserRole: $e');
    setState(() {
      _userRole = 'user';
      _userId = null;
    });
  }
}

  Future<void> _checkLoginStatus() async {
    final loggedIn = await _authService.isUserLoggedIn();
    if (mounted) setState(() => _isLoggedIn = loggedIn);
  }

Future<void> _fetchCreatorDetails() async {
  final userId = widget.subtopic['userId'];
  debugPrint('Fetching creator details for userId: $userId');
  
  final defaultDetails = {
    'profileImageUrl': '',
    'username': widget.subtopic['username'] ?? 'Unknown',
    'userRank': 'Learner Driver',
  };

  if (userId == null) {
    if (mounted) {
      setState(() => _creatorDetails = defaultDetails);
    }
    return;
  }

  final details = await _fetchUserDetails(userId);
  if (mounted) {
    setState(() {
      _creatorDetails = details ?? defaultDetails;
    });
  }
}
  String _translateUserRank(String rawRank) {
    final t = translations[_selectedLanguage] ?? translations['en']!;
    switch (rawRank.trim()) {
      case 'Újonc':
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
        debugPrint('Unknown raw rank: $rawRank, falling back to Learner Driver');
        return t['rankLearnerDriver'] ?? 'Learner Driver';
    }
  }

 Future<void> _fetchPosts() async {
  final subtopicId = widget.subtopic['id'];
  debugPrint('Fetching posts for subtopicId: $subtopicId');
  if (subtopicId == null) {
    if (mounted) setState(() => _isLoading = false);
    return;
  }
  try {
    final token = await _authService.getToken();
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/forum/subtopics/$subtopicId/posts'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    debugPrint('Fetch posts response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200 && mounted) {
      List<Map<String, dynamic>> posts = List<Map<String, dynamic>>.from(json.decode(response.body));
      for (var post in posts) {
        final userId = post['userId'];
        post['upvoteCount'] ??= 0;
        post['downvoteCount'] ??= 0;
        post['profileImageUrl'] ??= ''; // Egységes kulcs
        post['signature'] ??= '';
        post['userRank'] ??= 'Learner Driver';
        if (userId != null) { // Mindig kérjük le, ha van userId
          final userDetails = await _fetchUserDetails(userId);
          if (userDetails != null) {
            post['profileImageUrl'] = userDetails['profileImageUrl'] ?? '';
            post['signature'] = userDetails['signature'] ?? '';
            post['userRank'] = userDetails['userRank'] ?? 'Learner Driver';
            debugPrint('Post profileImageUrl for userId $userId: ${post['profileImageUrl']}');
          }
        }
      }
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } else if (mounted) {
      _showSnackBar('failedToLoadPosts', isError: true, error: '${response.statusCode} - ${response.body}');
      setState(() => _isLoading = false);
    }
  } catch (e) {
    if (mounted) {
      debugPrint('Error fetching posts: $e');
      _showSnackBar('errorFetchingPosts', isError: true, error: e.toString());
      setState(() => _isLoading = false);
    }
  }
}

  Future<void> _createPost({int? parentPostId}) async {
    if (_postController.text.trim().isEmpty) {
      _showSnackBar('emptyPostContent', isWarning: true);
      return;
    }

    final token = await _authService.getToken();
    final userIdStr = await _authService.getUserId();
    final subtopicId = widget.subtopic['id'];

    debugPrint('Creating post: userId=$userIdStr, subtopicId=$subtopicId, parentPostId=$parentPostId');

    if (token == null || userIdStr == null || subtopicId == null) {
      _showSnackBar('authError', isError: true);
      return;
    }

    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      _showSnackBar('invalidUserId', isError: true);
      return;
    }

    try {
      final postData = {
        'userId': userId,
        'subtopicId': subtopicId,
        'content': _postController.text.trim(),
        'parentPostId': parentPostId,
      };
      debugPrint('Sending post data: ${json.encode(postData)}');
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/User/posts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(postData),
      );
      debugPrint('Create post response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 201 && mounted) {
        _showSnackBar('postCreated');
        _postController.clear();
        setState(() => _replyingToPostId = null);
        await _fetchPosts();
      } else if (mounted) {
        _showSnackBar('failedToCreatePost', isError: true, error: '${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error creating post: $e');
        _showSnackBar('errorCreatingPost', isError: true, error: e.toString());
      }
    }
  }

 Future<void> _deleteSubtopic() async {
  if (!_isLoggedIn) {
    if (mounted) _showSnackBar('loginToDelete', isError: true);
    return;
  }

  final token = await _authService.getToken();
  final subtopicId = widget.subtopic['id'];

  debugPrint('Attempting to delete subtopic: userId=$_userId, subtopicId=$subtopicId, token=${token?.substring(0, 20)}..., role=$_userRole');

  if (token == null || _userId == null || subtopicId == null) {
    debugPrint('Delete subtopic error: token=$token, userId=$_userId, subtopicId=$subtopicId');
    if (mounted) _showSnackBar('authError', isError: true);
    return;
  }

  final canDelete = await _canDeleteSubtopic();
  debugPrint('Delete permission check: canDelete=$canDelete');
  if (!canDelete) {
    debugPrint('User $_userId is not authorized to delete subtopic $subtopicId');
    if (mounted) _showSnackBar('notSubtopicOwner', isError: true);
    return;
  }

  if (!mounted) return;

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        translations[_selectedLanguage]?['deleteSubtopic'] ?? 'Delete Subtopic',
        style: const TextStyle(color: Colors.white),
      ),
      content: Text(
        translations[_selectedLanguage]?['confirmDeleteSubtopic'] ?? 'Are you sure you want to delete this subtopic?',
        style: const TextStyle(color: Colors.white),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            translations[_selectedLanguage]?['cancel'] ?? 'Cancel',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(
            translations[_selectedLanguage]?['delete'] ?? 'Delete',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  if (confirm != true || !mounted) return;

  final cancelToken = CancelableOperation.fromFuture(
    http.delete(
      Uri.parse('https://localhost:7164/api/forum/subtopics/$subtopicId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ),
    onCancel: () => debugPrint('Delete subtopic request canceled'),
  );

  try {
    final response = await cancelToken.value;
    if (!mounted) return;

    debugPrint('Delete subtopic response: ${response.statusCode} - ${response.body}');

    if (response.statusCode == 200) {
      if (mounted) {
        _showSnackBar(_userRole.toLowerCase() == 'admin' ? 'subtopicDeletedByAdmin' : 'subtopicDeleted');
        Navigator.pop(context, true);
      }
    } else {
      String errorMessage = translations[_selectedLanguage]?['failedToDeleteSubtopic'] ?? 'Failed to delete subtopic';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
      } catch (_) {
        errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
      }
      if (mounted) {
        _showSnackBar('failedToDeleteSubtopic', isError: true, error: '$errorMessage (${response.statusCode})');
      }
    }
  } catch (e) {
    if (mounted) {
      debugPrint('Error deleting subtopic: $e');
      _showSnackBar('errorDeletingSubtopic', isError: true, error: e.toString());
    }
  }
}


  Future<void> _reportPost(int postId) async {
    if (!_isLoggedIn) {
      _showSnackBar('loginToReport', isError: true);
      return;
    }
    final token = await _authService.getToken();
    final userIdStr = await _authService.getUserId();
    debugPrint('Reporting post: postId=$postId, userId=$userIdStr');
    if (token == null || userIdStr == null) {
      _showSnackBar('authError', isError: true);
      return;
    }
    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      _showSnackBar('invalidUserId', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          translations[_selectedLanguage]?['reportPost'] ?? 'Report Post',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _reportReasonController,
          decoration: InputDecoration(
            labelText: translations[_selectedLanguage]?['reportReason'] ?? 'Reason for reporting (optional)',
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              translations[_selectedLanguage]?['cancel'] ?? 'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final reportData = {
                  'contentType': 'post',
                  'contentId': postId,
                  'reason': _reportReasonController.text.trim().isEmpty ? null : _reportReasonController.text.trim(),
                };
                debugPrint('Sending report data: ${json.encode(reportData)}');
                final response = await http.post(
                  Uri.parse('https://localhost:7164/api/Admin/report'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: json.encode(reportData),
                );
                debugPrint('Report post response: ${response.statusCode} - ${response.body}');
                Navigator.pop(context);
                if (response.statusCode == 200 && mounted) {
                  _showSnackBar('postReported');
                  _reportReasonController.clear();
                } else if (mounted) {
                  String errorMessage = translations[_selectedLanguage]?['failedToReport'] ?? 'Failed to report post';
                  try {
                    final errorData = json.decode(response.body);
                    errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
                  } catch (_) {}
                  _showSnackBar('failedToReport', isError: true, error: errorMessage);
                }
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  debugPrint('Error reporting post: $e');
                  _showSnackBar('errorReportingPost', isError: true, error: e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              translations[_selectedLanguage]?['submit'] ?? 'Submit',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _votePost(int postId, String voteType) async {
    if (!_isLoggedIn) {
      _showSnackBar('loginToVote', isError: true);
      return;
    }
    final token = await _authService.getToken();
    debugPrint('Voting post: postId=$postId, voteType=$voteType');
    if (token == null) {
      _showSnackBar('authError', isError: true);
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://localhost:7164/api/forum/posts/$postId/vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'voteType': voteType}),
      );
      debugPrint('Vote post response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && mounted) {
        await _fetchPosts();
      } else if (mounted) {
        _showSnackBar('failedToVote', isError: true, error: '${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error voting post: $e');
        _showSnackBar('errorVoting', isError: true, error: e.toString());
      }
    }
  }

  Future<void> _removeVote(int postId) async {
    if (!_isLoggedIn) {
      _showSnackBar('loginToRemoveVote', isError: true);
      return;
    }
    final token = await _authService.getToken();
    debugPrint('Removing vote from post: postId=$postId');
    if (token == null) {
      _showSnackBar('authError', isError: true);
      return;
    }
    try {
      final response = await http.delete(
        Uri.parse('https://localhost:7164/api/forum/posts/$postId/vote'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('Remove vote response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200 && mounted) {
        await _fetchPosts();
      } else if (mounted) {
        _showSnackBar('failedToRemoveVote', isError: true, error: '${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error removing vote: $e');
        _showSnackBar('errorRemovingVote', isError: true, error: e.toString());
      }
    }
  }

 Future<Map<String, dynamic>?> _fetchUserDetails(int userId) async {
  debugPrint('Fetching user details for userId: $userId');
  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/User/userdetails/$userId'),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    debugPrint('Fetch user details response: ${response.statusCode} - ${response.body}');
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (mounted) {
      _showSnackBar('failedToLoadUserDetails', isError: true, error: '${response.statusCode} - ${response.body}');
      return null;
    }
  } catch (e) {
    if (mounted) {
      debugPrint('Error fetching user details: $e');
      _showSnackBar('errorFetchingUserDetails', isError: true, error: e.toString());
      return null;
    }
  }
  return null;
}

  void _showUserProfileDialog(Map<String, dynamic> userData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundImage: userData['profileImageUrl'] != null && userData['profileImageUrl'].isNotEmpty
                      ? NetworkImage(userData['profileImageUrl'])
                      : null,
                  backgroundColor: Colors.grey[800],
                  child: userData['profileImageUrl'] == null || userData['profileImageUrl'].isEmpty
                      ? Icon(Icons.person, size: 40, color: Colors.grey[400])
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  userData['username'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (userData['registrationDate'] != null) ...[
                  _buildProfileField(
                    icon: Icons.calendar_today,
                    label: translations[_selectedLanguage]?['joined'] ?? 'Joined',
                    value: DateFormat('yyyy-MM-dd').format(DateTime.parse(userData['registrationDate'])),
                  ),
                  const SizedBox(height: 12),
                ],
                if (userData['lastActivity'] != null) ...[
                  _buildProfileField(
                    icon: Icons.access_time,
                    label: translations[_selectedLanguage]?['lastActive'] ?? 'Last Active',
                    value: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(userData['lastActivity'])),
                  ),
                  const SizedBox(height: 12),
                ],
                if (userData['userRank'] != null && userData['userRank'].isNotEmpty) ...[
                  _buildProfileField(
                    icon: Icons.star,
                    label: translations[_selectedLanguage]?['rank'] ?? 'Rank',
                    value: _translateUserRank(userData['userRank']),
                    valueColor: getRankColor(_translateUserRank(userData['userRank']), language: _selectedLanguage),
                  ),
                  const SizedBox(height: 12),
                ],
                if (userData['postCount'] != null) ...[
                  _buildProfileField(
                    icon: Icons.comment,
                    label: translations[_selectedLanguage]?['posts'] ?? 'Posts',
                    value: '${userData['postCount']}',
                  ),
                  const SizedBox(height: 12),
                ],
                if (userData['bio'] != null && userData['bio'].isNotEmpty) ...[
                  _buildProfileField(
                    icon: Icons.info,
                    label: translations[_selectedLanguage]?['bio'] ?? 'Bio',
                    value: userData['bio'],
                    isMultiLine: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (userData['hobbies'] != null && (userData['hobbies'] as List).isNotEmpty) ...[
                  _buildProfileField(
                    icon: Icons.favorite,
                    label: translations[_selectedLanguage]?['hobbies'] ?? 'Hobbies',
                    value: (userData['hobbies'] as List).join(', '),
                    isMultiLine: true,
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    translations[_selectedLanguage]?['close'] ?? 'Close',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiLine = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 14,
                ),
                maxLines: isMultiLine ? null : 1,
                overflow: isMultiLine ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _buildPostTree(List<Map<String, dynamic>> posts) {
    final Map<int, List<Map<String, dynamic>>> children = {};
    final List<Map<String, dynamic>> topLevelPosts = [];
    for (var post in posts) {
      final postId = post['id'] as int;
      children[postId] = [];
    }
    for (var post in posts) {
      final parentPostId = post['parentPostId'] as int?;
      if (parentPostId == null) {
        topLevelPosts.add(post);
      } else {
        children[parentPostId]?.add(post);
      }
    }
    for (var post in posts) {
      final postId = post['id'] as int;
      post['children'] = children[postId] ?? [];
    }
    return topLevelPosts;
  }

  Future<bool> _isOwnPost(int postUserId) async {
    final userIdStr = await _authService.getUserId();
    final loggedInUserId = userIdStr != null ? int.tryParse(userIdStr) : null;
    debugPrint('Checking post ownership: loggedInUserId=$loggedInUserId, postUserId=$postUserId');
    return loggedInUserId != null && postUserId == loggedInUserId;
  }

  Future<void> _deletePost(int postId) async {
    if (!_isLoggedIn) {
      if (mounted) _showSnackBar('loginToDelete', isError: true);
      return;
    }

    final token = await _authService.getToken();
    final userIdStr = await _authService.getUserId();
    debugPrint('Attempting to delete post: postId=$postId, userId=$userIdStr');
    if (token == null || userIdStr == null) {
      if (mounted) _showSnackBar('authError', isError: true);
      return;
    }

    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      if (mounted) _showSnackBar('invalidUserId', isError: true);
      return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          translations[_selectedLanguage]?['deletePost'] ?? 'Delete Post',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          translations[_selectedLanguage]?['confirmDeletePost'] ?? 'Are you sure you want to delete this post?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              translations[_selectedLanguage]?['cancel'] ?? 'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              translations[_selectedLanguage]?['delete'] ?? 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final cancelToken = CancelableOperation.fromFuture(
      http.delete(
        Uri.parse('https://localhost:7164/api/User/posts/$postId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      onCancel: () => debugPrint('Delete post request canceled'),
    );

    try {
      final response = await cancelToken.value;
      debugPrint('Delete post response: ${response.statusCode} - ${response.body}');
      if (!mounted) return;

      if (response.statusCode == 200) {
        if (mounted) {
          _showSnackBar('postDeleted');
          await _fetchPosts();
        }
      } else {
        if (mounted) {
          String errorMessage = translations[_selectedLanguage]?['failedToDeletePost'] ?? 'Failed to delete post';
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
          } catch (_) {}
          _showSnackBar('failedToDeletePost', isError: true, error: '$errorMessage (${response.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error deleting post: $e');
        _showSnackBar('errorDeletingPost', isError: true, error: e.toString());
      }
    }
  }

 void _showSnackBar(String key, {bool isError = false, bool isWarning = false, String? error}) {
  if (!mounted) return;
  final t = translations[_selectedLanguage] ?? translations['en']!;
  final message = error != null ? '${t[key] ?? key}: $error' : t[key] ?? key;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (isError) {
      showFailed(context, message);
    } else if (isWarning) {
      showWarning(context, message);
    } else {
      showSuccess(context, message);
    }
  });
}

Future<bool> _canDeleteSubtopic() async {
  final subtopicUserId = widget.subtopic['userId'];

  debugPrint('Checking delete permission: loggedInUserId=$_userId, subtopicUserId=$subtopicUserId, userRole=$_userRole');

  if (_userId == null || subtopicUserId == null) {
    return _userRole.toLowerCase() == 'admin'; // Ha nincs userId, csak admin törölhet
  }

  return _userRole.toLowerCase() == 'admin' || _userId == subtopicUserId; // Admin vagy tulajdonos törölhet
}

  Widget _buildPostItem(Map<String, dynamic> post, {int depth = 0}) {
    final content = post['content'] ?? 'No content';
    String formattedDate = 'N/A';
    if (post['createdAt'] != null) {
      try {
        formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(post['createdAt']));
      } catch (e) {
        debugPrint('Date parsing error: ${post['createdAt']} - $e');
      }
    }
    final postId = post['id'] as int;
    final upvoteCount = post['upvoteCount'] ?? 0;
    final downvoteCount = post['downvoteCount'] ?? 0;
    final userVote = post['userVote'] as String?;
    if (!_collapseStates.containsKey(postId)) {
      _collapseStates[postId] = false;
    }
    final isCollapsed = _collapseStates[postId]!;
    final rawRank = post['userRank'] as String? ?? 'Learner Driver';
    final translatedRank = _translateUserRank(rawRank);
    final rankColor = getRankColor(translatedRank, language: _selectedLanguage);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['children'] != null && (post['children'] as List).isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _collapseStates[postId] = !isCollapsed;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.0 * depth, top: 8, right: 8),
                      child: Icon(
                        isCollapsed ? MdiIcons.plus : MdiIcons.minus,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  )
                else
                  SizedBox(width: 16.0 * depth + (depth > 0 ? 10.0 : 0.0)),
                GestureDetector(
                  onTap: () async {
                    final userId = post['userId'];
                    if (userId != null) {
                      final userDetails = await _fetchUserDetails(userId);
                      if (userDetails != null && mounted) {
                        _showUserProfileDialog(userDetails);
                      }
                    } else {
                      _showSnackBar('userIdNotAvailable', isError: true);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: rankColor,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 25,
backgroundImage: post['profileImageUrl'] != null && post['profileImageUrl'].isNotEmpty
    ? NetworkImage(post['profileImageUrl'])
    : null,
                        backgroundColor: Colors.grey[800],
                        child: post['profile_image_url'] == null || post['profile_image_url'].isEmpty
                            ? Icon(Icons.person, size: 25, color: Colors.grey[400])
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Card(
                    elevation: 2,
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: EdgeInsets.only(
                      left: (depth > 0 ? 10.0 : 0.0),
                      top: 8,
                      bottom: 8,
                      right: 8,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(
                        content,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                              children: [
                                const TextSpan(text: 'Posted on: '),
                                TextSpan(text: formattedDate),
                                const TextSpan(text: ' by '),
                                TextSpan(
                                  text: post['username'] ?? 'Unknown',
                                  style: TextStyle(color: rankColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_upward,
                                  color: userVote == 'upvote' ? Colors.green : Colors.grey[400],
                                ),
                                onPressed: userVote == 'upvote'
                                    ? () => _removeVote(postId)
                                    : () => _votePost(postId, 'upvote'),
                                tooltip: translations[_selectedLanguage]?['upvote'] ?? 'Upvote',
                              ),
                              Text('$upvoteCount', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_downward,
                                  color: userVote == 'downvote' ? Colors.red : Colors.grey[400],
                                ),
                                onPressed: userVote == 'downvote'
                                    ? () => _removeVote(postId)
                                    : () => _votePost(postId, 'downvote'),
                                tooltip: translations[_selectedLanguage]?['downvote'] ?? 'Downvote',
                              ),
                              Text('$downvoteCount', style: const TextStyle(color: Colors.grey)),
                              const SizedBox(width: 16),
                              if (_isLoggedIn) ...[
                                TextButton(
                                  onPressed: () {
                                    setState(() => _replyingToPostId = post['id']);
                                  },
                                  child: Text(
                                    translations[_selectedLanguage]?['reply'] ?? 'Reply',
                                    style: const TextStyle(color: Colors.blueAccent),
                                  ),
                                ),
                                FutureBuilder<bool>(
                                  future: _isOwnPost(post['userId']),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data == true) {
                                      return TextButton(
                                        onPressed: () => _deletePost(postId),
                                        child: Text(
                                          translations[_selectedLanguage]?['delete'] ?? 'Delete',
                                          style: const TextStyle(color: Colors.redAccent),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _reportPost(post['id']),
                                  child: Text(
                                    translations[_selectedLanguage]?['report'] ?? 'Report',
                                    style: const TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (post['signature'] != null && post['signature'].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Divider(color: Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text(
                              post['signature'],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoggedIn && _replyingToPostId == post['id'])
              Padding(
                padding: EdgeInsets.only(left: 16.0 * (depth + 1) + 10.0, right: 16),
                child: TextField(
                  controller: _postController,
                  decoration: InputDecoration(
                    labelText: translations[_selectedLanguage]?['replyComment'] ?? 'Reply to this comment...',
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Colors.blueAccent),
                      onPressed: () => _createPost(parentPostId: post['id']),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
              ),
            if (!isCollapsed && post['children'] != null)
              ...((post['children'] as List<Map<String, dynamic>>).map((child) => _buildPostItem(child, depth: depth + 1))),
          ],
        ),
        if (depth > 0) ...[
          Positioned(
            left: 16.0 * (depth - 1) + 4.0,
            top: 0,
            bottom: null,
            height: 30.0,
            child: Container(
              width: 2,
              color: Colors.grey[600],
            ),
          ),
          Positioned(
            left: 16.0 * (depth - 1) + 4.0,
            top: 30.0,
            width: 16.0,
            child: Container(
              height: 2,
              color: Colors.grey[600],
            ),
          ),
          if (!isCollapsed && post['children'] != null && (post['children'] as List).isNotEmpty)
            Positioned(
              left: 16.0 * (depth - 1) + 4.0,
              top: 30.0,
              bottom: 0,
              child: Container(
                width: 2,
                color: Colors.grey[600],
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topLevelPosts = _buildPostTree(_posts);
    const String imagePath = 'assets/pictures/backgroundimage.png';
    final subtopicImages = [
      widget.subtopic['imageUrl1'] as String?,
      widget.subtopic['imageUrl2'] as String?,
      widget.subtopic['imageUrl3'] as String?,
    ].where((url) => url != null && url.isNotEmpty).toList();
    final description = widget.subtopic['description'] ?? translations[_selectedLanguage]?['noDescription'] ?? 'No description';
    final isDescriptionValid = description.length >= 50;

    return Scaffold(
      body: Stack(
        children: [
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
          Column(
            children: [
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
                      tooltip: translations[_selectedLanguage]?['back'] ?? 'Back',
                    ),
                    Expanded(
                      child: Text(
                        widget.subtopic['title'] ?? translations[_selectedLanguage]?['subtopicDetails'] ?? 'Subtopic Details',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: _canDeleteSubtopic(),
                      builder: (context, snapshot) {
                        if (_isLoggedIn && snapshot.hasData && snapshot.data == true) {
                          return IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 28),
                            onPressed: _deleteSubtopic,
                            tooltip: translations[_selectedLanguage]?['deleteSubtopic'] ?? 'Delete Subtopic',
                          );
                        }
                        return const SizedBox(width: 48);
                      },
                    ),
                  ],
                ),
              ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_creatorDetails != null)
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  final userId = widget.subtopic['userId'];
                                  if (userId != null) {
                                    final userDetails = await _fetchUserDetails(userId);
                                    if (userDetails != null && mounted) {
                                      _showUserProfileDialog(userDetails);
                                    }
                                  } else {
                                    _showSnackBar('userIdNotAvailable', isError: true);
                                  }
                                },
                                onTapDown: (_) => _avatarHoverController.forward(),
                                onTapUp: (_) => _avatarHoverController.reverse(),
                                onTapCancel: () => _avatarHoverController.reverse(),
                                child: ScaleTransition(
                                  scale: _avatarScaleAnimation,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: getRankColor(
                                          _translateUserRank(_creatorDetails!['userRank'] ?? 'Learner Driver'),
                                          language: _selectedLanguage,
                                        ),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: _creatorDetails!['profileImageUrl'] != null &&
                                              _creatorDetails!['profileImageUrl'].isNotEmpty
                                          ? NetworkImage(_creatorDetails!['profileImageUrl'])
                                          : null,
                                      backgroundColor: Colors.grey[800],
                                      child: _creatorDetails!['profileImageUrl'] == null ||
                                              _creatorDetails!['profileImageUrl'].isEmpty
                                          ? const Icon(Icons.person, size: 20, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    children: [
                                      TextSpan(
                                        text: '${translations[_selectedLanguage]?['postedOn'] ?? 'Posted on'}: ',
                                      ),
                                      TextSpan(
                                        text: widget.subtopic['createdAt'] != null
                                            ? DateFormat('yyyy-MM-dd HH:mm:ss')
                                                .format(DateTime.parse(widget.subtopic['createdAt']))
                                            : 'N/A',
                                      ),
                                      TextSpan(
                                        text: ' ${translations[_selectedLanguage]?['by'] ?? 'by'} ',
                                      ),
                                      TextSpan(
                                        text: _creatorDetails!['username'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: getRankColor(
                                            _translateUserRank(_creatorDetails!['userRank'] ?? 'Learner Driver'),
                                            language: _selectedLanguage,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 3,
                          color: Colors.blueGrey.shade900.withOpacity(0.9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    height: 1.4,
                                  ),
                                ),
                                if (!isDescriptionValid)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      translations[_selectedLanguage]?['descriptionTooShort'] ??
                                          'Description must be at least 50 characters long.',
                                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (subtopicImages.isNotEmpty)
                          FadeTransition(
                            opacity: _imageFadeAnimation,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: subtopicImages.asMap().entries.map((entry) {
                                  final url = entry.value!;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            child: Image.network(
                                              url,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.broken_image,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          url,
                                          width: 100,
                                          height: widget.imageHeight,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 100,
                                            height: widget.imageHeight,
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.grey,
                                              size: 50,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          translations[_selectedLanguage]?['discussion'] ?? 'Discussion',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_isLoggedIn && _replyingToPostId == null) ...[
                          TextField(
                            controller: _postController,
                            decoration: InputDecoration(
                              labelText: translations[_selectedLanguage]?['addComment'] ?? 'Add a comment...',
                              filled: true,
                              fillColor: Colors.grey[800],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send, color: Colors.tealAccent),
                                onPressed: () => _createPost(),
                              ),
                              labelStyle: const TextStyle(color: Colors.grey),
                            ),
                            style: const TextStyle(color: Colors.white),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),
                        ],
                        _isLoading
                            ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                            : topLevelPosts.isEmpty
                                ? Text(
                                    translations[_selectedLanguage]?['noComments'] ?? 'No comments yet',
                                    style: const TextStyle(color: Colors.grey),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: topLevelPosts.length,
                                    itemBuilder: (context, index) => _buildPostItem(topLevelPosts[index]),
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
}