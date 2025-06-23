import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:photo_view/photo_view.dart';
import '../Services/auth_service.dart'; // Import the AuthService
import '../Models/Models.dart';

class ListingDetailsPage extends StatelessWidget {
  final Car car;
  final AuthService _authService = AuthService(); // Instance of AuthService

  ListingDetailsPage({super.key, required this.car});

  // Beágyazott metódus a szerepkör lekérdezésére
  Future<String?> fetchUserRole() async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('No auth token found. User is likely not logged in.');
        return null;
      }

      final response = await http.get(
        Uri.parse('https://localhost:7164/api/User/me'), // API endpoint a szerepkör lekérdezésére
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return userData['role'] as String?;
      } else {
        print('Failed to fetch user role, status: ${response.statusCode}, body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  // Delete listing function
  Future<void> _deleteListing(BuildContext context, int carId) async {
    final token = await _authService.getToken();
    if (token == null) {
      showFailed(context, 'Authentication required');
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse('https://localhost:7164/api/admin/marketplace/$carId'), // New endpoint
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        showSuccess(context, 'Listing deleted successfully');
        Navigator.pop(context); // Return to previous screen
      } else {
        showFailed(context, 'Failed to delete listing: ${response.body}');
      }
    } catch (e) {
      showFailed(context, 'Error deleting listing: $e');
    }
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: details),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use only available image paths (max 5, min 1 if imagePath exists)
    final List<String?> imageUrls = [
      car.imagePath.isNotEmpty ? car.imagePath : null,
      car.imagePath2,
      car.imagePath3,
      car.imagePath4,
      car.imagePath5,
    ];
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final String imagePath = 'assets/pictures/backgroundimage.png';

    // Filter out null or empty image URLs and calculate dynamic image width
    final List<String?> validImageUrls = imageUrls.where((url) => url != null && url.isNotEmpty).toList();
    final int imageCount = validImageUrls.isNotEmpty ? validImageUrls.length : 0;
    final double fixedImageWidth = 350.0; 
    final double spacing = 8.0;

    return Scaffold(
      body: Stack(
        children: [
          // Background Image
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
              // Custom Title Bar with Back Button
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
                        '${car.title} (${car.year})',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer to balance back button
                  ],
                ),
              ),
              // Main Content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        // Car Images
                        if (validImageUrls.isNotEmpty)
                          SizedBox(
                            height: fixedImageWidth,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(imageCount, (index) {
                                  final imageUrl = validImageUrls[index];
                                  return Padding(
                                    padding: EdgeInsets.symmetric(horizontal: index > 0 ? spacing / 2 : 0.0),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PhotoViewPage(imageUrl: imageUrl),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl!,
                                          fit: BoxFit.cover,
                                          width: fixedImageWidth,
                                          height: fixedImageWidth,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(child: CircularProgressIndicator(color: Colors.tealAccent));
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[300],
                                              width: fixedImageWidth,
                                              height: fixedImageWidth,
                                              child: Center(child: Text('Image not available')),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Delete Button for Admin
                        FutureBuilder<String?>(
                          future: fetchUserRole(), // Használjuk a beágyazott metódust
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink(); // Loading state
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return const SizedBox.shrink(); // No role or error
                            }
                            if (snapshot.data == 'admin') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: ElevatedButton(
                                  onPressed: () => _deleteListing(context, car.id),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete Listing'),
                                ),
                              );
                            }
                            return const SizedBox.shrink(); // Non-admin users
                          },
                        ),
                        // Car Title
                        Text(
                          '${car.title} (${car.year})',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Car Price
                        Text(
                          '${car.price} €',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Basic Information
                        _buildDetailSection('Basic Information', [
                          _buildDetailRow('Mileage', '${car.mileage} km'),
                          _buildDetailRow('Fuel', car.fuel),
                          _buildDetailRow('Transmission', car.transmission),
                          _buildDetailRow('Seller Type', car.sellerType),
                          _buildDetailRow('Contact', car.contact),
                        ]),
                        // Technical Details
                        if (car.vin != null ||
                            car.engineCapacity != null ||
                            car.horsepower != null ||
                            car.bodyType != null ||
                            car.color != null ||
                            car.numberOfDoors != null)
                          _buildDetailSection('Technical Details', [
                            if (car.vin != null) _buildDetailRow('VIN', car.vin!),
                            if (car.engineCapacity != null)
                              _buildDetailRow('Engine Capacity', '${car.engineCapacity} cc'),
                            if (car.horsepower != null)
                              _buildDetailRow('Horsepower', '${car.horsepower} hp'),
                            if (car.bodyType != null) _buildDetailRow('Body Type', car.bodyType!),
                            if (car.color != null) _buildDetailRow('Color', car.color!),
                            if (car.numberOfDoors != null)
                              _buildDetailRow('Doors', car.numberOfDoors.toString()),
                          ]),
                        // Condition and Registration
                        if (car.condition != null ||
                            car.steeringSide != null ||
                            car.registrationStatus != null)
                          _buildDetailSection('Condition and Registration', [
                            if (car.condition != null) _buildDetailRow('Condition', car.condition!),
                            if (car.steeringSide != null)
                              _buildDetailRow('Steering Side', car.steeringSide!),
                            if (car.registrationStatus != null)
                              _buildDetailRow('Registration', car.registrationStatus!),
                          ]),
                        // Description
                        if (car.description != null && car.description!.isNotEmpty)
                          _buildDescriptionSection('Description', car.description!),
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

// New page for photo zooming (unchanged)
class PhotoViewPage extends StatelessWidget {
  final String imageUrl;

  const PhotoViewPage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey.shade900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.white)));
          },
        ),
      ),
    );
  }
}