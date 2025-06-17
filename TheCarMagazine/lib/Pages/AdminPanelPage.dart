import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'SubTopicDetailsPage.dart';
import '../main.dart';
import '../Services/auth_service.dart';
import '../Utils/Translations.dart';

class AdminPanelPage extends StatefulWidget {
  final String selectedLanguage;
  const AdminPanelPage({super.key, required this.selectedLanguage});
  
  @override
  _AdminPanelPageState createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  bool _isAdmin = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reportedContent = [];
  List<Map<String, dynamic>> _supportTickets = []; // Új lista a support ticketekhez
  final _userIdController = TextEditingController();
  Map<String, dynamic>? _selectedUser;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _role = 'user';
  bool _isVerified = false;
  final _bioController = TextEditingController();
  final _statusController = TextEditingController();
  final _profileImageUrlController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _userRankController = TextEditingController();
  final _signatureController = TextEditingController();
  final _languageController = TextEditingController();
  final _hashingAlgorithmController = TextEditingController();
  int _reportedContentPage = 1; // Jelentett tartalom aktuális oldala
  int _supportTicketsPage = 1; // Support ticketek aktuális oldala
  final int _itemsPerPage = 8; // Elemszám oldalanként
  bool _isLoadingMoreReported = false; // További jelentések betöltése
  bool _isLoadingMoreTickets = false; // További ticketek betöltése
  final ScrollController _reportedContentScrollController = ScrollController(); // Scroll vezérlő jelentésekhez
  final ScrollController _supportTicketsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchReportedContent();
    _fetchSupportTickets(); // Új függvény hívása
    _reportedContentScrollController.addListener(_loadMoreReportedContent);
    _supportTicketsScrollController.addListener(_loadMoreSupportTickets);
  }

  Future<void> _checkAdminStatus() async {
    try {
      final authService = AuthService();
      final token = await authService.getToken();
      if (token == null) {
        print('No auth token found. User is likely not logged in.');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final userIdStr = await authService.getUserId();
      final userId = int.tryParse(userIdStr ?? '');
      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        if (mounted) {
          setState(() {
            _isAdmin = userData['role'].toString() == 'admin';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

 Future<void> _fetchReportedContent({bool isLoadMore = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  if (isLoadMore && mounted) {
    setState(() => _isLoadingMoreReported = true);
  }
  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/Admin/reported-content?page=$_reportedContentPage&perPage=$_itemsPerPage'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _reportedContent.addAll(data.cast<Map<String, dynamic>>());
          } else {
            _reportedContent = data.cast<Map<String, dynamic>>();
          }
          _isLoadingMoreReported = false;
        });
      }
    } else {
      _showSnackBar('Failed to fetch reported content: ${response.body}', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error fetching reported content: $e', Colors.red);
  } finally {
    if (mounted && isLoadMore) {
      setState(() => _isLoadingMoreReported = false);
    }
  }
}

void _loadMoreReportedContent() {
  if (!_isLoadingMoreReported) {
    setState(() => _reportedContentPage++);
    _fetchReportedContent(isLoadMore: true);
  }
}




Future<void> _acceptReport(int contentId, String contentType) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/Admin/reported/$contentId/accept?contentType=$contentType'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      _showSnackBar('Report accepted', Colors.green);
      setState(() => _reportedContentPage = 1); // Reset oldal
      await _fetchReportedContent();
    } else {
      String errorMessage = 'Failed to accept report';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (_) {}
      _showSnackBar(errorMessage, Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error accepting report: $e', Colors.red);
  }
}

  // Új függvény a ticket állapotának frissítésére
  Future<void> _updateTicketStatus(int ticketId, String status) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.put(
      Uri.parse('https://localhost:7164/api/Admin/support-ticket/$ticketId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'status': status}),
    );
    if (response.statusCode == 200) {
      _showSnackBar('Ticket status updated to $status', Colors.green);
      setState(() => _supportTicketsPage = 1); // Reset oldal
      await _fetchSupportTickets();
    } else {
      try {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to update ticket status: ${errorData['error'] ?? response.body}', Colors.red);
      } catch (_) {
        _showSnackBar('Failed to update ticket status: ${response.body}', Colors.red);
      }
    }
  } catch (e) {
    _showSnackBar('Error updating ticket status: $e', Colors.red);
  }
}

Future<void> _fetchUser() async {
  final userId = _userIdController.text.trim();
  final username = _usernameController.text.trim();
  if (userId.isEmpty && username.isEmpty) {
    _showSnackBar('Please enter a User ID or Username', Colors.red);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  setState(() => _isLoading = true);
  try {
    final query = userId.isNotEmpty ? 'id=$userId' : 'username=$username';
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/Admin/user?$query'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200 && mounted) {
      final userData = json.decode(response.body);
      setState(() {
      _selectedUser = {
        ...userData,
        'isBanned': (userData['isBanned'] ?? false) != 0, // Convert int to bool
        'IsVerified': (userData['IsVerified'] ?? false) != 0, // Existing fix for IsVerified
      };
      _userIdController.text = userData['id'].toString();
      _usernameController.text = userData['username'] ?? '';
      _emailController.text = userData['email'] ?? '';
      _passwordController.clear();
      _role = userData['role'] ?? 'user';
      _isVerified = (userData['IsVerified'] ?? false) != 0;
      _bioController.text = userData['bio'] ?? '';
      _statusController.text = userData['status'] ?? '';
      _profileImageUrlController.text = userData['profile_image_url'] ?? '';
      _locationController.text = userData['location'] ?? '';
      _contactEmailController.text = userData['contact_email'] ?? '';
      _userRankController.text = userData['user_rank'] ?? '';
      _signatureController.text = userData['signature'] ?? '';
      _languageController.text = userData['language'] ?? 'en';
      _hashingAlgorithmController.text = userData['HashingAlgorithm'] ?? 'Bcrypt';
      _isLoading = false;
    });
      _showSnackBar('User fetched successfully', Colors.green);
    } else {
      _showSnackBar('Invalid User ID or Username', Colors.red);
      setState(() {
        _selectedUser = null;
        _isLoading = false;
      });
    }
  } catch (e) {
    _showSnackBar('Error fetching user: $e', Colors.red);
    setState(() {
      _selectedUser = null;
      _isLoading = false;
    });
  }
}
 

Future<void> _updateUser() async {
  if (_selectedUser == null) {
    _showSnackBar('No user selected', Colors.red);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  final updateData = {
    'UserId': int.parse(_userIdController.text),
    if (_passwordController.text.isNotEmpty) 'Password': _passwordController.text,
    'Role': _role,
    'IsVerified': _isVerified,
    'IsBanned': _selectedUser!['isBanned'] ?? false,
    if (_usernameController.text.isNotEmpty) 'Username': _usernameController.text,
    if (_emailController.text.isNotEmpty) 'Email': _emailController.text,
    if (_bioController.text.isNotEmpty) 'Bio': _bioController.text,
    if (_statusController.text.isNotEmpty) 'Status': _statusController.text,
    if (_profileImageUrlController.text.isNotEmpty) 'ProfileImageUrl': _profileImageUrlController.text,
    if (_locationController.text.isNotEmpty) 'Location': _locationController.text,
    if (_contactEmailController.text.isNotEmpty) 'ContactEmail': _contactEmailController.text,
    if (_userRankController.text.isNotEmpty) 'UserRank': _userRankController.text,
    if (_signatureController.text.isNotEmpty) 'Signature': _signatureController.text,
    if (_languageController.text.isNotEmpty) 'Language': _languageController.text,
    if (_hashingAlgorithmController.text.isNotEmpty) 'HashingAlgorithm': _hashingAlgorithmController.text,
  };
  setState(() => _isLoading = true);
  try {
    final response = await http.put(
      Uri.parse('https://localhost:7164/api/Admin/user/${_userIdController.text}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(updateData),
    );
    if (response.statusCode == 200) {
      _showSnackBar('User updated successfully', Colors.green);
      setState(() {
        _selectedUser = null;
        _userIdController.clear();
        _usernameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _bioController.clear();
        _statusController.clear();
        _profileImageUrlController.clear();
        _locationController.clear();
        _contactEmailController.clear();
        _userRankController.clear();
        _signatureController.clear();
        _languageController.clear();
        _hashingAlgorithmController.clear();
        _role = 'user';
        _isVerified = false;
        _isLoading = false;
      });
    } else {
      _showSnackBar('Failed to update user: ${response.body}', Colors.red);
      setState(() => _isLoading = false);
    }
  } catch (e) {
    _showSnackBar('Error updating user: $e', Colors.red);
    setState(() => _isLoading = false);
  }
}
 
Future<void> _deleteContent(int contentId, String contentType) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.delete(
      Uri.parse('https://localhost:7164/api/Admin/reported/$contentId?contentType=$contentType'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      _showSnackBar('Deletion successfull.', Colors.green);
      setState(() => _reportedContentPage = 1); // Reset oldal
      await _fetchReportedContent();
    } else {
      String errorMessage = 'Failed to delete $contentType';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['error'] ?? errorMessage;
      } catch (_) {}
      _showSnackBar(errorMessage, Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error deleting $contentType: $e', Colors.red);
  }
}
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.roboto(color: Colors.white)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = translations[widget.selectedLanguage]!;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                t['accessDenied'] ?? 'Access Denied',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                t['adminPrivileges'] ?? 'You need admin privileges to access this page.',
                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => MainPage(authService: AuthService())),
                    (route) => false,
                  );
                },
                child: Text(t['goToHome'] ?? 'Go to Home', style: GoogleFonts.roboto(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          t['adminPanel'] ?? 'Admin Panel',
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInAnimation(child: _buildSection(t['modifyUser'] ?? 'Modify User', _buildUserModificationForm())),
              SizedBox(height: 24),
              FadeInAnimation(child: _buildSection(t['reportedContent'] ?? 'Reported Content', _buildReportedContent())),
              SizedBox(height: 24),
              FadeInAnimation(child: _buildSection(t['supportTickets'] ?? 'Support Tickets', _buildSupportTickets())), // Új szekció
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1C2526),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

 Widget _buildUserModificationForm() {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: _userIdController,
        decoration: InputDecoration(
          labelText: t['userId'] ?? 'User ID',
          filled: true,
          fillColor: Color(0xFF2A2F31),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        keyboardType: TextInputType.number,
        style: GoogleFonts.roboto(color: Colors.white),
      ),
      SizedBox(height: 16),
      TextField(
        controller: _usernameController,
        decoration: InputDecoration(
          labelText: t['username'] ?? 'Username',
          filled: true,
          fillColor: Color(0xFF2A2F31),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.roboto(color: Colors.white),
      ),
      SizedBox(height: 16),
      ElevatedButton(
        onPressed: _fetchUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: Text(t['fetchUser'] ?? 'Fetch User', style: GoogleFonts.roboto(fontSize: 16)),
      ),
      if (_selectedUser != null) ...[
        SizedBox(height: 20),
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: t['email'] ?? 'Email',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            labelText: t['newPassword'] ?? 'New Password (leave blank to keep current)',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
          obscureText: true,
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _role,
          decoration: InputDecoration(
            labelText: t['role'] ?? 'Role',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: const [
            DropdownMenuItem(value: 'user', child: Text('User')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _role = value);
          },
          style: GoogleFonts.roboto(color: Colors.white),
          dropdownColor: Color(0xFF2A2F31),
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _hashingAlgorithmController.text.isEmpty ? 'Bcrypt' : _hashingAlgorithmController.text,
          decoration: InputDecoration(
            labelText: t['hashingAlgorithm'] ?? 'Hashing Algorithm',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: const [
            DropdownMenuItem(value: 'Bcrypt', child: Text('Bcrypt')),
            DropdownMenuItem(value: 'Argon2id', child: Text('Argon2id')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _hashingAlgorithmController.text = value;
              });
            }
          },
          style: GoogleFonts.roboto(color: Colors.white),
          dropdownColor: Color(0xFF2A2F31),
        ),
        SizedBox(height: 16),
        CheckboxListTile(
          title: Text(t['verified'] ?? 'Verified', style: GoogleFonts.roboto(color: Colors.white)),
          value: _isVerified,
          onChanged: (value) {
            if (value != null) setState(() => _isVerified = value);
          },
          checkColor: Colors.white,
          activeColor: Colors.blueAccent,
          contentPadding: EdgeInsets.zero,
        ),
CheckboxListTile(
  title: Text(t['banned'] ?? 'Banned', style: GoogleFonts.roboto(color: Colors.white)),
  value: (_selectedUser!['isBanned'] == 1), // Csak akkor legyen bejelölve, ha 1
  onChanged: (value) {
    if (value != null) {
      setState(() {
        _selectedUser!['isBanned'] = value ? 1 : 0; // Visszatároljuk int-ként
      });
    }
  },
  checkColor: Colors.white,
  activeColor: Colors.redAccent,
  contentPadding: EdgeInsets.zero,
),

        SizedBox(height: 16),
        TextField(
          controller: _bioController,
          decoration: InputDecoration(
            labelText: t['bio'] ?? 'Bio',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
          maxLines: 3,
        ),
        SizedBox(height: 16),
        TextField(
          controller: _statusController,
          decoration: InputDecoration(
            labelText: t['status'] ?? 'Status',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _profileImageUrlController,
          decoration: InputDecoration(
            labelText: t['profileImageUrl'] ?? 'Profile Image URL',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: t['location'] ?? 'Location',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _contactEmailController,
          decoration: InputDecoration(
            labelText: t['contactEmail'] ?? 'Contact Email',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _userRankController,
          decoration: InputDecoration(
            labelText: t['userRank'] ?? 'User Rank',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _signatureController,
          decoration: InputDecoration(
            labelText: t['signature'] ?? 'Signature',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 16),
        TextField(
          controller: _languageController,
          decoration: InputDecoration(
            labelText: t['language'] ?? 'Language',
            filled: true,
            fillColor: Color(0xFF2A2F31),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.roboto(color: Colors.white),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedUser = null;
                  _userIdController.clear();
                  _usernameController.clear();
                  _emailController.clear();
                  _passwordController.clear();
                  _bioController.clear();
                  _statusController.clear();
                  _profileImageUrlController.clear();
                  _locationController.clear();
                  _contactEmailController.clear();
                  _userRankController.clear();
                  _signatureController.clear();
                  _languageController.clear();
                  _hashingAlgorithmController.clear();
                  _role = 'user';
                  _isVerified = false;
                });
              },
              child: Text(t['cancel'] ?? 'Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: _updateUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: Text(t['updateUser'] ?? 'Update User', style: GoogleFonts.roboto(fontSize: 16)),
            ),
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Color(0xFF1C2526),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  title: Text(t['banUser'] ?? 'Ban User', style: GoogleFonts.roboto(fontSize: 14)),
                  content: Text(t['banUserConfirm'] ?? 'Are you sure you want to ban this user?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t['cancel'] ?? 'Cancel', style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 10)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _banUser();
                      },
                      child: Text(t['ban'] ?? 'Ban', style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              child: Text(t['banUser'] ?? 'Ban User', style: GoogleFonts.roboto(fontSize: 16)),
            ),
          ],
        ),
      ],
      ],
    );
  }
Future<void> _banUser() async {
  if (_selectedUser == null) {
    _showSnackBar('No user selected', Colors.red);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  setState(() => _isLoading = true);
  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/Admin/user/${_userIdController.text}/ban'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      _showSnackBar('User banned successfully', Colors.green);
      setState(() {
        _selectedUser!['isBanned'] = true;
        _isLoading = false;
      });
    } else {
      _showSnackBar('Failed to ban user: ${response.body}', Colors.red);
      setState(() => _isLoading = false);
    }
  } catch (e) {
    _showSnackBar('Error banning user: $e', Colors.red);
    setState(() => _isLoading = false);
  }
}
// Ticket törlése és e-mail küldése
Future<void> _deleteSupportTicket(int ticketId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.delete(
      Uri.parse('https://localhost:7164/api/Admin/support-ticket/$ticketId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      _showSnackBar('Ticket deleted successfully', Colors.green);
      setState(() => _supportTicketsPage = 1); // Reset oldal
      await _fetchSupportTickets();
    } else {
      try {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to delete ticket: ${errorData['error'] ?? response.body}', Colors.red);
      } catch (_) {
        _showSnackBar('Failed to delete ticket: ${response.body}', Colors.red);
      }
    }
  } catch (e) {
    _showSnackBar('Error deleting ticket: $e', Colors.red);
  }
}

// Válasz e-mail küldése
Future<void> _sendResponseEmail(int ticketId, String userEmail, String subject, String responseText) async {
  if (userEmail.isEmpty) {
    _showSnackBar('User email is required', Colors.red);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/Admin/support-ticket/$ticketId/respond'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'userEmail': userEmail,
        'subject': subject,
        'responseText': responseText,
      }),
    );
    if (response.statusCode == 200) {
      _showSnackBar('Response email sent', Colors.green);
      // Állítsuk in_progress státuszra
      await _updateTicketStatus(ticketId, 'in_progress');
      await _fetchSupportTickets();
    } else {
      try {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to send response email: ${errorData['error'] ?? response.body}', Colors.red);
      } catch (_) {
        _showSnackBar('Failed to send response email: ${response.body}', Colors.red);
      }
    }
  } catch (e) {
    _showSnackBar('Error sending response email: $e', Colors.red);
  }
}

