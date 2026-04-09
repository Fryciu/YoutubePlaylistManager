# ManageTube – YouTube Management Tool

[![Flutter](https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Language-Dart-0175C2?logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-All_Rights_Reserved-red.svg)](https://choosealicense.com/no-permission/)

**ManageTube** is a high-performance, Android utility designed to streamline YouTube library management. It addresses the native UI limitations of YouTube by enabling batch operations on playlists through efficient API integration, focusing on **OAuth2 security** and **asynchronous data processing**.

---

## 🚀 Key Features & Engineering Challenges

* **Bulk API Operations:** Engineered complex request handling for the YouTube Data API v3, including pagination management and quota optimization.
* **Secure Authentication:** Integrated Google OAuth2 flow, ensuring sensitive user credentials never touch the application (token-based authorization).
* **State Management:** Utilized a reactive state management pattern to ensure smooth UI updates during intensive batch deletion processes.

---

## 🛠 Technical Stack

* **Framework:** Flutter (>=3.0.0)
* **Language:** Dart (>=3.0.0)
* **Native Flutter State Management**
* **API Communication:** Google API Client (YouTube Data API v3)
* **Auth:** Google Sign-In (OAuth 2.0)

---

## 🏗 Architecture & Project Structure

The project follows **Clean Architecture** principles, separating data sources, business logic, and UI components to ensure maintainability and testability.

### Development Prerequisites
* Flutter SDK
* Registered OAuth Client ID via Google Cloud Console

### Build & Deployment
The build process utilizes AOT (Ahead-of-Time) compilation and Tree Shaking to minimize binary size and maximize performance.

```bash
# Clone the repository
git clone [https://github.com/Fryciu/youtube_playlist_cleaner.git](https://github.com/Fryciu/youtube_playlist_cleaner.git)
cd youtube_playlist_cleaner

# Install dependencies
flutter pub get

# Test APK, while having phone connected to PC (Android)
flutter run 

# Build Release APK (Android)
flutter build apk --release --split-per-abi

# Test Executable (Windows)
flutter run windows

# Build Release Executable (Windows)
flutter build windows
```
## Challenges & Planned Updates
While the app works, right now you have to log out and log back in to refresh the token. In an earlier solution, the buttons "choose playlists to import" or "choose videos to be deleted" were triggering ` _googleSignIn.attemptLightweightAuthentication() ` which in turn made the little popup called "signing in" which I didn't like.
