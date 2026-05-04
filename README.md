Parkinson's Detection – Voice-Based Screening with Beautiful Flutter UI

A modern, cross-platform mobile/desktop application that predicts Parkinson’s Disease risk using vocal fundamental frequency (MDVP:Fo(Hz)). Built with Flutter, featuring glass‑morphism design, smooth animations, haptic feedback, and an in‑memory prediction history.

✨ Features
Simple rule‑based prediction – Frequency > 145 Hz → Parkinson’s, else Healthy.

Live confidence score (0.5–0.99) based on distance from threshold.

22‑feature input (UCI Parkinson’s dataset format) with real‑time validation.

Load random example values – test both outcomes instantly.

Animated results – Hero transitions, circular & linear confidence indicators.

Horizontal bar chart – visual comparison of all input features.

Prediction history – last 10 results with timestamps (in‑memory).

Haptic feedback – heavy/light impact & selection clicks.

Glass‑morphism UI – blurred backdrops, gradients, soft shadows.

Custom page transitions – smooth slide + fade animations.
🛠️ Tech Stack
Flutter (Material Design 3)

Dart (no external packages required)

BackdropFilter for glass effect

HapticFeedback & AnimationController

🧪 How to Run
Clone the repo

Run flutter pub get (no extra dependencies)

flutter run

📱 Screenshots
[Splash Screen → Input Form → Result Screen → History]

🔮 Next Steps (roadmap)
Integrate a real ML model (SVM / ensemble) with TensorFlow Lite.

Real‑time voice recording + automatic feature extraction.

Persistent storage & cloud sync.


<img width="739" height="825" alt="Screenshot 2026-05-04 122040" src="https://github.com/user-attachments/assets/e3810cc3-dc03-43a6-8069-299e79b83e2e" />


<img width="728" height="836" alt="image" src="https://github.com/user-attachments/assets/7d526c49-b192-4589-af1e-83ccb15c9dce" />

<img width="652" height="834" alt="image" src="https://github.com/user-attachments/assets/58fde2ab-c8a0-4974-ba5a-633393cd40e5" />




