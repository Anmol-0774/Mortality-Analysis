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

  // ══════════════════════════════════════════════════════
  // CONTROLLERS
  // ══════════════════════════════════════════════════════

  final nameC = TextEditingController();
  final ageC = TextEditingController();
  final durationOfIllnessC = TextEditingController();
  final specificLocalityC = TextEditingController();
  final otherCauseC = TextEditingController();
  final otherConditionC = TextEditingController();

  // ══════════════════════════════════════════════════════
  // SELECTED VALUES
  // ══════════════════════════════════════════════════════

  String? province;
  String? district;
  String? tehsil;
  String? areaType;
  String? gender;
  String? causeOfDeath;
  String? placeOfDeath;

  // OPTIONAL ANALYTICS PARAMETERS
  String? waterSource;
  String? incomeBracket;

  DateTime? selectedDate;

  List<String> medicalConditions = [];

  // ══════════════════════════════════════════════════════
  // ENHANCED COLOR PALETTE
  // ══════════════════════════════════════════════════════

  static const Color primary = Color(0xFF1E293B);
  static const Color primaryLight = Color(0xFFF1F5F9);
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentLight = Color(0xFFDBEAFE);
  static const Color accentGradient1 = Color(0xFF3B82F6);
  static const Color accentGradient2 = Color(0xFF8B5CF6);
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGrey = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color cardShadow = Color(0xFF0F172A);
  static const Color green = Color(0xFF10B981);
  static const Color greenLight = Color(0xFFD1FAE5);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeLight = Color(0xFFFEF3C7);
  static const Color red = Color(0xFFEF4444);
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleLight = Color(0xFFEDE9FE);
  static const Color teal = Color(0xFF14B8A6);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseLight = Color(0xFFFEE2E2);
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoLight = Color(0xFFE0E7FF);

  // ══════════════════════════════════════════════════════
  // GEOGRAPHIC DATA
  // ══════════════════════════════════════════════════════

  final List<String> provinceList = [
    "Punjab",
    "Sindh",
    "KPK",
    "Balochistan",
    "AJK",
    "Gilgit-Baltistan",
  ];

  final Map<String, List<String>> districtMap = {
    "Punjab": [
      "Lahore",
      "Rawalpindi",
      "Faisalabad",
      "Multan",
      "Gujranwala",
      "Sialkot",
      "Jhelum"
    ],
    "Sindh": [
      "Karachi Central",
      "Karachi South",
      "Hyderabad",
      "Sukkur",
      "Larkana",
      "Mirpurkhas"
    ],
    "KPK": [
      "Peshawar",
      "Abbottabad",
      "Mardan",
      "Swat",
      "Mansehra",
      "Kohat"
    ],
    "Balochistan": [
      "Quetta",
      "Gwadar",
      "Khuzdar",
      "Sibi",
      "Hub"
    ],
    "AJK": [
      "Muzaffarabad",
      "Mirpur",
      "Kotli",
      "Bhimber",
      "Rawalakot"
    ],
    "Gilgit-Baltistan": [
      "Gilgit",
      "Skardu",
      "Hunza",
      "Diamer"
    ],
  };

  final Map<String, List<String>> tehsilMap = {
    "Lahore": [
      "Lahore City",
      "Lahore Cantt",
      "Model Town",
      "Raiwind",
      "Shalimar"
    ],
    "Rawalpindi": [
      "Rawalpindi",
      "Gujar Khan",
      "Kahuta",
      "Taxila",
      "Murree"
    ],
    "Faisalabad": [
      "Faisalabad City",
      "Faisalabad Sadar",
      "Chak Jhumra",
      "Jaranwala",
      "Sammundri",
      "Tandlianwala"
    ],
    "Multan": [
      "Multan City",
      "Multan Saddar",
      "Shujabad",
      "Jalalpur Pirwala"
    ],
    "Gujranwala": [
      "Gujranwala City",
      "Gujranwala Saddar",
      "Kamoke",
      "Nowshera Virkan",
      "Wazirabad"
    ],
    "Sialkot": [
      "Sialkot",
      "Daska",
      "Pasrur",
      "Sambrial"
    ],
    "Jhelum": [
      "Jhelum",
      "Dina",
      "Sohawa",
      "Pind Dadan Khan"
    ],
    "Karachi Central": [
      "Gulberg",
      "Liaquatabad",
      "Nazimabad",
      "North Nazimabad"
    ],
    "Karachi South": [
      "Lyari",
      "Saddar",
      "Aram Bagh"
    ],
    "Hyderabad": [
      "Hyderabad City",
      "Hyderabad Latifabad",
      "Hyderabad Qasimabad"
    ],
    "Sukkur": [
      "Sukkur",
      "Rohri",
      "Pano Akil",
      "Salehpat"
    ],
    "Larkana": [
      "Larkana",
      "Ratodero",
      "Bakrani",
      "Dokri"
    ],
    "Mirpurkhas": [
      "Mirpurkhas",
      "Digri",
      "Kot Ghulam Muhammad",
      "Jhuddo"
    ],
    "Peshawar": [
      "Peshawar City",
      "Shah Alam",
      "Saddar",
      "Hayatabad"
    ],
    "Abbottabad": [
      "Abbottabad",
      "Havelian"
    ],
    "Mardan": [
      "Mardan",
      "Takht Bhai",
      "Katlang"
    ],
    "Swat": [
      "Babuzai",
      "Matta",
      "Khwazakhela",
      "Barikot",
      "Kaball",
      "Charbagh"
    ],
    "Mansehra": [
      "Mansehra",
      "Balakot",
      "Oghi",
      "Baffa Pakhal"
    ],
    "Kohat": [
      "Kohat",
      "Lachi"
    ],
    "Quetta": [
      "Quetta City",
      "Chiltan",
      "Zarghoon"
    ],
    "Gwadar": [
      "Gwadar",
      "Pasni",
      "Ormara",
      "Jiwanl"
    ],
    "Khuzdar": [
      "Khuzdar",
      "Wadh",
      "Nall",
      "Moola"
    ],
    "Sibi": [
      "Sibi",
      "Harnai"
    ],
    "Hub": [
      "Hub",
      "Dureji"
    ],
    "Muzaffarabad": [
      "Muzaffarabad",
      "Naseerabad"
    ],
    "Mirpur": [
      "Mirpur",
      "Dadyal"
    ],
    "Kotli": [
      "Kotli",
      "Sehnsa",
      "Charhoi"
    ],
    "Bhimber": [
      "Bhimber",
      "Barnala",
      "Samahni"
    ],
    "Rawalakot": [
      "Rawalakot",
      "Hajira"
    ],
    "Gilgit": [
      "Gilgit City",
      "Danyor",
      "Juglot"
    ],
    "Skardu": [
      "Skardu Town",
      "Rondu",
      "Gambal"
    ],
    "Hunza": [
      "Aliabad",
      "Gojal"
    ],
    "Diamer": [
      "Chilas",
      "Tangir"
    ],
  };

  // ══════════════════════════════════════════════════════
  // OPTIONS
  // ══════════════════════════════════════════════════════

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

  final List<String> genderOptions = [
    "Male",
    "Female",
    "Other",
  ];

  final List<String> placeOptions = [
    "Hospital",
    "Home",
    "Workplace / Farm",
    "En Route / Accident Site",
  ];

  final List<String> waterOptions = [
    "Filtered / Clean Tap Water",
    "Borehole / Motor Well",
    "Open Hand Pump / Canal / Unfiltered Well",
  ];

  final List<String> incomeOptions = [
    "Lower Income Segment",
    "Middle Income Segment",
    "Upper Income Segment",
  ];

  // ══════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════

  List<String> get currentDistricts =>
      province != null ? (districtMap[province] ?? []) : [];

  List<String> get currentTehsils =>
      district != null ? (tehsilMap[district] ?? []) : [];

  // ══════════════════════════════════════════════════════
  // INIT / DISPOSE
  // ══════════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════════
  // COMORBIDITY SELECTION
  // ══════════════════════════════════════════════════════

  void toggleCondition(String value) {
    setState(() {
      if (value == "None") {
        medicalConditions = ["None"];
        otherConditionC.clear();
        return;
      }

      medicalConditions.remove("None");

      if (medicalConditions.contains(value)) {
        medicalConditions.remove(value);

        if (value == "Other") {
          otherConditionC.clear();
        }
      } else {
        medicalConditions.add(value);
      }
    });
  }

  // ══════════════════════════════════════════════════════
  // DATE PICKER
  // ══════════════════════════════════════════════════════

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: accent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  // ══════════════════════════════════════════════════════
  // LOGOUT
  // ══════════════════════════════════════════════════════

  Future<void> confirmLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: redLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: red,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: textDark,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your session?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: textGrey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textGrey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'LOGOUT',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint("Supabase SignOut error: $e");
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (route) => false,
      );
    }
  }

  // ══════════════════════════════════════════════════════
  // OFFLINE SYNC
  // ══════════════════════════════════════════════════════

  Future<void> syncOfflineRecords() async {
    if (_offlineBox.isEmpty) return;

    final keys = List.from(_offlineBox.keys);

    for (final key in keys) {
      final Map<dynamic, dynamic>? rawRecord =
          _offlineBox.get(key);

      if (rawRecord == null) continue;

      final Map<String, dynamic> strictRecord =
          Map<String, dynamic>.from(rawRecord);

      try {
        await Supabase.instance.client
            .from("mortality_records")
            .insert(strictRecord);

        await _offlineBox.delete(key);
      } catch (e) {
        debugPrint("OFFLINE SYNC ERROR: $e");
        return;
      }
    }

    if (mounted) {
      _show(
        "Offline records synchronized successfully!",
        green,
      );
    }
  }

  // ══════════════════════════════════════════════════════
  // SAVE DATA
  // ══════════════════════════════════════════════════════

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null) {
      _show(
        "Please choose a valid Date of Death",
        red,
      );
      return;
    }

    final String finalizedCause =
        (causeOfDeath == "Other" &&
                otherCauseC.text.trim().isNotEmpty)
            ? "Other: ${otherCauseC.text.trim()}"
            : causeOfDeath ?? "Unknown";

    final List<String> finalizedConditions =
        List<String>.from(medicalConditions);

    if (finalizedConditions.contains("Other") &&
        otherConditionC.text.trim().isNotEmpty) {
      finalizedConditions.remove("Other");

      finalizedConditions.add(
        "Other: ${otherConditionC.text.trim()}",
      );
    }

    // ══════════════════════════════════════════════════
    // DATABASE RECORD
    // ══════════════════════════════════════════════════

    final Map<String, dynamic> record = {
      "patient_name":
          nameC.text.trim().isEmpty
              ? "Anonymous"
              : nameC.text.trim(),

      "age":
          int.tryParse(ageC.text.trim()) ?? 0,

      "gender": gender,

      "province": province,

      "district": district,

      "tehsil": tehsil,

      "area_type": areaType,

      "specific_locality":
          specificLocalityC.text.trim(),

      "cause_of_death":
          finalizedCause,

      "duration_of_illness":
          durationOfIllnessC.text.trim().isEmpty
              ? "Not Specified"
              : durationOfIllnessC.text.trim(),

      // IMPORTANT:
      // This remains List<String>.
      // Supabase text[] will store:
      // {"Diabetes (Sugar)","Heart Disease"}
      "prior_medical_conditions":
          finalizedConditions,

      "place_of_death": placeOfDeath,

      // OPTIONAL
      // If user does not select it, NULL is stored.
      "water_source": waterSource,

      // OPTIONAL
      // If user does not select it, NULL is stored.
      "income_bracket": incomeBracket,

      "date_of_death":
          selectedDate!
              .toIso8601String()
              .split("T")[0],

      "created_at":
          DateTime.now().toIso8601String(),
    };

    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client
          .from("mortality_records")
          .insert(record);

      _show(
        "Record saved successfully",
        green,
      );

      _resetForm();

      await syncOfflineRecords();
    } catch (supabaseError) {
      debugPrint(
        "SUPABASE WRITE ERROR: $supabaseError",
      );

      await _offlineBox.add(record);

      _show(
        "Saved offline. It will sync automatically when connected.",
        orange,
      );

      _resetForm();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // RESET FORM
  // ══════════════════════════════════════════════════════

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

      // Optional fields reset to NULL
      waterSource = null;
      incomeBracket = null;

      medicalConditions = [];
      selectedDate = null;
    });
  }

  // ══════════════════════════════════════════════════════
  // SNACKBAR
  // ══════════════════════════════════════════════════════

  void _show(String msg, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == green
                  ? Icons.check_circle_rounded
                  : color == orange
                  ? Icons.warning_rounded
                  : Icons.info_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 4,
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;

    return Scaffold(
      backgroundColor: background,

      // ════════════════════════════════════════════════
      // APP BAR - Enhanced
      // ════════════════════════════════════════════════

      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 72,

        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [accent, purple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mortality Registry",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: isWide ? 20 : 17,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  "Data Collection Portal",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: "Logout",
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 22,
                ),
              ),
              onPressed: confirmLogout,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ════════════════════════════════════════════════
      // BODY
      // ════════════════════════════════════════════════

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 980,
          ),

          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 34 : 18,
              vertical: 26,
            ),

            child: Form(
              key: _formKey,

              child: Column(
                children: [

                  // HEADER - Enhanced
                  _buildPageHeader(),

                  const SizedBox(height: 24),

                  // PERSONAL
                  _sectionCard(
                    icon: Icons.person_outline_rounded,
                    title: "Personal Information",
                    subtitle: "Basic information about the deceased",
                    color: accent,
                    children: [

                      TextFormField(
                        controller: nameC,
                        decoration: _inputDecoration(
                          "Full Name",
                          "Leave blank for anonymous",
                          Icons.badge_outlined,
                          required: false,
                        ),
                      ),

                      const SizedBox(height: 16),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 500) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: ageC,
                                  keyboardType:
                                      TextInputType.number,
                                  decoration: _inputDecoration(
                                    "Age (Years)",
                                    "Enter age",
                                    Icons.cake_outlined,
                                    required: true,
                                  ),
                                  validator: (v) =>
                                      (v == null ||
                                              v.trim().isEmpty)
                                          ? "Age is required"
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                _dropdown(
                                  "Gender",
                                  genderOptions,
                                  gender,
                                  true,
                                  (v) => setState(
                                    () => gender = v,
                                  ),
                                  icon: Icons.wc_rounded,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: ageC,
                                  keyboardType:
                                      TextInputType.number,
                                  decoration: _inputDecoration(
                                    "Age (Years)",
                                    "Enter age",
                                    Icons.cake_outlined,
                                    required: true,
                                  ),
                                  validator: (v) =>
                                      (v == null ||
                                              v.trim().isEmpty)
                                          ? "Age is required"
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _dropdown(
                                  "Gender",
                                  genderOptions,
                                  gender,
                                  true,
                                  (v) => setState(
                                    () => gender = v,
                                  ),
                                  icon: Icons.wc_rounded,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),

                  // LOCATION
                  _sectionCard(
                    icon: Icons.location_on_outlined,
                    title: "Geographical Information",
                    subtitle: "Select the location using the hierarchy",
                    color: teal,
                    children: [

                      _dropdown(
                        "Province",
                        provinceList,
                        province,
                        true,
                        (v) {
                          setState(() {
                            province = v;
                            district = null;
                            tehsil = null;
                          });
                        },
                        icon: Icons.map_outlined,
                      ),
                      const SizedBox(height: 14),
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
                        disabledHint:
                            province == null
                                ? "Select province first"
                                : null,
                        icon: Icons.location_city_outlined,
                      ),
                      const SizedBox(height: 14),
                      _dropdown(
                        "Tehsil",
                        currentTehsils,
                        tehsil,
                        true,
                        (v) => setState(
                          () => tehsil = v,
                        ),
                        disabledHint:
                            district == null
                                ? "Select district first"
                                : null,
                        icon: Icons.holiday_village_outlined,
                      ),
                    ],
                  ),

                  // LOCALITY
                  _sectionCard(
                    icon: Icons.home_work_outlined,
                    title: "Locality Information",
                    subtitle: "Specify whether the location is urban or rural",
                    color: orange,
                    children: [

                      _dropdown(
                        "Area Type",
                        ["Urban", "Rural"],
                        areaType,
                        true,
                        (v) => setState(
                          () => areaType = v,
                        ),
                        icon: Icons.domain_rounded,
                      ),

                      if (areaType != null) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller:
                              specificLocalityC,
                          decoration: _inputDecoration(
                            areaType == "Rural"
                                ? "Village / Chak Details"
                                : "City Locality Details",
                            areaType == "Rural"
                                ? "e.g. Chak 12-L, Near Mosque"
                                : "e.g. Sector G-11/2, Street 4",
                            Icons.place_outlined,
                            required: true,
                          ),
                          validator: (v) =>
                              (v == null ||
                                      v.trim().isEmpty)
                                  ? "Locality details are required"
                                  : null,
                        ),
                      ],
                    ],
                  ),

                  // CAUSE
                  _sectionCard(
                    icon: Icons.medical_information_outlined,
                    title: "Cause of Death",
                    subtitle: "Record the primary cause and illness duration",
                    color: rose,
                    children: [

                      _dropdown(
                        "Primary Cause of Death",
                        causeOptions,
                        causeOfDeath,
                        true,
                        (v) {
                          setState(() {
                            causeOfDeath = v;
                            if (v != "Other") {
                              otherCauseC.clear();
                            }
                          });
                        },
                        icon: Icons.coronavirus_outlined,
                      ),

                      if (causeOfDeath == "Other") ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: otherCauseC,
                          decoration: _inputDecoration(
                            "Custom Medical Cause",
                            "Specify the cause",
                            Icons.edit_note_rounded,
                            required: true,
                          ),
                          validator: (v) =>
                              (causeOfDeath == "Other" &&
                                      (v == null ||
                                          v.trim().isEmpty))
                                  ? "Please specify the cause"
                                  : null,
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller:
                            durationOfIllnessC,
                        decoration: _inputDecoration(
                          "Duration of Illness",
                          "e.g. 2 Weeks, 5 Years, Sudden",
                          Icons.timelapse_rounded,
                          required: true,
                        ),
                        validator: (v) =>
                            (v == null ||
                                    v.trim().isEmpty)
                                ? "Duration is required"
                                : null,
                      ),
                    ],
                  ),

                  // COMORBIDITIES
                  _sectionCard(
                    icon: Icons.healing_outlined,
                    title: "Prior Medical Conditions",
                    subtitle: "Select all conditions that apply",
                    color: purple,
                    children: [

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            conditionOptions.map(
                          (condition) {
                            final selected =
                                medicalConditions
                                    .contains(condition);
                            return FilterChip(
                              label: Text(
                                condition,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight:
                                      selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                  color: selected ? accent : textDark,
                                ),
                              ),
                              selected: selected,
                              selectedColor: accentLight,
                              checkmarkColor: accent,
                              side: BorderSide(
                                color: selected
                                    ? accent
                                    : border,
                                width: selected ? 2 : 1,
                              ),
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        12),
                              ),
                              onSelected: (_) =>
                                  toggleCondition(
                                      condition),
                            );
                          },
                        ).toList(),
                      ),

                      if (medicalConditions
                          .contains("Other")) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller:
                              otherConditionC,
                          decoration: _inputDecoration(
                            "Other Chronic Disease",
                            "Specify condition",
                            Icons.edit_note_rounded,
                            required: true,
                          ),
                          validator: (v) =>
                              medicalConditions
                                          .contains(
                                              "Other") &&
                                      (v == null ||
                                          v.trim().isEmpty)
                                  ? "Please specify the condition"
                                  : null,
                        ),
                      ],
                    ],
                  ),

                  // SOCIO ENVIRONMENT
                  _sectionCard(
                    icon: Icons.public_outlined,
                    title: "Environmental & Socioeconomic",
                    subtitle: "Optional lifestyle and socioeconomic information",
                    color: indigo,
                    children: [

                      _dropdown(
                        "Place of Death",
                        placeOptions,
                        placeOfDeath,
                        true,
                        (v) => setState(
                          () => placeOfDeath = v,
                        ),
                        icon: Icons.local_hospital_outlined,
                      ),
                      const SizedBox(height: 14),

                      // OPTIONAL WATER SOURCE
                      _dropdown(
                        "Water Source",
                        waterOptions,
                        waterSource,
                        false,
                        (v) => setState(
                          () => waterSource = v,
                        ),
                        icon: Icons.water_drop_outlined,
                        optionalLabel: true,
                      ),
                      const SizedBox(height: 14),

                      // OPTIONAL INCOME
                      _dropdown(
                        "Income Bracket",
                        incomeOptions,
                        incomeBracket,
                        false,
                        (v) => setState(
                          () => incomeBracket = v,
                        ),
                        icon: Icons.account_balance_wallet_outlined,
                        optionalLabel: true,
                      ),
                    ],
                  ),

                  // DATE
                  _sectionCard(
                    icon: Icons.calendar_month_outlined,
                    title: "Date of Death",
                    subtitle: "Select the date when death occurred",
                    color: primary,
                    children: [

                      InkWell(
                        borderRadius:
                            BorderRadius.circular(14),
                        onTap: pickDate,
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedDate == null
                                ? redLight
                                : accentLight,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedDate == null
                                  ? red.withOpacity(0.3)
                                  : accent.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.all(
                                        10),
                                decoration: BoxDecoration(
                                  color:
                                      selectedDate == null
                                          ? redLight
                                          : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(
                                          10),
                                ),
                                child: Icon(
                                  Icons
                                      .calendar_month_rounded,
                                  color:
                                      selectedDate == null
                                          ? red
                                          : accent,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      selectedDate == null
                                          ? "Date of Death"
                                          : "Selected Date",
                                      style:
                                          GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: textGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      selectedDate == null
                                          ? "Tap to select date"
                                          : _formatDate(
                                              selectedDate!),
                                      style:
                                          GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w700,
                                        color:
                                            selectedDate ==
                                                    null
                                                ? red
                                                : accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons
                                    .arrow_forward_ios_rounded,
                                size: 16,
                                color:
                                    selectedDate == null
                                        ? red
                                        : accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // INFO
                  _buildInfoBox(),

                  const SizedBox(height: 24),

                  // SUBMIT - Enhanced
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                      onPressed:
                          _isSaving ? null : _saveData,
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "SUBMIT ANALYTICS RECORD",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your record is securely stored and can be synchronized when offline.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: textGrey,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // PAGE HEADER - Enhanced
  // ══════════════════════════════════════════════════════

  Widget _buildPageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E293B),
            Color(0xFF3B82F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [accent, purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Register Mortality Record",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Enter accurate information for mortality analysis and reporting.",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.5,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // SECTION CARD - Enhanced
  // ══════════════════════════════════════════════════════

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardShadow.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          color: textGrey,
                          fontSize: 11.5,
                          height: 1.4,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: border.withOpacity(0.5),
          ),
          // CONTENT
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // INPUT DECORATION - Enhanced
  // ══════════════════════════════════════════════════════

  InputDecoration _inputDecoration(
    String label,
    String hint,
    IconData icon, {
    required bool required,
  }) {
    return InputDecoration(
      labelText: required
          ? "$label *"
          : label,
      hintText: hint,
      labelStyle: GoogleFonts.poppins(
        color: textGrey,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.poppins(
        color: textLight,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: textGrey,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFBFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border.withOpacity(0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: accent,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: red,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: red,
          width: 2,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DROPDOWN - Enhanced
  // ══════════════════════════════════════════════════════

  Widget _dropdown(
    String label,
    List<String> items,
    String? value,
    bool isRequired,
    ValueChanged<String?> onChanged, {
    String? disabledHint,
    IconData? icon,
    bool optionalLabel = false,
  }) {
    final bool hasDisabledHint =
        disabledHint != null;

    final bool validValue =
        value != null &&
        items.contains(value);

    return DropdownButtonFormField<String>(
      initialValue:
          validValue ? value : null,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: GoogleFonts.poppins(
        color: textDark,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: textGrey,
      ),
      decoration: InputDecoration(
        labelText: isRequired
            ? "$label *"
            : "$label (Optional)",
        labelStyle: GoogleFonts.poppins(
          color: textGrey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: icon != null
            ? Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  icon,
                  size: 20,
                  color: textGrey,
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFFAFBFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: accent,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: border.withOpacity(0.3),
          ),
        ),
      ),
      items: hasDisabledHint
          ? null
          : items.map(
              (item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                );
              },
            ).toList(),
      onChanged:
          hasDisabledHint ? null : onChanged,
      hint: hasDisabledHint
          ? Text(
              disabledHint,
              style: GoogleFonts.poppins(
                color: textLight,
                fontSize: 12,
                height: 1.3,
              ),
            )
          : Text(
              "Select $label",
              style: GoogleFonts.poppins(
                color: textLight,
                fontSize: 12,
                height: 1.3,
              ),
            ),
      validator: (v) {
        if (!isRequired) {
          return null;
        }
        if (hasDisabledHint) {
          return null;
        }
        if (v == null || v.isEmpty) {
          return "Please select $label";
        }
        return null;
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // INFO BOX - Enhanced
  // ══════════════════════════════════════════════════════

  Widget _buildInfoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            greenLight,
            greenLight.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: green.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Fields marked with * are required. "
              "Water Source and Income Bracket are optional and can be left blank.",
              style: GoogleFonts.poppins(
                color: const Color(0xFF065F46),
                fontSize: 11,
                height: 1.6,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // DATE FORMAT
  // ══════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    final String day =
        date.day.toString().padLeft(2, '0');
    final String month =
        date.month.toString().padLeft(2, '0');
    return "$day-$month-${date.year}";
  }
}