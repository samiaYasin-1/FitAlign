# FitAlign

AI-powered fitness companion that uses computer vision for real-time posture alignment and workout tracking.

Built with Flutter, FitAlign watches your form through the device camera and helps you perform every exercise correctly to prevent injuries.


## Features

- **AI posture tracking:** analyzes your form in real time using the device camera.
- **Live feedback:** instant alerts when your posture goes wrong.
- **Exercise library:** browse exercises and open a guided pre-workout checklist.
- **Progress overview:** duration and accuracy scores for recent workouts.
- **Onboarding and sign in:** animated splash, intro slides and email login with validation.
- **Camera permission flow:** clear explanation, denied and permanently denied handling.

## Tech Stack

- **Framework:** Flutter (Dart, Material 3)
- **Computer vision:** Google ML Kit
- **Networking:** `http` with a REST (PHP) backend
- **Local storage:** `shared_preferences`
- **UI packages:** `carousel_slider`, `introduction_screen`
- **Permissions:** `permission_handler`

## Design

The whole app uses a single dark teal and coral color scheme defined once in `ThemeData` (`lib/main.dart`). Every screen reads its colors from `Theme.of(context).colorScheme`, so the look stays consistent and can be changed in one place.

## Getting Started

```bash
git clone https://github.com/samiaYasin-1/FitAlign.git
cd FitAlign/fit_align
flutter pub get
flutter run
```

> Camera and posture detection need a real Android device. They do not work in the browser.

## Project Structure

```
fit_align/lib
├── main.dart              # App entry, theme and home dashboard
├── splash1.dart           # Animated splash screen
├── slider2.dart           # Onboarding slides
├── signIN.dart            # Login screen
├── exercise.dart          # Exercise list
├── exercisedetail.dart    # Pre-workout checklist
├── camerapermission.dart  # Camera permission flow
└── camera.dart            # Live camera and posture detection
```

## Author

**Samia Yasin**
GitHub: [@samiaYasin-1](https://github.com/samiaYasin-1)# FitAlign
AI-powered fitness companion that uses computer vision for real-time posture alignment and workout tracking.
