import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../Services/auth_service.dart';
import 'ProfilePage.dart';
import '../Utils/Translations.dart';

class AIModelSite extends StatefulWidget {
  final String selectedLanguage;
  const AIModelSite({super.key, required this.selectedLanguage});

  @override
  _AIModelSiteState createState() => _AIModelSiteState();
}

class _AIModelSiteState extends State<AIModelSite> with TickerProviderStateMixin {
  PlatformFile? _image;
  List<Map<String, dynamic>>? _results;
  String? _annotatedImageBase64;
  bool _isLoading = false;
  bool? _isLoggedIn;
  String _selectedModel = 'Car Parts Recognizer';
  final List<String> _models = ['Car Parts Recognizer', 'Car Damage Level Detector'];
  bool _isButtonPressed = false;

 

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await AuthService().isUserLoggedIn();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
        });
      }
    } catch (e) {
      if (mounted) {
        _showWarning(context, '${_t('loginStatusError')}: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _image = result.files.first;
          _results = null;
          _annotatedImageBase64 = null;
        });
      } else if (mounted) {
        _showWarning(context, _t('noImageSelected'));
      }
    } catch (e) {
      if (mounted) {
        _showWarning(context, '${_t('imagePickError')}: $e');
      }
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null || _image!.bytes == null) {
      _showWarning(context, _t('noImage'));
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _results = null;
        _annotatedImageBase64 = null;
      });
    }

    try {
      String apiUrl = _selectedModel == 'Car Damage Level Detector'
          ? 'https://localhost:7164/api/cardamage/predict'
          : 'https://localhost:7164/api/prediction/predict';

      String? token = await AuthService().getToken();
      if (token == null) {
        throw Exception(_t('authError'));
      }

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _image!.bytes!,
          filename: _image!.name,
          contentType: _image!.extension != null
              ? MediaType('image', _image!.extension!)
              : MediaType('image', 'jpeg'),
        ),
      );

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var apiResult = jsonDecode(responseBody);
        if (mounted) {
          setState(() {
            if (_selectedModel == 'Car Damage Level Detector') {
              _results = (apiResult['predictions'] as List).map((result) {
                double confidence = (result['confidence'] as num).toDouble() * 100;
                return {
                  'Label': result['label'] as String? ?? 'Unknown',
                  'Confidence': confidence.clamp(0.0, 100.0),
                };
              }).toList();
              _annotatedImageBase64 = apiResult['annotatedImage'] as String?;
            } else {
              _results = (apiResult as List).map((result) {
                double confidence = (result['confidence'] as num).toDouble() * 100;
                return {
                  'Label': result['label'] as String? ?? 'Unknown',
                  'Confidence': confidence.clamp(0.0, 100.0),
                };
              }).toList();
            }
            _isLoading = false;
          });
          _showSuccess(context, _t('imageProcessed'));
        }
      } else {
        throw Exception('API request failed: ${response.statusCode} - $responseBody');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [{'Label': _t('error'), 'Confidence': 0.0}];
          _isLoading = false;
        });
        _showFailed(context, _formatErrorMessage(e.toString()));
      }
    }
  }

  String _formatErrorMessage(String error) {
    if (error.contains('Authentication')) {
      return _t('authError');
    } else if (error.contains('Model error') || error.contains('Prediction failed')) {
      return _t('modelError');
    } else if (error.contains('Failed to connect')) {
      return _t('connectionError');
    }
    return '${_t('error')}: $error';
  }

  String _t(String key) {
    return translations[widget.selectedLanguage]?[key] ?? translations['en']![key]!;
  }

  void _showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showFailed(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

 Widget _buildAnimatedButton({
  required String text,
  required List<Color> gradientColors,
  required VoidCallback? onTap,
}) {
  return GestureDetector(
    onTapDown: onTap != null ? (_) => setState(() => _isButtonPressed = true) : null,
    onTapUp: (_) => setState(() => _isButtonPressed = false),
    onTapCancel: () => setState(() => _isButtonPressed = false),
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      transform: Matrix4.identity()..scale(_isButtonPressed ? 0.95 : 1.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: onTap == null
              ? [Colors.grey[400]!, Colors.grey[600]!] // Disabled state
              : gradientColors, // Custom colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onTap == null ? Colors.grey[600]! : Colors.grey[700]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onTap == null ? Colors.grey[300] : Colors.white, // White for contrast
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  // Loading state with polished CircularProgressIndicator
  if (_isLoggedIn == null) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: const CircularProgressIndicator(
            strokeWidth: 6.0,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
    );
  }

  // Login prompt screen if not logged in
  if (_isLoggedIn == false) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t('appBarTitle'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 2,
        shadowColor: Colors.grey.withOpacity(0.2),
        backgroundColor: Colors.grey[900],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 500),
              child: Text(
                _t('loginPrompt'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildAnimatedButton(
              text: _t('goToProfile'),
              gradientColors: [Colors.grey[300]!, Colors.grey[500]!],
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(selectedLanguage: widget.selectedLanguage),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Main content with polished layout and animations
  return Scaffold(
    appBar: AppBar(
      title: Text(
        _t('AITools'),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 24,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      elevation: 2,
      shadowColor: Colors.grey.withOpacity(0.2),
      backgroundColor: Colors.grey[900],
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // AI model dropdown
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey[200]!, Colors.grey[300]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[400]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                value: _models.contains(_selectedModel)
                    ? _selectedModel
                    : _models.isNotEmpty
                        ? _models.first
                        : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                  labelText: _t('selectAIModel'),
                  labelStyle: TextStyle(
                    color: _isLoading ? Colors.grey : Colors.black54,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  disabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
                  ),
                ),
                items: _models.isNotEmpty
                    ? _models.map((model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            widget.selectedLanguage == 'en'
                                ? model
                                : model == 'Car Parts Recognizer'
                                    ? 'Autóalkatrész Felismerés'
                                    : 'Autókár Értékelés',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isLoading ? Colors.grey : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList()
                    : [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            _t('noModels'),
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                onChanged: _isLoading
                    ? null // Disable dropdown during loading
                    : (value) {
                        if (value != null && mounted) {
                          setState(() {
                            _selectedModel = value;
                            _results = null;
                            _annotatedImageBase64 = null;
                          });
                        }
                      },
                dropdownColor: Colors.grey[100],
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            // Image container sized to image
            AnimatedCrossFade(
              firstChild: Container(
                constraints: const BoxConstraints(
                  minHeight: 150,
                  minWidth: 150,
                  maxHeight: 150,
                  maxWidth: 250,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[200]!, Colors.grey[300]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _t('noImageSelected'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              secondChild: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _annotatedImageBase64 != null
                      ? Image.memory(
                          base64Decode(_annotatedImageBase64!),
                          fit: BoxFit.contain,
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (frame == null) {
                              return const Center(
                                child: CircularProgressIndicator(strokeWidth: 4.0),
                              );
                            }
                            return AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: child,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text(
                              'Error loading annotated image',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                          ),
                        )
                      : _image != null && _image!.bytes != null
                          ? Image.memory(
                              _image!.bytes!,
                              fit: BoxFit.contain,
                              width: 250,
                              height: 200,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (frame == null) {
                                  return const Center(
                                    child: CircularProgressIndicator(strokeWidth: 4.0),
                                  );
                                }
                                return AnimatedOpacity(
                                  opacity: 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  child: child,
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Text(
                                  'Error loading image',
                                  style: TextStyle(color: Colors.red, fontSize: 16),
                                ),
                              ),
                            )
                          : const Center(
                              child: Text(
                                'No image available',
                                style: TextStyle(color: Colors.red, fontSize: 16),
                              ),
                            ),
                ),
              ),
              crossFadeState: _image == null && _annotatedImageBase64 == null
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 300),
            ),
            const SizedBox(height: 16),
            // Buttons in a horizontal Row with distinct colors
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildAnimatedButton(
                  text: _t('selectImage'),
                  gradientColors: [Colors.blue[300]!, Colors.blue[500]!],
                  onTap: _pickImage,
                ),
                const SizedBox(width: 16),
                _buildAnimatedButton(
                  text: _t('classify'),
                  gradientColors: [Colors.green[300]!, Colors.green[500]!],
                  onTap: _image == null || _isLoading ? null : _classifyImage,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Loading or results with animations
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 5.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              )
            else if (_results != null && _results!.isNotEmpty) ...[
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _results!.where((result) => result['Confidence'] > 0.01).length,
                itemBuilder: (context, index) {
                  final filteredResults = _results!.where((result) => result['Confidence'] > 0.01).toList();
                  final result = filteredResults[index];
                  final isFirstHighConfidence = index == 0 && result['Confidence'] > 80;

                  return AnimatedSlide(
                    offset: Offset(0, index * 0.05),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isFirstHighConfidence ? Colors.green[100] : Colors.purple[100],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          title: Text(
                            result['Label'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              color: isFirstHighConfidence ? Colors.green[800] : Colors.purple[800],
                              letterSpacing: 0.2,
                            ),
                          ),
                          subtitle: Text(
                            '${_t('confidence')}: ${result['Confidence'].toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 15,
                              color: isFirstHighConfidence ? Colors.green[800] : Colors.purple[800],
                            ),
                          ),
                          trailing: Icon(
                            Icons.check_circle,
                            color: result['Confidence'] > 50
                                ? Colors.green
                                : isFirstHighConfidence
                                    ? Colors.green[800]
                                    : Colors.purple[800],
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ] else if (_results != null && _results!.isEmpty)
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: Text(
                    _t('noResults'),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}