Future<void> _resolveSupportTicketWithEmail(int ticketId, String userEmail, String subject) async {
  if (userEmail.isEmpty) {
    _showSnackBar('User email is required', Colors.red);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.post(
      Uri.parse('https://localhost:7164/api/Admin/support-ticket/$ticketId/resolve-email'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'userEmail': userEmail,
        'subject': subject,
      }),
    );
    if (response.statusCode == 200) {
      _showSnackBar('Ticket resolved and notification email sent', Colors.green);
      await _fetchSupportTickets(); // Frissítjük a ticketek listáját
    } else {
      try {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to resolve ticket: ${errorData['error'] ?? response.body}', Colors.red);
      } catch (_) {
        _showSnackBar('Failed to resolve ticket: ${response.body}', Colors.red);
      }
    }
  } catch (e) {
    _showSnackBar('Error resolving ticket: $e', Colors.red);
  }
}

// Ticket részletek dialog
void _showTicketDetailsDialog(Map<String, dynamic> ticket) {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF1C2526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        ticket['subject'] ?? t['supportTicket'] ?? 'Support Ticket',
        style: GoogleFonts.roboto(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'User: ${ticket['username'] ?? 'Not Specified'} (ID: ${ticket['user_id'] ?? 'N/A'})',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Email: ${ticket['email'] ?? 'Not Specified'}',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Message: ${ticket['message']}',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Status: ${ticket['status'] ?? 'new'}',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Submitted at: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(ticket['submitted_at']))}',
              style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t['close'] ?? 'Close', style: GoogleFonts.roboto(color: Colors.grey[400])),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _showResponseDialog(ticket);
          },
          child: Text(t['respond'] ?? 'Respond', style: GoogleFonts.roboto(color: Colors.blueAccent)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Mark as Resolved', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                content: Text('Do you want to send an email notification to the user?', style: GoogleFonts.roboto()),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resolveSupportTicket(ticket['id']);
                    },
                    child: Text('No', style: GoogleFonts.roboto(color: Colors.grey[400])),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resolveSupportTicketWithEmail(
                        ticket['id'],
                        ticket['email'] ?? '',
                        ticket['subject'] ?? 'Support Ticket',
                      );
                    },
                    child: Text('Yes, send email', style: GoogleFonts.roboto(color: Colors.blueAccent)),
                  ),
                ],
              ),
            );
          },
          child: Text(t['resolve'] ?? 'Resolve', style: GoogleFonts.roboto(color: Colors.green)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Delete Ticket', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                content: Text('Are you sure you want to delete this ticket?', style: GoogleFonts.roboto()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _deleteSupportTicket(ticket['id']);
                    },
                    child: Text('Delete', style: GoogleFonts.roboto(color: Colors.redAccent)),
                  ),
                ],
              ),
            );
          },
          child: Text(t['delete'] ?? 'Delete', style: GoogleFonts.roboto(color: Colors.redAccent)),
        ),
      ],
    ),
  );
}

