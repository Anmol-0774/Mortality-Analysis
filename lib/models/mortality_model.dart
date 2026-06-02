class MortalityModel {
  final String id;
  final DateTime createdAt;
  final int age;
  final String gender;
  final String province;
  final String district;
  final String tehsil;
  final String village;
  final String causeOfDeath;
  final DateTime deathDate;
  final String smoker;
  final String obesity;
  final String diabetes;
  final String hypertension;
  final double latitude;
  final double longitude;

  MortalityModel({
    required this.id,
    required this.createdAt,
    required this.age,
    required this.gender,
    required this.province,
    required this.district,
    required this.tehsil,
    required this.village,
    required this.causeOfDeath,
    required this.deathDate,
    required this.smoker,
    required this.obesity,
    required this.diabetes,
    required this.hypertension,
    required this.latitude,
    required this.longitude,
  });

  factory MortalityModel.fromJson(Map<String, dynamic> json) {
    return MortalityModel(
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      gender: json['gender']?.toString() ?? 'Unknown',
      province: json['province']?.toString() ?? 'Unknown',
      district: json['district']?.toString() ?? 'Unknown',
      tehsil: json['tehsil']?.toString() ?? 'Unknown',
      village: json['village']?.toString() ?? 'Unknown',
      causeOfDeath: json['cause_of_death']?.toString() ?? 'Other',
      deathDate: DateTime.parse(json['death_date'] ?? DateTime.now().toIso8601String()),
      smoker: json['smoker']?.toString() ?? 'No',
      obesity: json['obesity']?.toString() ?? 'No',
      diabetes: json['diabetes']?.toString() ?? 'No',
      hypertension: json['hypertension']?.toString() ?? 'No',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}