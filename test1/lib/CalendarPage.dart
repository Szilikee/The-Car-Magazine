import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String? selectedOption;
  List<dynamic> data = [];
  String? selectedYear = "2024";
  bool isLoading = false;
  

  @override
  void initState() {
    super.initState();
    fetchData();
  }

 Future<void> fetchData() async {
  setState(() => isLoading = true);

  String url = selectedOption == "Races"
      ? 'http://ergast.com/api/f1/$selectedYear.json'
      : 'https://api.openf1.org/v1/drivers';

  try {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 5),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      setState(() {
        if (selectedOption == "Races") {
          data = jsonResponse['MRData']['RaceTable']['Races'] ?? [];
        } else {
          // Remove duplicates by converting to a Set based on full_name, then back to a List
          List<dynamic> drivers = jsonResponse;
          data = drivers.fold<List<dynamic>>(
            [],
            (uniqueList, driver) {
              if (!uniqueList.any((d) => d['full_name'] == driver['full_name'])) {
                uniqueList.add(driver);
              }
              return uniqueList;
            },
          );
        }
      });
    } else {
      throw Exception('API ERROR!');
    }
  } catch (e) {
    print('Error: $e');
    setState(() {
      data = [];
    });
  } finally {
    setState(() => isLoading = false);
  }
}

