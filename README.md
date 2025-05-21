# Ashesi Engage

A comprehensive campus engagement platform for Ashesi University, built with Flutter. This application enables students to actively participate in campus life through various interactive features.

## Features

### 🎯 Core Features
- **Proposals**: Submit and endorse campus improvement ideas
- **Forum**: Engage in meaningful discussions with the campus community
- **Polls & Surveys**: Participate in campus-wide polls and surveys
- **Events**: Stay updated with campus events and activities
- **Real-time Notifications**: Get instant updates on new proposals, discussions, and events
- **Offline Support**: Access content even without internet connection
- **Deep Linking**: Share and access content through direct links
- **Admin Dashboard**: Comprehensive tools for content and user management

### 🛠 Technical Features
- Cross-platform support (iOS, Android, Web)
- Real-time data synchronization
- Offline data persistence
- Push notifications
- Deep linking support
- Material Design 3 UI
- Dark/Light theme support
- Responsive design

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Firebase
  - Authentication
  - Firestore
  - Cloud Messaging
  - App Check
- **State Management**: Provider
- **Navigation**: GoRouter
- **UI**: Material Design 3
- **Local Storage**: Shared Preferences
- **Network**: Connectivity Plus

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- Firebase CLI
- Android Studio / Xcode (for mobile development)
- VS Code (recommended IDE)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/jayy-07/ashesi_engage.git
```

2. Navigate to the project directory:
```bash
cd ashesi_engage
```

3. Install dependencies:
```bash
flutter pub get
```

4. Configure Firebase:
   - Create a new Firebase project
   - Add Android/iOS/Web apps to your Firebase project
   - Download and add the configuration files
   - Enable required Firebase services

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── auth/           # Authentication related code
├── config/         # App configuration
├── models/         # Data models
├── providers/      # State providers
├── services/       # Service classes
├── viewmodels/     # View models
├── views/          # UI components
│   ├── admin/      # Admin screens
│   ├── screens/    # Main app screens
│   └── widgets/    # Reusable widgets
└── main.dart       # Entry point
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Ashesi University for the opportunity to build this platform
- Flutter team for the amazing framework
- Firebase team for the robust backend services
- All contributors who have helped shape this project

## Contact

Project Link: [https://github.com/jayy-07/ashesi_engage](https://github.com/jayy-07/ashesi_engage)
