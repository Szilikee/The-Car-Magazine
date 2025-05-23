import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreateCarListingsPage extends StatefulWidget {
  const CreateCarListingsPage({super.key});

  @override
  _CreateCarListingsPageState createState() => _CreateCarListingsPageState();
}

class _CreateCarListingsPageState extends State<CreateCarListingsPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController kmController = TextEditingController();
  final TextEditingController fuelController = TextEditingController();
  final TextEditingController sellerController = TextEditingController();
  final TextEditingController transmissionController = TextEditingController();
  final TextEditingController ownerController = TextEditingController();

  // Use XFile instead of File for cross-platform compatibility
  XFile? _image;
  Uint8List? _imageBytes; // For web image preview
  final ImagePicker _picker = ImagePicker();
  String? _imageUrl;

  static const String apiUrl = 'https://localhost:7164/api/forum/addcar';

  // Function to pick an image from gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        // On web, read image bytes for preview
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _image = pickedFile;
          _imageBytes = bytes;
        });
      } else {
        // On mobile, use XFile directly
        setState(() {
          _image = pickedFile;
        });
      }
    }
  }

  // Function to upload image to Cloudinary
  Future<String?> _uploadImageToCloudinary() async {
  if (_image == null) return null;

  const String cloudinaryUrl = 'https://api.cloudinary.com/v1_1/dshksou7u/image/upload';
  print('Cloudinary URL: $cloudinaryUrl');
  print('API Key: 156576676194584');
  print('Upload Preset: marketplace_preset'); // Módosítva a helyes névre

  try {
    var request = http.MultipartRequest('POST', Uri.parse(cloudinaryUrl));
    request.fields['api_key'] = '156576676194584';
    request.fields['upload_preset'] = 'marketplace_preset'; // Módosítva a helyes névre
    if (kIsWeb) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        await _image!.readAsBytes(),
        filename: _image!.name,
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));
    }

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    print('Cloudinary válasz státuszkód: ${response.statusCode}');
    print('Cloudinary válasz: $responseData');

    if (response.statusCode == 200) {
      var jsonData = jsonDecode(responseData);
      return jsonData['secure_url'];
    } else {
      throw Exception('Nem sikerült a kép feltöltése: ${response.statusCode} - $responseData');
    }
  } catch (e) {
    print('Képfeltöltési hiba: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Képfeltöltési hiba: $e')),
    );
    return null;
  }
}

  Future<void> _createListing() async {
  if (nameController.text.isEmpty ||
      yearController.text.isEmpty ||
      priceController.text.isEmpty ||
      kmController.text.isEmpty ||
      fuelController.text.isEmpty ||
      sellerController.text.isEmpty ||
      transmissionController.text.isEmpty ||
      ownerController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Minden mezőt ki kell tölteni!')),
    );
    return;
  }

  try {
    // Kép feltöltése Cloudinary-ra, ha van kiválasztott kép
    if (_image != null) {
      print('Kép feltöltése Cloudinary-ra...');
      _imageUrl = await _uploadImageToCloudinary();
      if (_imageUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nem sikerült a képet feltölteni')),
        );
        return;
      }
      print('Kép feltöltve, URL: $_imageUrl');
    } else {
      print('Nincs kép kiválasztva, üres image_url használata');
      _imageUrl = '';
    }

    var url = Uri.parse(apiUrl);
    var headers = {
      'Content-Type': 'application/json',
      // JWT token hozzáadása, ha szükséges
      // 'Authorization': 'Bearer $yourJwtToken',
    };
  var body = jsonEncode({
    'Name': nameController.text,
    'Year': int.tryParse(yearController.text) ?? 0,
    'SellingPrice': int.tryParse(priceController.text) ?? 0,
    'KmDriven': int.tryParse(kmController.text) ?? 0,
    'Fuel': fuelController.text,
    'SellerType': sellerController.text,
    'Transmission': transmissionController.text,
    'Owner': ownerController.text,
    'ImageUrl': _imageUrl ?? '',
  });

    print('Kérés küldése a backendnek: $url');
    print('Kérés body: $body');
    var response = await http.post(url, headers: headers, body: body);
    var responseBody = response.body;
    print('Válasz státuszkód: ${response.statusCode}');
    print('Válasz body: $responseBody');

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hirdetés sikeresen létrehozva!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba: ${response.statusCode} - $responseBody')),
      );
    }
  } catch (e) {
    print('Hálózati hiba: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Hálózati hiba: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Listing')),
      body: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 5,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(nameController, 'Car Name'),
                    _buildTextField(yearController, 'Year', isNumber: true),
                    _buildTextField(priceController, 'Selling Price (€)', isNumber: true),
                    _buildTextField(kmController, 'Kilometers Driven', isNumber: true),
                    _buildTextField(fuelController, 'Fuel Type'),
                    _buildTextField(sellerController, 'Seller Type'),
                    _buildTextField(transmissionController, 'Transmission'),
                    _buildTextField(ownerController, 'Owner'),
                    const SizedBox(height: 20),
                    // Image preview
                    _image != null
                        ? kIsWeb
                            ? Image.memory(_imageBytes!, height: 100, width: 100, fit: BoxFit.cover)
                            : Image.network(_image!.path, height: 100, width: 100, fit: BoxFit.cover)
                        : const Text('No image selected'),
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Pick Image'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _createListing,
                      child: const Text('Create Listing'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    yearController.dispose();
    priceController.dispose();
    kmController.dispose();
    fuelController.dispose();
    sellerController.dispose();
    transmissionController.dispose();
    ownerController.dispose();
    super.dispose();
  }
}