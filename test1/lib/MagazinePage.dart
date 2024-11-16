import 'package:flutter/material.dart';


class MagazinePage extends StatelessWidget {
  const MagazinePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the width of the screen to determine if it's mobile
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 600; // Define mobile breakpoint

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Featured Article
            _buildFeatureArticleCard(
              title: 'Honda Prelude Rumoured to Come Back as Electric Sports Coupe',
              imagePath: 'assets/pictures/honda_prelude.jpg',
              onTap: () {},
            ),
            const SizedBox(height: 16),
            // Grid of 4 articles
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildArticleGrid(isMobile: isMobile), // Pass isMobile to grid
            ),
            const SizedBox(height: 10),
            // List of remaining articles
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildHorizontalArticleCard(
                    title: 'What Comes After F1, P1? The New McLaren “W1” Hypercar, of Course',
                    description: 'A new hypercar takes the spotlight with advanced technology.',
                    imagePath: 'assets/pictures/mclaren_hypercar.jpg',
                    isMobile: isMobile, // Pass isMobile to the card
                  ),
                  _buildHorizontalArticleCard(
                    title: '2025 BMW Z4 Manual Tested: Enjoy This Stick-Shift Roadster While It Lasts',
                    description: 'BMW brings back manual for its iconic Z4 model.',
                    imagePath: 'assets/pictures/bmw_z4.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '\$640,000 of Restomod Awesomeness! Driving the ’68 Mustang and ’70 F-100',
                    description: 'Iconic classics reimagined for modern drivers.',
                    imagePath: 'assets/pictures/mustang_f100.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2025 GMC Hummer EV SUV 3X vs. Rivian R1S Quad Ascend: Maximum Effort',
                    description: 'A head-to-head between two leading electric SUVs.',
                    imagePath: 'assets/pictures/suvs.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2024 Toyota Tacoma Trailhunter First Test: Toyota’s Factory Overlanding Rig Just Needs a Driver',
                    description: 'Toyota offers plenty of accessories, but the Trailhunter has what you need to go from the dealership to daring adventure.',
                    imagePath: 'assets/pictures/toyota_suv.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: 'The First Ferrari EV Is Coming in 2026: Here’s What We Know',
                    description: 'The company promises its new EV, built almost entirely in-house, will drive like a Ferrari.',
                    imagePath: 'assets/pictures/ferrari_suv.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2025 Porsche 911 GT3 RS Revealed: The Pinnacle of Precision Engineering',
                    description: 'Porsche delivers another track-ready marvel with its latest 911 GT3 RS, built for the purists.',
                    imagePath: 'assets/pictures/porsche_gt3rs.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: 'Tesla’s Cybertruck Nears Production: The Future of Electric Trucks?',
                    description: 'Elon Musk promises the Cybertruck will revolutionize the electric truck market with its unique design and features.',
                    imagePath: 'assets/pictures/tesla_cybertruck.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2026 Audi A9 e-Tron Unveiled: A Luxury EV Sedan with 500 Miles of Range',
                    description: 'Audi sets a new standard for electric luxury sedans with the A9 e-Tron, boasting impressive range and cutting-edge technology.',
                    imagePath: 'assets/pictures/audi_a9.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2025 Ford Bronco Raptor: The Off-Road Beast Gets a Power Boost',
                    description: 'The Bronco Raptor is back with more power, more capability, and even more off-road features for the ultimate adventure.',
                    imagePath: 'assets/pictures/bronco_raptor.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: 'The 2025 Lamborghini Revuelto Hybrid: The Future of Supercar Performance?',
                    description: 'Lamborghini enters the hybrid supercar market with the Revuelto, combining electric power with their iconic V12 engine.',
                    imagePath: 'assets/pictures/lamborghini_revuelto.jpg',
                    isMobile: isMobile,
                  ),
                  _buildHorizontalArticleCard(
                    title: '2024 Jeep Grand Cherokee 4xe: The Off-Roader Goes Green',
                    description: 'Jeep’s iconic Grand Cherokee gets an eco-friendly update with the 4xe plug-in hybrid model, offering power and efficiency.',
                    imagePath: 'assets/pictures/jeep_grand_cherokee.jpg',
                    isMobile: isMobile,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  
// Build grid of articles with responsive layout
Widget _buildArticleGrid({required bool isMobile}) {
  return GridView.count(
    crossAxisCount: isMobile ? 2 : 5,  // 2 columns for mobile, 4 for desktop
    crossAxisSpacing: 12, // Increased spacing for better visual separation
    mainAxisSpacing: 12,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Add padding around the grid
    children: [
      _buildSmallArticleCard(
        title: 'What Comes After F1, P1? The New McLaren “W1” Hypercar, of Course',
        imagePath: 'assets/pictures/mclaren_hypercar.jpg',
        isMobile: isMobile,
      ),
      _buildSmallArticleCard(
        title: '2025 BMW Z4 Manual Tested: Enjoy This Stick-Shift Roadster While It Lasts',
        imagePath: 'assets/pictures/bmw_z4.jpg',
        isMobile: isMobile, // Pass isMobile here
      ),
      _buildSmallArticleCard(
        title: '\$640,000 of Restomod Awesomeness! Driving the ’68 Mustang and ’70 F-100',
        imagePath: 'assets/pictures/mustang_f100.jpg',
        isMobile: isMobile, // Pass isMobile here
      ),
      _buildSmallArticleCard(
        title: '2025 GMC Hummer EV SUV 3X vs. Rivian R1S Quad Ascend: Maximum Effort',
        imagePath: 'assets/pictures/suvs.jpg',
        isMobile: isMobile, // Pass isMobile here
      ),
      _buildSmallArticleCard(
        title: 'The First Ferrari EV Is Coming in 2026: Here’s What We Know',
        imagePath: 'assets/pictures/ferrari_suv.jpg',
        isMobile: isMobile, // Pass isMobile here
      ),
    ],
  );
}

// Build individual small article card for grid
Widget _buildSmallArticleCard({required String title, required String imagePath, required bool isMobile}) {
  return Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12), // Rounded corners for a softer look
    ),
    elevation: 4, // Slightly lower elevation for a subtle shadow
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Article Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.asset(
            imagePath,
            fit: BoxFit.cover,
            height: isMobile ? 75 : 200, // Height adjustment for mobile
            width: double.infinity,
          ),
        ),
        // Title
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 20, // Smaller font size for mobile
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis, // Handle overflow gracefully
            maxLines: 10, // Limit title to 2 lines
          ),
        ),
      ],
    ),
  );
}



  // Build horizontal article card (image on the left, text on the right)
  Widget _buildHorizontalArticleCard({
    required String title,
    required String description,
    required String imagePath,
    required bool isMobile, // Pass isMobile to adjust layout
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 5,
      child: Row(
        children: [
          // Article Image on the left
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
              height: isMobile ? 150 : 200, // Adjust height for mobile
              width: isMobile ? 120 : 300, // Adjust width for mobile
            ),
          ),
          // Title and description on the right
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20, // Adjust font size for mobile
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16, // Adjust font size for mobile
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

    // Build the featured article card
  Widget _buildFeatureArticleCard({
    required String title,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 5,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // Ellenőrizd a képernyő magasságát és szélességét
            double height = constraints.maxWidth < 600 ? 200 : 350; // 250 telefonon, 350 nagyobb képernyőkön
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Featured Article Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    height: height, // Dinamikus magasság
                    width: double.infinity,
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24, // Increase font size for visibility
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
