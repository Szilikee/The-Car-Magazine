import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../Utils/Translations.dart';

class CalendarPage extends StatefulWidget {
  final String selectedLanguage;

  const CalendarPage({super.key, required this.selectedLanguage});

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  String? selectedOption;
  List<dynamic> data = [];
  String? selectedYear = "2024";
  bool isLoading = false;
  bool _isDisposed = false; // Track disposal state


  @override
  void initState() {
    super.initState();
    selectedOption = "Races"; // Set default option
    fetchData();
  }

  @override
  void didUpdateWidget(CalendarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage != widget.selectedLanguage) {
      // Language has changed, refresh the data or UI
      fetchData();
    }
  }

  Future<void> fetchData() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      isLoading = true;
    });

    String url = selectedOption == "Races"
        ? 'http://ergast.com/api/f1/$selectedYear.json'
        : 'https://api.openf1.org/v1/drivers';

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
      );

      if (_isDisposed || !mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        setState(() {
          if (selectedOption == "Races") {
            data = jsonResponse['MRData']['RaceTable']['Races'] ?? [];
          } else {
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
      if (_isDisposed || !mounted) return;
      print('Error: $e');
      setState(() {
        data = [];
      });
    } finally {
      if (_isDisposed || !mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true; // Mark as disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int crossAxisCount = selectedOption == "Races" ? 4 : 6;
    double aspectRatio = selectedOption == "Races" ? 1.2 : 0.6;

    return Scaffold(
      appBar: AppBar(
        title: Text(translations[widget.selectedLanguage]!['appBarTitle']!),
        centerTitle: true,
      ),
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
                    hint: Text(translations[widget.selectedLanguage]!['chooseCategory']!),
                    onChanged: (String? newValue) {
                      if (_isDisposed || !mounted) return;
                      setState(() {
                        selectedOption = newValue!;
                      });
                      fetchData();
                    },
                    items: [
                      DropdownMenuItem(value: "Races", child: Text(translations[widget.selectedLanguage]!['races']!)),
                      DropdownMenuItem(value: "Drivers", child: Text(translations[widget.selectedLanguage]!['drivers']!)),
                    ],
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                    dropdownColor: Colors.grey[800],
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                if (selectedOption == "Races")
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedYear,
                      hint: Text(translations[widget.selectedLanguage]!['chooseYear']!),
                      onChanged: (String? newValue) {
                        if (_isDisposed || !mounted) return;
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
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                      dropdownColor: Colors.grey[800],
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? Center(child: Text(translations[widget.selectedLanguage]!['loading']!))
                  : data.isEmpty
                      ? Center(child: Text(translations[widget.selectedLanguage]!['noData']!))
                      : GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: aspectRatio,
                          ),
                          itemCount: data.length > 20 ? 20 : data.length,
                          itemBuilder: (context, index) {
                            if (selectedOption == "Drivers" &&
                                (data[index]['headshot_url'] == null ||
                                    data[index]['headshot_url'] == "")) {
                              return const SizedBox.shrink();
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
    String flagUrl = "https://flagcdn.com/w2560/$countryCode.png";
    String wikiUrl = race['url'] ?? 'https://en.wikipedia.org/wiki/Formula_One';

    if (countryCode == "un") {
      flagUrl = "https://flagcdn.com/w2560/ae.png"; // Default UAE flag
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
        hoverColor: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4.0),
        child: Card(
          elevation: 2,
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
                      race['raceName'] ?? translations[widget.selectedLanguage]!['unknownLocation']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "${translations[widget.selectedLanguage]!['date']}: ${race['date'] ?? 'N/A'}",
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "${translations[widget.selectedLanguage]!['location']}: ${race['Circuit']['circuitName'] ?? translations[widget.selectedLanguage]!['unknownLocation']!}",
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
                        height: 290,
                        errorBuilder: (context, error, stackTrace) => _errorImage(),
                      ),
                    )
                  : _errorImage(),
              Expanded(
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
                      infoRow(Icons.numbers, "${translations[widget.selectedLanguage]?['driverNumber'] ?? 'Driver Number'}: ${driver['driver_number'] ?? 'N/A'}"),
                      infoRow(Icons.flag, "${translations[widget.selectedLanguage]?['nationality'] ?? 'Nationality'}: ${driver['country_code'] ?? 'N/A'}"),
                      infoRow(Icons.sports_motorsports, "${translations[widget.selectedLanguage]?['team'] ?? 'Team'}: ${driver['team_name'] ?? 'N/A'}"),
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
    const String imageUrl = "https://cdn-icons-png.flaticon.com/512/74/74472.png";

    return Container(
      height: 290,
      color: Colors.grey[800],
      child: Center(
        child: GestureDetector(
          onTap: () async {
            if (await canLaunchUrl(Uri.parse(imageUrl))) {
              await launchUrl(Uri.parse(imageUrl), mode: LaunchMode.externalApplication);
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
      "Qatar": "qa",
      "UAE": "ae",
      "Malaysia": "my",
      "British": "gb",
      "Azerbaijan": "az",
      "Abu Dhabi": "ae",
      "Miami": "us",
      "USA": "us",
      "UK": "gb",
    };

    return countryCodes[country] ?? "un";
  }
}