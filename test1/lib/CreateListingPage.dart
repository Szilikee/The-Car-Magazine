import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  static const String apiUrl = 'https://localhost:7164/api/forum/addcar'; 

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
        const SnackBar(content: Text('All fields must be filled!')),
      );
      return;
    }

    try {
      var url = Uri.parse(apiUrl);
      var headers = {'Content-Type': 'application/json'};
      var body = jsonEncode({
        'name': nameController.text,
        'year': int.tryParse(yearController.text) ?? 0, // Convert to int
        'selling_price': int.tryParse(priceController.text) ?? 0, // Convert to int
        'km_driven': int.tryParse(kmController.text) ?? 0, // Convert to int
        'fuel': fuelController.text,
        'seller_type': sellerController.text,
        'transmission': transmissionController.text,
        'owner': ownerController.text,
      });

      var response = await http.post(url, headers: headers, body: body);
      var responseBody = response.body;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing successfully created!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.statusCode} - $responseBody')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Create New Listing')),
    body: Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5, // Max 90% szélesség
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 5,
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                ElevatedButton(onPressed: _createListing, child: const Text('Create Listing')),
              ],
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
}
