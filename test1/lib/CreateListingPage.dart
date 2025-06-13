import 'dart:io' as io show File if (dart.library.html) 'dart:html';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Translations.dart';


class CreateCarListingsPage extends StatefulWidget {
  final String selectedLanguage;
  const CreateCarListingsPage({super.key, required this.selectedLanguage});

  @override
  _CreateCarListingsPageState createState() => _CreateCarListingsPageState();
}

class _CreateCarListingsPageState extends State<CreateCarListingsPage> {
  // Controllers for text fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController kmController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController vinController = TextEditingController();
  final TextEditingController engineCapacityController = TextEditingController();
  final TextEditingController horsepowerController = TextEditingController();
  final TextEditingController bodyTypeController = TextEditingController();
  final TextEditingController customColorController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // Dropdown values
  String? selectedFuel;
  String? selectedSellerType;
  String? selectedTransmission;
  String? selectedColor;
  String? selectedCondition;
  String? selectedSteeringSide;
  String? selectedRegistrationStatus;
  String? selectedNumberOfDoors;
  List<bool> _isUploadingImages = [false, false, false, false, false]; // Képfeltöltési állapotok
  // Dropdown options
  final List<String> fuelOptions = ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid'];
  final List<String> sellerTypeOptions = ['Private Person', 'Dealer'];
  final List<String> transmissionOptions = ['Manual', 'Automatic'];
  final List<String> colorOptions = ['White', 'Black', 'Gray', 'Red', 'Blue', 'Green', 'Other'];
  final List<String> conditionOptions = ['New', 'Used'];
  final List<String> steeringSideOptions = ['Left Side', 'Right Side'];
  final List<String> registrationStatusOptions = ['Registered', 'Unregistered'];
  final List<String> numberOfDoorsOptions = ['2', '3', '4', '5'];
  bool _isUploadingImage = false;
  // Image handling
  List<XFile?> _images = [null, null, null, null, null]; // Store up to 5 images
  List<Uint8List?> _imageBytes = [null, null, null, null, null]; // For web image bytes
  final ImagePicker _picker = ImagePicker();
  List<String?> _imageUrls = [null, null, null, null, null]; // Store Cloudinary URLs

  static const String apiUrl = 'https://localhost:7164/api/marketplace/addcar';

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
        });
      } else {
        setState(() {
          _images[index] = pickedFile;
        });
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile? image, int index) async {
  if (image == null) return null;

  setState(() => _isUploadingImages[index] = true);

  const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
  final apiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  if (apiKey.isEmpty || uploadPreset.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['configError'] ?? 'Cloudinary konfigurációs hiba')),
    );
    setState(() => _isUploadingImages[index] = false);
    return null;
  }

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
    print('Cloudinary válasz státuszkód: ${response.statusCode}');
    print('Cloudinary válasz: $responseData');

    if (response.statusCode == 200) {
      var jsonData = jsonDecode(responseData);
      return jsonData['secure_url'];
    } else {
      throw Exception('${t['imageUploadFailed'] ?? 'Nem sikerült a kép feltöltése'}: ${response.statusCode} - $responseData');
    }
  } catch (e) {
    print('Képfeltöltési hiba: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${t['imageUploadFailed'] ?? 'Képfeltöltési hiba'}: $e')),
    );
    return null;
  } finally {
    setState(() => _isUploadingImages[index] = false);
  }
}
  // Function to create listing
  
