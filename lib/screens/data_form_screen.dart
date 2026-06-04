import 'package:flutter/material.dart';
import 'package:mortality_analysis/screens/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class DataFormScreen extends StatefulWidget {
  const DataFormScreen({super.key});

  @override
  State<DataFormScreen> createState() => _DataFormScreenState();
}

class _DataFormScreenState extends State<DataFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final Box _offlineBox = Hive.box('offline_records');

  // Controllers
  final nameC = TextEditingController();
  final ageC = TextEditingController();
  final durationOfIllnessC = TextEditingController();
  final specificLocalityC = TextEditingController(); 
  final otherCauseC = TextEditingController();
  final otherConditionC = TextEditingController();

  // Selected State Parameters
  String? province;
  String? district;
  String? tehsil;
  String? areaType; 
  String? gender;
  String? causeOfDeath;
  String? placeOfDeath;
  
  // Analytics Parameters
  String? waterSource;
  String? incomeBracket;

  DateTime? selectedDate;
  List<String> medicalConditions = [];

  // ---------------- DATA STATIC GEOGRAPHIC HIERARCHY MAPS ----------------
  final List<String> provinceList = ["Punjab", "Sindh", "KPK", "Balochistan", "AJK", "Gilgit-Baltistan"];

  final Map<String, List<String>> districtMap = {
    "Punjab": ["Lahore", "Rawalpindi", "Faisalabad", "Multan", "Gujranwala", "Sialkot", "Jhelum"],
    "Sindh": ["Karachi Central", "Karachi South", "Hyderabad", "Sukkur", "Larkana", "Mirpurkhas"],
    "KPK": ["Peshawar", "Abbottabad", "Mardan", "Swat", "Mansehra", "Kohat"],
    "Balochistan": ["Quetta", "Gwadar", "Khuzdar", "Sibi", "Hub"],
    "AJK": ["Muzaffarabad", "Mirpur", "Kotli", "Bhimber", "Rawalakot"],
    "Gilgit-Baltistan": ["Gilgit", "Skardu", "Hunza", "Diamer"],
  };

  final Map<String, List<String>> tehsilMap = {
    "Lahore": ["Lahore City", "Lahore Cantt", "Model Town", "Raiwind", "Shalimar"],
    "Rawalpindi": ["Rawalpindi", "Gujar Khan", "Kahuta", "Taxila", "Murree"],
    "Faisalabad": ["Faisalabad City", "Faisalabad Sadar", "Chak Jhumra", "Jaranwala", "Sammundri", "Tandlianwala"],
    "Multan": ["Multan City", "Multan Saddar", "Shujabad", "Jalalpur Pirwala"],
    "Gujranwala": ["Gujranwala City", "Gujranwala Saddar", "Kamoke", "Nowshera Virkan", "Wazirabad"],
    "Sialkot": ["Sialkot", "Daska", "Pasrur", "Sambrial"],
    "Jhelum": ["Jhelum", "Dina", "Sohawa", "Pind Dadan Khan"],
    "Karachi Central": ["Gulberg", "Liaquatabad", "Nazimabad", "North Nazimabad"],
    "Karachi South": ["Lyari", "Saddar", "Aram Bagh"],
    "Hyderabad": ["Hyderabad City", "Hyderabad Latifabad", "Hyderabad Qasimabad"],
    "Sukkur": ["Sukkur", "Rohri", "Pano Akil", "Salehpat"],
    "Larkana": ["Larkana", "Ratodero", "Bakrani", "Dokri"],
    "Mirpurkhas": ["Mirpurkhas", "Digri", "Kot Ghulam Muhammad", "Jhuddo"],
    "Peshawar": ["Peshawar City", "Shah Alam", "Saddar", "Hayatabad"],
    "Abbottabad": ["Abbottabad", "Havelian"],
    "Mardan": ["Mardan", "Takht Bhai", "Katlang"],
    "Swat": ["Babuzai", "Matta", "Khwazakhela", "Barikot", "Kaball", "Charbagh"],
    "Mansehra": ["Mansehra", "Balakot", "Oghi", "Baffa Pakhal"],
    "Kohat": ["Kohat", "Lachi"],
    "Quetta": ["Quetta City", "Chiltan", "Zarghoon"],
    "Gwadar": ["Gwadar", "Pasni", "Ormara", "Jiwanl"],
    "Khuzdar": ["Khuzdar", "Wadh", "Nall", "Moola"],
    "Sibi": ["Sibi", "Harnai"],
    "Hub": ["Hub", "Dureji"],
    "Muzaffarabad": ["Muzaffarabad", "Naseerabad"],
    "Mirpur": ["Mirpur", "Dadyal"],
    "Kotli": ["Kotli", "Sehnsa", "Charhoi"],
    "Bhimber": ["Bhimber", "Barnala", "Samahni"],
    "Rawalakot": ["Rawalakot", "Hajira"],
    "Gilgit": ["Gilgit City", "Danyor", "Juglot"],
    "Skardu": ["Skardu Town", "Rondu", "Gambal"],
    "Hunza": ["Aliabad", "Gojal"],
    "Diamer": ["Chilas", "Tangir"],
  };

  final List<String> causeOptions = [
    "Heart Attack / Cardiac Arrest",
    "Cancer / Tumor",
    "Brain Stroke / Paralysis",
    "Respiratory Failure (Lung Issues)",
    "Kidney Failure",
    "Liver Disease / Hepatitis",
    "Diabetes Complications",
    "Accident / Trauma",
    "Old Age Natural Death",
    "Other"
  ];

  final List<String> conditionOptions = [
    "Diabetes (Sugar)",
    "High Blood Pressure",
    "Heart Disease",
    "Asthma / Breathing Issues",
    "Chronic Kidney Disease",
    "Liver Issues",
    "None",
    "Other"
  ];

  // ---------------- HELPER GEOGRAPHIC ANALYSIS LIST GETTERS ----------------
  List<String> get currentDistricts => province != null ? (districtMap[province] ?? []) : [];
  List<String> get currentTehsils => district != null ? (tehsilMap[district] ?? []) : [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncOfflineRecords();
    });
  }

  @override
  void dispose() {
    nameC.dispose();
    ageC.dispose();
    durationOfIllnessC.dispose();
    specificLocalityC.dispose();
    otherCauseC.dispose();
    otherConditionC.dispose();
    super.dispose();
  }

  void toggleCondition(String value) {
    setState(() {
      if (value == "None") {
        medicalConditions = ["None"];
        otherConditionC.clear();
      } else {
        medicalConditions.remove("None");
        if (medicalConditions.contains(value)) {
          medicalConditions.remove(value);
          if (value == "Other") otherConditionC.clear();
        } else {
          medicalConditions.add(value);
        }
      }
    });
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  // --- FIXED LOGOUT METHOD WITH SECURE CONTEXT HANDLING ---
  Future<void> confirmLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        print("Supabase SignOut error or session already expired: $e");
      }

      if (!mounted) return;
      
      // Clean navigation stack completely back to the Login Screen route
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> syncOfflineRecords() async {
    if (_offlineBox.isEmpty) return;
    final keys = List.from(_offlineBox.keys);
    for (var key in keys) {
      final Map<dynamic, dynamic>? rawRecord = _offlineBox.get(key);
      if (rawRecord == null) continue;
      final Map<String, dynamic> strictRecord = Map<String, dynamic>.from(rawRecord);

      try {
        await Supabase.instance.client.from("mortality_records").insert(strictRecord);
        await _offlineBox.delete(key);
      } catch (e) {
        print("🚨 OFFLINE SYNC TIMED OUT OR REJECTED: $e");
        return;
      }
    }
    _show("All offline synchronization queues successfully completed!", Colors.green.shade700);
  }

  // ---------------- RECORD SUBMISSION ENGINE ----------------
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      _show("Please choose a valid Date of Death", Colors.red.shade700);
      return;
    }

    final String finalizedCause = (causeOfDeath == "Other" && otherCauseC.text.isNotEmpty)
        ? "Other: ${otherCauseC.text.trim()}"
        : causeOfDeath ?? "Unknown";

    List<String> finalizedConditions = List.from(medicalConditions);
    if (finalizedConditions.contains("Other") && otherConditionC.text.isNotEmpty) {
      finalizedConditions.remove("Other");
      finalizedConditions.add("Other: ${otherConditionC.text.trim()}");
    }

    final Map<String, dynamic> record = {
      "patient_name": nameC.text.trim().isEmpty ? "Anonymous" : nameC.text.trim(),
      "age": int.tryParse(ageC.text.trim()) ?? 0,
      "gender": gender,
      "province": province,
      "district": district,
      "tehsil": tehsil,
      "area_type": areaType,
      "specific_locality": specificLocalityC.text.trim(), 
      "cause_of_death": finalizedCause,
      "duration_of_illness": durationOfIllnessC.text.trim().isEmpty ? "Not Specified" : durationOfIllnessC.text.trim(),
      "prior_medical_conditions": finalizedConditions, 
      "place_of_death": placeOfDeath,
      "water_source": waterSource,
      "income_bracket": incomeBracket,
      "date_of_death": selectedDate!.toIso8601String().split("T")[0],
      "created_at": DateTime.now().toIso8601String(),
    };

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client.from("mortality_records").insert(record);

