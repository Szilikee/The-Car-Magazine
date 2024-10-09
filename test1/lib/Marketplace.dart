import 'package:flutter/material.dart';
//import 'package:flutter_cache_manager/flutter_cache_manager.dart';
//import 'dart:convert';
//import 'package:http/http.dart' as http;
//import 'package:intl/intl.dart';

class MarketplacePage extends StatelessWidget {
  const MarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
      ),
      body: GridView.count(
        crossAxisCount: 2,  // 2 items per row
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMarketplaceItem('Car 1', 'assets/pictures/car1.jpg'),
          _buildMarketplaceItem('Car 2', 'assets/pictures/car2.jpg'),
          _buildMarketplaceItem('Car 3', 'assets/pictures/car3.jpg'),
          _buildMarketplaceItem('Car 4', 'assets/pictures/car4.jpg'),
        ],
      ),
    );
  }

  Widget _buildMarketplaceItem(String title, String imagePath) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(imagePath, fit: BoxFit.cover, height: 150),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}