Future<void> _createListing() async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['fillAllFields'] ?? 'Minden kötelező mezőt ki kell tölteni!')),
    );
    return;
  }

  // Numerikus mezők validálása
  final year = int.tryParse(yearController.text);
  final price = double.tryParse(priceController.text);
  final kmDriven = int.tryParse(kmController.text);
  if (year == null || price == null || kmDriven == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t['invalidNumber'] ?? 'Érvénytelen számformátum!')),
    );
    return;
  }

  setState(() => _isLoading = true);
  try {
    // Token lekérése
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['loginFailed'] ?? 'Kérjük, jelentkezzen be!')),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Képek feltöltése
    for (int i = 0; i < _images.length; i++) {
      if (_images[i] != null) {
        print('Kép feltöltése Cloudinary-ra (index: $i)...');
        _imageUrls[i] = await _uploadImageToCloudinary(_images[i], i);
        if (_imageUrls[i] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t['imageUploadFailed'] ?? 'Nem sikerült a(z)'} ${i + 1}. ${t['image'] ?? 'képet feltölteni'}')),
          );
          setState(() => _isLoading = false);
          return;
        }
        print('Kép feltöltve (index: $i), URL: ${_imageUrls[i]}');
      }
    }

    var url = Uri.parse(apiUrl);
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    var body = jsonEncode({
      'Name': nameController.text,
      'Year': year,
      'SellingPrice': price,
      'KmDriven': kmDriven,
      'Fuel': selectedFuel,
      'SellerType': selectedSellerType,
      'Transmission': selectedTransmission,
      'Contact': contactController.text,
      'ImageUrl': _imageUrls[0] ?? '',
      'ImageUrl2': _imageUrls[1] ?? '',
      'ImageUrl3': _imageUrls[2] ?? '',
      'ImageUrl4': _imageUrls[3] ?? '',
      'ImageUrl5': _imageUrls[4] ?? '',
      'Vin': vinController.text.isEmpty ? null : vinController.text,
      'EngineCapacity': int.tryParse(engineCapacityController.text),
      'Horsepower': int.tryParse(horsepowerController.text),
      'BodyType': bodyTypeController.text.isEmpty ? null : bodyTypeController.text,
      'Color': selectedColor == 'Other' ? customColorController.text : selectedColor,
      'NumberOfDoors': int.tryParse(selectedNumberOfDoors ?? '') ?? 0,
      'Condition': selectedCondition, // Javítsd 'condition_'-ról 'Condition'-re
      'SteeringSide': selectedSteeringSide,
      'RegistrationStatus': selectedRegistrationStatus,
      'Description': descriptionController.text.isEmpty ? null : descriptionController.text,
    });

    var response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t['listingCreated'] ?? 'Hirdetés sikeresen létrehozva!')),
      );
      Navigator.pop(context);
    } else {
      var errorMessage = 'Hiba: ${response.statusCode}';
      try {
        final jsonResponse = jsonDecode(response.body);
        errorMessage = jsonResponse['message'] ?? errorMessage;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${t['error'] ?? 'Hiba'}: $errorMessage')),
      );
    }
  } catch (e) {
    print('Hálózati hiba: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${t['networkError'] ?? 'Hálózati hiba'}: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}


  bool _isLoading = false;
  
  get t => null;

  @override
  void initState() {
    super.initState();
    dotenv.load(fileName: ".env");
  }

    @override
  Widget build(BuildContext context) {
    final t = translations[widget.selectedLanguage] ?? translations['en']!;
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
                      colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                );
              },
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
                    colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
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
                      tooltip: t['back'] ?? 'Back',
                    ),
                    Expanded(
                      child: Text(
                        t['createListing'] ?? 'Create New Listing',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade800.withOpacity(0.85),
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
                        Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: List.generate(5, (index) {
    return Column(
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
                  if (_isUploadingImage && _imageUrls[index] == null)
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
    );
  }),
),
                          const SizedBox(height: 20),
                          _isLoading
                              ? const CircularProgressIndicator(color: Colors.tealAccent)
                              : ElevatedButton(
                                  onPressed: _createListing,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text(t['createListingButton'] ?? 'Create Listing', style: const TextStyle(fontSize: 16)),
                                ),
                        ],
                      ),
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

  // Text field builder
  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
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
          labelStyle: TextStyle(color: Colors.grey[400]),
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
        style: const TextStyle(color: Colors.white),
        dropdownColor: Colors.blueGrey.shade700,
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
