// Topic modell
class Topic {
  final int id;
  final String title;
  final DateTime createdAt;

  Topic({required this.id, required this.title, required this.createdAt});

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] as int,
      title: json['title'] ?? 'No title',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
    );
  }
}

// Subtopic osztály
class Subtopic {
  final int id;
  final String title;
  final DateTime createdAt;
  final int topicId;
  final String? description;
  final String? username;

  Subtopic({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.topicId,
    this.description,
    this.username,
  });

  factory Subtopic.fromJson(Map<String, dynamic> json) {
    return Subtopic(
      id: json['id'] as int,
      title: json['title'] ?? 'No title',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toString()),
      topicId: json['topicId'] as int,
      description: json['description'] as String?,
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topicId': topicId,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'description': description,
      'username': username,
    };
  }
}

// Post modell
class Post {
  final int id;
  final String content;
  final DateTime createdAt;

  Post({required this.id, required this.content, required this.createdAt});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      content: json['content'] ?? 'No content',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
    );
  }
}


class Car {
  final int id;
  final String title;
  final int year;
  final double price;
  final int mileage;
  final String fuel;
  final String sellerType;
  final String transmission;
  final String contact;
  final String imagePath; // Required
  final String? imagePath2; // Optional
  final String? imagePath3; // Optional
  final String? imagePath4; // Optional
  final String? imagePath5; // Optional
  final String? vin;
  final int? engineCapacity;
  final int? horsepower;
  final String? bodyType;
  final String? color;
  final int? numberOfDoors;
  final String? condition;
  final String? steeringSide;
  final String? registrationStatus;
  final String? description;

  Car({
    required this.id,
    required this.title,
    required this.year,
    required this.price,
    required this.mileage,
    required this.fuel,
    required this.sellerType,
    required this.transmission,
    required this.contact,
    required this.imagePath,
    this.imagePath2,
    this.imagePath3,
    this.imagePath4,
    this.imagePath5,
    this.vin,
    this.engineCapacity,
    this.horsepower,
    this.bodyType,
    this.color,
    this.numberOfDoors,
    this.condition,
    this.steeringSide,
    this.registrationStatus,
    this.description,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      id: json['id']?.toInt() ?? 0,
      title: json['name']?.toString() ?? 'Unknown Car',
      year: json['year']?.toInt() ?? 0,
      price: json['sellingPrice']?.toDouble() ?? json['selling_price']?.toDouble() ?? 0.0,
      mileage: json['kmDriven']?.toInt() ?? json['km_driven']?.toInt() ?? 0,
      fuel: json['fuel']?.toString() ?? 'Unknown',
      sellerType: json['sellerType']?.toString() ?? json['seller_type']?.toString() ?? 'Unknown',
      transmission: json['transmission']?.toString() ?? 'Unknown',
      contact: json['contact']?.toString().trim() ?? 'Unknown',
      imagePath: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
      imagePath2: json['imageUrl2']?.toString() ?? json['image_url2']?.toString(),
      imagePath3: json['imageUrl3']?.toString() ?? json['image_url3']?.toString(),
      imagePath4: json['imageUrl4']?.toString() ?? json['image_url4']?.toString(), // Ensure mapping
      imagePath5: json['imageUrl5']?.toString() ?? json['image_url5']?.toString(), // Ensure mapping
      vin: json['vin']?.toString(),
      engineCapacity: json['engineCapacity']?.toInt(),
      horsepower: json['horsepower']?.toInt(),
      bodyType: json['bodyType']?.toString(),
      color: json['color']?.toString(),
      numberOfDoors: json['numberOfDoors']?.toInt(),
      condition: json['condition_']?.toString(), // Fixed typo: removed duplicate condition_
      steeringSide: json['steeringSide']?.toString(),
      registrationStatus: json['registrationStatus']?.toString(),
      description: json['description']?.toString() ?? 'No description available',
    );
  }

  @override
  String toString() => 'Car(id: $id, title: $title, year: $year, price: $price, imagePath: $imagePath, imagePath4: $imagePath4, imagePath5: $imagePath5)';
}

class CarListing {
  final int id;
  final int userId;
  final String name;
  final int year;
  final double sellingPrice;
  final int kmDriven;
  final String fuel;
  final String sellerType;
  final String transmission;
  final String contact;
  final String? imageUrl;
  final String? imageUrl2;
  final String? imageUrl3;
  final String? imageUrl4;
  final String? imageUrl5;
  final String? vin;
  final int? engineCapacity;
  final int? horsepower;
  final String? bodyType;
  final String? color;
  final int? numberOfDoors;
  final String? condition;
  final String? steeringSide;
  final String? registrationStatus;
  final String? description;

  CarListing({
    required this.id,
    required this.userId,
    required this.name,
    required this.year,
    required this.sellingPrice,
    required this.kmDriven,
    required this.fuel,
    required this.sellerType,
    required this.transmission,
    required this.contact,
    this.imageUrl,
    this.imageUrl2,
    this.imageUrl3,
    this.imageUrl4,
    this.imageUrl5,
    this.vin,
    this.engineCapacity,
    this.horsepower,
    this.bodyType,
    this.color,
    this.numberOfDoors,
    this.condition,
    this.steeringSide,
    this.registrationStatus,
    this.description,
  });

  factory CarListing.fromJson(Map<String, dynamic> json) {
    return CarListing(
      id: json['id'],
      userId: json['userId'],
      name: json['name'] ?? '',
      year: json['year'] ?? 0,
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      kmDriven: json['kmDriven'] ?? 0,
      fuel: json['fuel'] ?? '',
      sellerType: json['sellerType'] ?? '',
      transmission: json['transmission'] ?? '',
      contact: json['contact'] ?? '',
      imageUrl: json['imageUrl'],
      imageUrl2: json['imageUrl2'],
      imageUrl3: json['imageUrl3'],
      imageUrl4: json['imageUrl4'],
      imageUrl5: json['imageUrl5'],
      vin: json['vin'],
      engineCapacity: json['engineCapacity'],
      horsepower: json['horsepower'],
      bodyType: json['bodyType'],
      color: json['color'],
      numberOfDoors: json['numberOfDoors'],
      condition: json['condition_'],
      steeringSide: json['steeringSide'],
      registrationStatus: json['registrationStatus'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'year': year,
      'sellingPrice': sellingPrice,
      'kmDriven': kmDriven,
      'fuel': fuel,
      'sellerType': sellerType,
      'transmission': transmission,
      'contact': contact,
      'imageUrl': imageUrl,
      'imageUrl2': imageUrl2,
      'imageUrl3': imageUrl3,
      'imageUrl4': imageUrl4,
      'imageUrl5': imageUrl5,
      'vin': vin,
      'engineCapacity': engineCapacity,
      'horsepower': horsepower,
      'bodyType': bodyType,
      'color': color,
      'numberOfDoors': numberOfDoors,
      'condition_': condition,
      'steeringSide': steeringSide,
      'registrationStatus': registrationStatus,
      'description': description,
    };
  }
}


class Article {
  final int id;
  final int userId;
  final String title;
  final String description;
  final String imageUrl;
  final String category;
  final String placement;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  Article({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.placement,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      category: json['category'] as String? ?? 'N/A',
      placement: json['placement'] as String? ?? 'list',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
    );
  }
}