// Válasz dialog
void _showResponseDialog(Map<String, dynamic> ticket) {
  final t = translations[widget.selectedLanguage]!;
  final responseController = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Color(0xFF1C2526),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        t['respondToTicket'] ?? 'Respond to Ticket',
        style: GoogleFonts.roboto(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: responseController,
        decoration: InputDecoration(
          labelText: t['responseMessage'] ?? 'Response Message',
          filled: true,
          fillColor: Color(0xFF2A2F31),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          labelStyle: GoogleFonts.roboto(color: Colors.grey[400]),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: GoogleFonts.roboto(color: Colors.white),
        maxLines: 5,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t['cancel'] ?? 'Cancel', style: GoogleFonts.roboto(color: Colors.grey[400])),
        ),
        ElevatedButton(
          onPressed: () {
            if (responseController.text.trim().isEmpty) {
              _showSnackBar(t['responseRequired'] ?? 'Response message is required', Colors.red);
              return;
            }
            Navigator.pop(context);
            _sendResponseEmail(
              ticket['id'],
              ticket['email'] ?? '',
              ticket['subject'] ?? 'Support Ticket',
              responseController.text.trim(),
            );
            responseController.dispose();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(t['send'] ?? 'Send', style: GoogleFonts.roboto(fontSize: 16)),
        ),
      ],
    ),
  );
}

