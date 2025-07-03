# 🍀 Lucky Ten Commandments (행운의 십계명)

A daily spiritual guidance Flutter app that provides inspirational cards with stories, reflections, and community features.

## 📱 About The App

Lucky Ten Commandments is a multilingual mobile application designed to provide daily spiritual guidance through inspirational cards. Each card contains a theme, story, and reflection questions to help users practice mindfulness and personal growth.

### ✨ Key Features

- **🎯 Daily Cards**: Draw inspiration cards with themes, stories, and reflection questions
- **📝 Personal Memos**: Save and organize your thoughts and reflections
- **👥 Community Sharing**: Share your memos with the community and interact with others
- **🌍 Multilingual Support**: Available in 5 languages (Korean, English, Japanese, Chinese, Spanish)
- **📊 Progress Tracking**: Track your daily visits and streak count
- **⏰ Daily Reminders**: Set up custom reminder times
- **💾 Cloud Sync**: Data synchronized via Supabase backend

## 🌐 Supported Languages

- 🇰🇷 Korean (한국어)
- 🇺🇸 English
- 🇯🇵 Japanese (日本語)
- 🇨🇳 Chinese (中文)
- 🇪🇸 Spanish (Español)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.7.2 or higher)
- Dart SDK
- Android Studio / VS Code
- Supabase account (for backend services)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Multi_lucky_ten_commandments
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Environment Setup**
   - Create a `.env` file in the root directory
   - Add your Supabase configuration:
     ```
     SUPABASE_URL=your_supabase_url
     SUPABASE_ANON_KEY=your_supabase_anon_key
     ```

4. **Generate launcher icons**
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### 📦 Dependencies

- **supabase_flutter**: Backend database and authentication
- **shared_preferences**: Local data storage
- **flutter_dotenv**: Environment variable management
- **logger**: Logging functionality
- **flutter_launcher_icons**: Custom app icons

## 🏗️ Project Structure

```
lib/
├── main.dart                    # Main app entry point
├── community_memo_page.dart     # Community features
├── reminder_setting_page.dart   # User settings and statistics
└── reminder_service.dart        # Notification services

assets/
├── images/                      # App images and icons
├── lucky_ten_ui_labels.json    # Multilingual UI labels
└── multilang_cards_final_449_to_480.csv  # Card data
```

## 🔧 Features Details

### 📱 Main Features

1. **Card Drawing System**
   - Random card selection from database
   - Beautiful card display with themes and stories
   - Reflection questions for personal growth

2. **Memo System**
   - Personal memo creation and storage
   - Community memo sharing
   - Like and comment functionality

3. **Progress Tracking**
   - Daily visit streaks
   - Access statistics
   - Personal achievement tracking

4. **Reminder System**
   - Customizable daily reminder times
   - Local notification support

### 🎨 UI/UX Features

- Clean, modern Material Design interface
- Smooth animations and transitions
- Responsive design for various screen sizes
- Dark/Light theme considerations
- Intuitive navigation

## 🗄️ Database Schema

The app uses Supabase as the backend with the following main tables:
- `cards`: Multilingual card content
- `user_memos`: Personal user memos
- `community_memos`: Shared community memos
- `memo_likes`: Like system for community interaction
- `memo_comments`: Comment system

## 🔧 Development

### Building for Release

**Android:**
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

### Testing

```bash
flutter test
```

## 📱 Platform Support

- ✅ Android (API 21+)
- ✅ iOS (iOS 12+)
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is private and not published to pub.dev. All rights reserved.

## 📞 Support

For support and questions, please contact the development team.

## 🔄 Version History

- **v1.0.8 (Build 402)**: Current stable version
  - Multilingual support implementation
  - Community features
  - Progress tracking system
  - Bug fixes and performance improvements

---

Made with ❤️ using Flutter