@override
Widget build(BuildContext context) {
  int crossAxisCount = selectedOption == "Races" ? 4 : 6;
double aspectRatio = selectedOption == "Races" ? 1.2 : 0.6; // Kisebb érték a Driver kártyáknál


  return Scaffold(
    appBar: AppBar(title: const Text("F1 Teams & Races"), centerTitle: true),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedOption,
                  hint: const Text("Choose Category"), // Hint when nothing is selected
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedOption = newValue!;
                    });
                    fetchData();
                  },
                  items: const [
                    DropdownMenuItem(value: "Races", child: Text("Races")),
                    DropdownMenuItem(value: "Drivers", child: Text("Drivers")),
                  ],
                  style: const TextStyle(fontSize: 16, color: Colors.white), // Text style
                  dropdownColor: Colors.grey[800], // Background color of dropdown
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white), // Dropdown arrow
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  borderRadius: BorderRadius.circular(8.0), // Rounded corners
                ),
              ),
              if (selectedOption == "Races")
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedYear,
                    hint: const Text("Choose Year"), // Hint when nothing is selected
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedYear = newValue!;
                      });
                      fetchData();
                    },
                    items: List.generate(
                      DateTime.now().year - 1950 + 1,
                      (index) => (1950 + index).toString(),
                    ).map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    style: const TextStyle(fontSize: 16, color: Colors.white), // Text style
                    dropdownColor: Colors.grey[800], // Background color of dropdown
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white), // Dropdown arrow
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    borderRadius: BorderRadius.circular(8.0), // Rounded corners
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text("No accessible data."))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: data.length > 20 ? 20 : data.length, // Max 53 elem
                        itemBuilder: (context, index) {
                          if (selectedOption == "Drivers" &&
                              (data[index]['headshot_url'] == null ||
                                  data[index]['headshot_url'] == "")) {
                            return SizedBox.shrink(); // Nem jelenítünk meg semmit
                          }
                          return selectedOption == "Races"
                              ? raceCard(data[index])
                              : driverCard(data[index]);
                        },
                      ),
          )
        ],
      ),
    ),
  );
}
 
 
Widget raceCard(dynamic race) {
  String country = race['Circuit']['Location']['country'] ?? 'Unknown';
  String countryCode = getCountryCode(country);
  String flagUrl = "https://flagcdn.com/w2560/${countryCode}.png";
  String wikiUrl = race['url'] ?? 'https://en.wikipedia.org/wiki/Formula_One';

  if (countryCode == "un") {
    flagUrl = "https://flagcdn.com/w2560/ae.png"; // Default UAE flag
  }

  return MouseRegion(
    cursor: SystemMouseCursors.click, // Hand icon on hover
    child: InkWell(
      onTap: () async {
        final Uri url = Uri.parse(wikiUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          print('Could not launch $wikiUrl');
        }
      },
      hoverColor: Colors.grey.withOpacity(0.2), // Slight grey overlay on hover
      borderRadius: BorderRadius.circular(4.0), // Match Card's default radius
      child: Card(
        elevation: 2, // Default elevation
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              flagUrl,
              fit: BoxFit.cover,
              height: 280,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => _errorImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    race['raceName'] ?? "No name",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    "Date: ${race['date'] ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Location: ${race['Circuit']['circuitName'] ?? 'Ismeretlen'}",
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



Widget driverCard(dynamic driver) {
  String wikiUrl =
      'https://en.wikipedia.org/wiki/${driver['first_name'] ?? ''}_${driver['last_name'] ?? ''}';

  Color teamColor = Colors.grey;
  if (driver['team_colour'] != null) {
    try {
      teamColor = Color(int.parse("0xFF${driver['team_colour']}"));
    } catch (e) {
      print("Invalid color format: ${driver['team_colour']}");
    }
  }

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: InkWell(
      onTap: () async {
        final Uri url = Uri.parse(wikiUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          print('Could not launch $wikiUrl');
        }
      },
      hoverColor: teamColor,
      borderRadius: BorderRadius.circular(8.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          driver['headshot_url'] != null && driver['headshot_url'] != ""
                ? ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8.0)),
                    child: Image.network(
                      driver['headshot_url'],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 290, // Kép magasságának beállítása
                      errorBuilder: (context, error, stackTrace) => _errorImage(),
                    ),
                  )
                : _errorImage(),
            Expanded( // Szöveges rész kitöltése, hogy ne legyen overflow
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['full_name'] ?? "No name provided",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    infoRow(Icons.numbers, "Driver Number: ${driver['driver_number'] ?? 'N/A'}"),
                    infoRow(Icons.flag, "Nationality: ${driver['country_code'] ?? 'N/A'}"),
                    infoRow(Icons.sports_motorsports, "Team: ${driver['team_name'] ?? 'N/A'}"),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: teamColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8.0)),
              ),
              child: Center(
                child: Text(
                  driver['team_name'] ?? "Retired",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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



// Kisebb segédfüggvény az ismétlődő sorokhoz
Widget infoRow(IconData icon, String text, {bool isLink = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: isLink ? Colors.blue.shade700 : Colors.white,
            fontWeight: isLink ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}



Widget _errorImage() {
  final String imageUrl = "https://cdn-icons-png.flaticon.com/512/74/74472.png";

  return Container(
    height: 290,
    color: Colors.grey[800],
    child: Center(
      child: GestureDetector(
        onTap: () async {
          if (await canLaunch(imageUrl)) {
            await launch(imageUrl);
          }
        },
        child: Image.network(imageUrl),
      ),
    ),
  );
}

String getCountryCode(String country) {
  Map<String, String> countryCodes = {
    "Australia": "au",
    "United Kingdom": "gb",
    "United States": "us",
    "Italy": "it",
    "France": "fr",
    "Germany": "de",
    "Spain": "es",
    "Canada": "ca",
    "Brazil": "br",
    "Japan": "jp",
    "Mexico": "mx",
    "Netherlands": "nl",
    "United Arab Emirates": "ae",
    "Saudi Arabia": "sa",
    "Hungary": "hu",
    "Belgium": "be",
    "Singapore": "sg",
    "Austria": "at",
    "Monaco": "mc",
    "Bahrain": "bh",
    "China": "cn",
    "South Korea": "kr",
    "Qatar" : "qa",
    "UAE" : "ae",
    "Malaysia" : "my",
    "British": "gb",
    "Azerbaijan": "az",
    "Abu Dhabi": "ae",
    "Miami": "us",
    "USA": "us",
    "UK": "gb",
  };

  return countryCodes[country] ?? "un"; // Return default if not found
}
}