_show("Saved directly to Cloud Storage", Colors.green.shade700);

_resetForm();

// 🔥 IMPORTANT: force list refresh if you're using another screen
if (mounted) {
  setState(() {});
}

syncOfflineRecords();
    } catch (supabaseError) {
      await _offlineBox.add(record);
      _show("Saved Offline (Cloud write error protection active)", Colors.orange.shade800);
      _resetForm();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    nameC.clear();
    ageC.clear();
    durationOfIllnessC.clear();
    specificLocalityC.clear();
    otherCauseC.clear();
    otherConditionC.clear();
    setState(() {
      province = null;
      district = null;
      tehsil = null;
      areaType = null;
      gender = null;
      causeOfDeath = null;
      placeOfDeath = null;
      waterSource = null;
      incomeBracket = null;
      medicalConditions = [];
      selectedDate = null;
    });
  }

  void _show(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: GoogleFonts.poppins()), backgroundColor: c)
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        centerTitle: true, 
        title: Text(
          "Mortality Records Registry",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: isWide ? 22 : 18),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: confirmLogout),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- SECTION 1: PERSONAL PARAMETERS ---
                  _card([
                    TextFormField(
                      controller: nameC,
                      decoration: const InputDecoration(labelText: "Full Name (Leave blank if anonymous)"),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ageC,
                            keyboardType: TextInputType.number, 
                            decoration: const InputDecoration(labelText: "Age (Years)"),
                            validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _dropdown("Gender", ["Male", "Female", "Other"], gender, true, (v) {
                            setState(() => gender = v);
                          }, null),
                        ),
                      ],
                    ),
                  ]),

                  // --- SECTION 2: GEOGRAPHIC DEPENDENCY HIERARCHY ---
                  _card([
                    _dropdown("Province", provinceList, province, true, (v) {
                      setState(() {
                        province = v;
                        district = null; 
                        tehsil = null;   
                      });
                    }, null),
                    const SizedBox(height: 12),
                    _dropdown(
                      "District", 
                      currentDistricts, 
                      district, 
                      true, 
                      (v) {
                        setState(() {
                          district = v;
                          tehsil = null; 
                        });
                      },
                      province == null ? "Select Province First" : null,
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      "Tehsil", 
                      currentTehsils, 
                      tehsil, 
                      true, 
                      (v) => setState(() => tehsil = v),
                      district == null ? "Select District First" : null,
                    ),
                  ]),

                  // --- SECTION 3: LOCALITY METRICS ---
                  _card([
                    _dropdown("Area Type", ["Urban", "Rural"], areaType, true, (v) {
                      setState(() => areaType = v);
                    }, null),
                    if (areaType != null) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: specificLocalityC,
                        decoration: InputDecoration(
                          labelText: areaType == "Rural" 
                              ? "Village / Chak details *" 
                              : "City Locality details *",
                          hintText: areaType == "Rural"
                              ? "e.g. Chak 12-L, Near Mosque"
                              : "e.g. Sector G-11/2, Street 4, House 12",
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Please provide locality details" : null,
                      ),
                    ]
                  ]),

                  // --- SECTION 4: CAUSE METRICS ---
                  _card([
                    _dropdown("Primary Cause of Death", causeOptions, causeOfDeath, true, (v) {
                      setState(() {
                        causeOfDeath = v;
                        if (v != "Other") otherCauseC.clear();
                      });
                    }, null),
                    if (causeOfDeath == "Other") ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: otherCauseC,
                        decoration: const InputDecoration(labelText: "Specify Custom Medical Cause"),
                        validator: (v) => (causeOfDeath == "Other" && (v == null || v.trim().isEmpty)) ? "Required" : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: durationOfIllnessC,
                      decoration: const InputDecoration(labelText: "Duration of Illness (e.g., 2 Weeks, 5 Years, Sudden)"),
                      validator: (v) => (v == null || v.isEmpty) ? "Required" : null,
                    ),
                  ]),

                  // --- SECTION 5: COMORBIDITIES ---
                  _card([
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text("Prior Medical Conditions", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: conditionOptions.map((e) {
                        final selected = medicalConditions.contains(e);
                        return FilterChip(
                          label: Text(e),
                          selected: selected,
                          selectedColor: Colors.indigo.shade100,
                          checkmarkColor: Colors.indigo.shade900,
                          onSelected: (_) => toggleCondition(e),
                        );
                      }).toList(),
                    ),
                    if (medicalConditions.contains("Other")) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: otherConditionC,
                        decoration: const InputDecoration(labelText: "Specify Other Chronic Disease"),
                        validator: (v) => (medicalConditions.contains("Other") && (v == null || v.trim().isEmpty)) ? "Please specify" : null,
                      ),
                    ]
                  ]),

                  // --- SECTION 6: SOCIO-ENVIRONMENTAL METRICS ---
                  _card([
                    _dropdown("Place of Death", ["Hospital", "Home", "Workplace / Farm", "En Route / Accident Site"], placeOfDeath, true, (v) => setState(() => placeOfDeath = v), null),
                    const SizedBox(height: 12),
                    _dropdown("Primary Water Source Type", ["Filtered / Clean Tap Water", "Borehole / Motor Well", "Open Hand Pump / Canal / Unfiltered Well"], waterSource, true, (v) => setState(() => waterSource = v), null),
                    const SizedBox(height: 12),
                    _dropdown("Estimated Socio-Economic Bracket", ["Lower Income Segment", "Middle Income Segment", "Upper Income Segment"], incomeBracket, true, (v) => setState(() => incomeBracket = v), null),
                  ]),

                  // --- SECTION 7: DATE SELECTION ---
                  _card([
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selectedDate == null ? "Select Date of Death *" : "Date Selected: ${selectedDate.toString().split(" ")[0]}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selectedDate == null ? Colors.red.shade700 : Colors.indigo.shade900
                        ),
                      ),
                      trailing: Icon(Icons.calendar_month, color: Colors.indigo.shade900),
                      onTap: pickDate,
                    )
                  ]),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade900,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveData,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("SUBMIT ANALYTICS RECORD", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  // --- REPAIRED DROPDOWN WIDGET METHOD USING SYSTEM EXPLICIT VALUE MAPPING ---
  Widget _dropdown(String label, List<String> items, String? value, bool isRequired, ValueChanged<String?> onChanged, String? hintText) {
    // Prevent rendering validation mismatch errors by enforcing checking constraints
    final bool hasHint = hintText != null;
    final bool validValue = value != null && items.contains(value);

    return DropdownButtonFormField<String>(
      initialValue: validValue ? value : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
      ),
      items: hasHint ? null : items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
      onChanged: hasHint ? null : onChanged,
      validator: (v) => (isRequired && !hasHint && v == null) ? "Required field" : null,
    );
  }
}
