import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'CreateListingPage.dart';

class MarketplacePage extends StatefulWidget {
  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  late Future<List<Car>> _cars;
  bool isLoggedIn = true; // Ezt a változót valós bejelentkezési állapottal cseréld le

  @override
  void initState() {
    super.initState();
    _cars = getCars();
  }

  Future<List<Car>> getCars() async {
    const String apiUrl = 'https://localhost:7164/api/Forum/carlistings';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((carJson) => Car.fromJson(carJson)).toList();
      } else {
        throw Exception('Failed to load cars');
      }
    } catch (e) {
      throw Exception('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Marketplace'),
      ),
      body: Column(
        children: [
          if (isLoggedIn)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) =>  CreateCarListingsPage()),
                  );
                },
                child: const Text('Add New Car Listing'),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Car>>(
              future: _cars,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No cars available.'));
                }

                List<Car> cars = snapshot.data!;

                return ListView.builder(
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    Car car = cars[index];
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(car.title),
                        subtitle: Text('${car.location} - ${car.mileage} km'),
                        trailing: Text('\$${car.price}'),
                        onTap: () {
                          // Handle tap event here, e.g., navigate to car details
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