Widget _buildReportedContent() {
  final t = translations[widget.selectedLanguage]!;
  return _reportedContent.isEmpty
      ? Text(
          t['noReportedContent'] ?? 'No reported content.',
          style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 14),
        )
      : Column(
          children: [
            Stack(
              children: [
                GridView.builder(
                  controller: _reportedContentScrollController,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: _reportedContent.length,
                  itemBuilder: (context, index) {
                    final content = _reportedContent[index];
                    final title = content['title'] != null && content['title'].toString().isNotEmpty
                        ? content['title'].toString().length > 15
                            ? '${content['title'].toString().substring(0, 15)}...'
                            : content['title'].toString()
                        : 'Content';
                    return Card(
                      color: Color(0xFF2A2F31),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 1,
                      child: InkWell(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          final token = prefs.getString('token');
                          if (token == null) {
                            _showSnackBar('Authentication token not available', Colors.red);
                            return;
                          }
                          int? subtopicId;
                          if (content['type'] == 'post') {
                            if (content['subtopicId'] != null) {
                              subtopicId = content['subtopicId'] as int;
                            } else {
                              try {
                                final postResponse = await http.get(
                                  Uri.parse('https://localhost:7164/api/forum/subtopics/${content['contentId']}/posts'),
                                  headers: {'Authorization': 'Bearer $token'},
                                );
                                if (postResponse.statusCode == 200) {
                                  final posts = json.decode(postResponse.body) as List;
                                  final post = posts.firstWhere(
                                    (p) => p['id'] == content['contentId'],
                                    orElse: () => null,
                                  );
                                  if (post != null && post['subtopicId'] != null) {
                                    subtopicId = post['subtopicId'] as int;
                                  }
                                }
                              } catch (e) {
                                _showSnackBar('Error fetching post details: $e', Colors.red);
                                return;
                              }
                            }
                          } else if (content['type'] == 'subtopic') {
                            subtopicId = content['contentId'] as int;
                          }
                          if (subtopicId == null) {
                            _showSnackBar('Cannot navigate: Missing subtopic ID', Colors.red);
                            return;
                          }
                          try {
                            final response = await http.get(
                              Uri.parse('https://localhost:7164/api/forum/subtopics/$subtopicId'),
                              headers: {'Authorization': 'Bearer $token'},
                            );
                            if (response.statusCode == 200) {
                              final subtopic = json.decode(response.body);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SubtopicDetailsPage(
                                      subtopic: subtopic,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              _showSnackBar('Failed to fetch subtopic: ${response.body}', Colors.red);
                            }
                          } catch (e) {
                            _showSnackBar('Error fetching subtopic: $e', Colors.red);
                          }
                        },
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Type: ${content['type']}',
                                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                              ),
                              Text(
                                'By: ${content['reportedBy']}',
                                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 12),
                              ),
                              Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.check, color: Colors.green, size: 15),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Color(0xFF1C2526),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        title: Text(t['acceptReport'] ?? 'Accept Report', style: GoogleFonts.roboto(fontSize: 15)),
                                        content: Text(t['acceptReportConfirm'] ?? 'Mark this report as accepted without deleting the content?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(t['cancel'] ?? 'Cancel', style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 10)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _acceptReport(content['contentId'], content['type']);
                                            },
                                            child: Text(t['accept'] ?? 'Accept', style: GoogleFonts.roboto(color: Colors.green, fontSize: 10)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    tooltip: t['acceptReport'] ?? 'Accept Report',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.redAccent, size: 14),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: Color(0xFF1C2526),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        title: Text(t['deleteContent'] ?? 'Delete Content', style: GoogleFonts.roboto(fontSize: 14)),
                                        content: Text(t['deleteContentConfirm'] ?? 'Are you sure you want to delete this content?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(t['cancel'] ?? 'Cancel', style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 10)),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _deleteContent(content['contentId'], content['type']);
                                            },
                                            child: Text(t['delete'] ?? 'Delete', style: GoogleFonts.roboto(color: Colors.redAccent, fontSize: 10)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    tooltip: t['deleteContent'] ?? 'Delete Content',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Gomb a jobb felső sarokban
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: ElevatedButton(
                    onPressed: _isLoadingMoreReported ? null : _loadMoreReportedContent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: _isLoadingMoreReported
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            t['loadMore'] ?? 'Load More',
                            style: GoogleFonts.roboto(color: Colors.white, fontSize: 12),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
}

Future<void> _resolveSupportTicket(int ticketId) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  try {
    final response = await http.put(
      Uri.parse('https://localhost:7164/api/Admin/support-ticket/$ticketId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'status': 'resolved'}),
    );
    if (response.statusCode == 200) {
      _showSnackBar('Ticket marked as resolved', Colors.green);
      await _fetchSupportTickets(); // Frissítjük a listát
    } else {
      try {
        final errorData = json.decode(response.body);
        _showSnackBar('Failed to update ticket status: ${errorData['error'] ?? response.body}', Colors.red);
      } catch (_) {
        _showSnackBar('Failed to update ticket status: ${response.body}', Colors.red);
      }
    }
  } catch (e) {
    _showSnackBar('Error updating ticket status: $e', Colors.red);
  }
}


  // Új függvény a support ticketek megjelenítésére
Widget _buildSupportTickets() {
  final t = translations[widget.selectedLanguage] ?? translations['en']!;
  final filteredTickets = _supportTickets.where((ticket) => ticket['status'] != 'resolved').toList();

  return filteredTickets.isEmpty
      ? Text(
          t['noSupportTickets'] ?? 'No support tickets.',
          style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 18),
        )
      : Column(
          children: [
            Stack(
              children: [
                GridView.builder(
                  controller: _supportTicketsScrollController,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1.8,
                  ),
                  itemCount: filteredTickets.length,
                  itemBuilder: (context, index) {
                    final ticket = filteredTickets[index];
                    // Biztonságos substring használata
                    final subject = ticket['subject'] != null && ticket['subject'].toString().isNotEmpty
                        ? ticket['subject'].toString().length > 30
                            ? '${ticket['subject'].toString().substring(0, 30)}...'
                            : ticket['subject'].toString()
                        : 'Support Ticket';
                    return Card(
                      color: Color(0xFF2A2F31),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _showTicketDetailsDialog(ticket),
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: GoogleFonts.roboto(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'User: ${ticket['username'] ?? 'N/A'}',
                                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 16),
                              ),
                              Text(
                                'Status: ${ticket['status'] ?? 'new'}',
                                style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 16),
                              ),
                              Spacer(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Gomb a jobb alsó sarokban a további ticketek betöltéséhez
                Positioned(
                  bottom: 2,
                  right: 8,
                  child: ElevatedButton(
                    onPressed: _isLoadingMoreTickets ? null : _loadMoreSupportTickets,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: _isLoadingMoreTickets
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            t['loadMore'] ?? 'Load More',
                            style: GoogleFonts.roboto(color: Colors.white, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
            if (_isLoadingMoreTickets)
              Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Colors.blueAccent),
              ),
          ],
        );
}

// Ensure these methods are defined in _AdminPanelPageState
void _loadMoreSupportTickets() {
  if (!_isLoadingMoreTickets) {
    setState(() {
      _supportTicketsPage++;
      _isLoadingMoreTickets = true;
    });
    _fetchSupportTickets(isLoadMore: true).then((_) {
      if (mounted) {
        setState(() => _isLoadingMoreTickets = false);
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _isLoadingMoreTickets = false);
        _showSnackBar('Error loading more tickets: $e', Colors.red);
      }
    });
  }
}

Future<void> _fetchSupportTickets({bool isLoadMore = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  if (token == null) {
    _showSnackBar('Authentication token not available', Colors.red);
    return;
  }
  if (isLoadMore && mounted) {
    setState(() => _isLoadingMoreTickets = true);
  }
  try {
    final response = await http.get(
      Uri.parse('https://localhost:7164/api/Admin/support-tickets?page=$_supportTicketsPage&perPage=$_itemsPerPage'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      if (mounted) {
        setState(() {
          if (isLoadMore) {
            // Filter out duplicates based on ticket['id']
            final existingIds = _supportTickets.map((ticket) => ticket['id'] as int).toSet();
            final newTickets = data.cast<Map<String, dynamic>>().where((ticket) => !existingIds.contains(ticket['id'] as int)).toList();
            _supportTickets.addAll(newTickets);
          } else {
            _supportTickets = data.cast<Map<String, dynamic>>();
          }
          _isLoadingMoreTickets = false;
        });
      }
    } else {
      _showSnackBar('Failed to fetch support tickets: ${response.body}', Colors.red);
    }
  } catch (e) {
    _showSnackBar('Error fetching support tickets: $e', Colors.red);
  } finally {
    if (mounted && isLoadMore) {
      setState(() => _isLoadingMoreTickets = false);
    }
  }
}

  @override
  void dispose() {
    _userIdController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _statusController.dispose();
    _profileImageUrlController.dispose();
    _locationController.dispose();
    _contactEmailController.dispose();
    _userRankController.dispose();
    _signatureController.dispose();
    _languageController.dispose();
    _hashingAlgorithmController.dispose();
    _reportedContentScrollController.dispose();
    _supportTicketsScrollController.dispose();
    super.dispose();
  }
}

class FadeInAnimation extends StatefulWidget {
  final Widget child;
  const FadeInAnimation({super.key, required this.child});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}