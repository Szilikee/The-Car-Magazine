import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CreateCarListingsPage extends StatelessWidget {
  CreateCarListingsPage({super.key});

  final TextEditingController titleController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Listing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Car Title'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: mileageController,
              decoration: const InputDecoration(labelText: 'Mileage'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Price'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newCar = Car(
                  title: titleController.text,
                  imagePath: 'assets/pictures/default.jpg', // Placeholder image
                  location: locationController.text,
                  mileage: mileageController.text,
                  price: priceController.text,
                );

                try {
                  await ApiService().createCar(newCar);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New listing created!')),
                  );
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Create Listing'),
            ),
          ],
        ),
      ),
    );
  }
}

class ApiService {
  static const String apiUrl = 'https://localhost:7164/cars'; // Az API URL

  Future<void> createCar(Car car) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(car.toJson()),
    );

    if (response.statusCode == 201) {
      // Sikeres létrehozás
    } else {
      throw Exception('Failed to create listing');
    }
  }
}

class Car {
  final String title;
  final String imagePath;
  final String location;
  final String mileage;
  final String price;

  Car({
    required this.title,
    required this.imagePath,
    required this.location,
    required this.mileage,
    required this.price,
  });

  // fromJson method to convert JSON data to Car object
  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      title: json['title'] as String,
      imagePath: json['imagePath'] as String,
      location: json['location'] as String,
      mileage: json['mileage'] as String,
      price: json['price'] as String,
    );
  }

  // toJson method to convert Car object to JSON data
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'imagePath': imagePath,
      'location': location,
      'mileage': mileage,
      'price': price,
    };
  }
}
