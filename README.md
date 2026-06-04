# 📊 Mortality Analysis & Data Collection System

A comprehensive, dual-part system designed to collect regional health/mortality data via a mobile application and perform deep data insights and statistical analysis on the collected datasets.

---

## 📱 Part 1: Data Collection Tool (Flutter App)

The data collection phase is powered by a robust mobile application built using **Flutter**. This application is tailored for field health workers and community researchers to log vital statistics and health records directly from the ground—even in areas with limited connectivity.

### Key Features of the App
* **Localized Demographics:** Easily log precise geographic details including District, Tehsil, and specific localities (e.g., Lahore, Rawalpindi neighborhoods).
* **Dynamic Medical Tagging:** Input multiple prior medical conditions using an intuitive multi-select interface.
* **Socioeconomic & Environmental Tracking:** Capture crucial contextual data such as the household's primary `water_source` and `income_bracket` to help map environmental health risks.
* **Offline First (Optional/Planned):** Designed to temporarily cache entries locally when field workers are out of cellular range.

### Tech Stack
* **Framework:** Flutter (Dart)
* **State Management:** Provider / Bloc *(Update as per your implementation)*
* **Database/Backend:** Firebase / Supabase / Local SQLite *(Update as per your implementation)*

---

## 🔬 Part 2: Mortality Dataset & Analysis

The data collected through the app is compiled into a granular dataset containing community health entries from the Punjab region. This analysis aims to discover hidden correlations between environmental factors, socioeconomic status, and regional mortality causes.

### Dataset Overview
The dataset tracks several critical parameters:
* **Demographics:** Age, Gender, and detailed Location (District, Tehsil, Locality).
* **Health Profiles:** Underlying prior medical conditions (Diabetes, Heart Disease, Hypertension, etc.) and explicit `Cause of Death`.
* **Environmental/Social Factors:** `Water Source` (e.g., Borehole, Filtration Plant, Tap Water) and `Income Bracket`.

### Ongoing Data Cleaning & Analysis Objectives
1. **Data Standardization:** Converting varying categorical timelines (e.g., `1 Week`, `2 Months`, `Sudden`) into standardized numeric durations.
2. **Anomaly Detection:** Filtering data-entry anomalies (such as mislogged age-to-cause ratios) to ensure analytical integrity.
3. **Correlation Mapping:** Analyzing whether specific water sources or lower-income brackets correlate with higher frequencies of specific terminal conditions (like Hepatitis or Liver failure).

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (v3.x or higher)
* Android Studio / VS Code
* Python 3.8+ (for running the data analysis scripts)

### Installation & Setup

1. **Clone the repository:**
```bash
   git clone [https://github.com/Anmol-0774/Mortality-Analysis.git](https://github.com/Anmol-0774/Mortality-Analysis.git)
   cd mortality_analysis
```
2. **Run the Flutter App:**

```bash
   # Get packages
   flutter pub get
``` 
# Run on connected device
```bash
   flutter run
```