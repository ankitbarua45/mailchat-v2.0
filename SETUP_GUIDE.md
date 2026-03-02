# MailChat - WhatsApp-like Real-time Chat App

A modern real-time chatting mobile application built with Flutter and Firebase, similar to WhatsApp.

## Features

✅ **User Authentication**
- Email and Password signup/login with Firebase Authentication
- Auto-generated unique usernames
- Secure authentication with proper error handling

✅ **User Management**
- User profiles stored in Firestore
- Online/offline status tracking
- Last seen timestamps
- Search users by username

✅ **Real-time Messaging**
- One-to-one chat functionality
- Real-time message updates
- Message read receipts
- Timestamp for each message
- Unread message counts

✅ **Modern UI**
- WhatsApp-style clean interface
- Chat list with recent conversations
- Smooth animations and transitions
- Responsive design

## Project Structure

```
lib/
├── main.dart                   # App entry point
├── models/                     # Data models
│   ├── user_model.dart
│   ├── message_model.dart
│   └── chat_model.dart
├── services/                   # Business logic
│   ├── auth_service.dart
│   └── database_service.dart
├── providers/                  # State management
│   └── auth_provider.dart
└── screens/                    # UI screens
    ├── login_screen.dart
    ├── signup_screen.dart
    ├── chat_list_screen.dart
    ├── chat_screen.dart
    └── user_search_screen.dart
```

## Setup Instructions

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Firebase account
- Android Studio / VS Code
- Android/iOS device or emulator

### Firebase Setup

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project" or select existing project
   - Enter project name: "MailChat"

2. **Enable Firebase Authentication**
   - In Firebase Console, go to Authentication
   - Click "Get Started"
   - Enable "Email/Password" sign-in method

3. **Create Firestore Database**
   - In Firebase Console, go to Firestore Database
   - Click "Create database"
   - Choose "Start in test mode" (for development)
   - Select a location

4. **Configure Firebase for Android**
   - In Firebase Console, click on Android icon
   - Register app with package name: `com.example.mail`
   - Download `google-services.json`
   - Place it in `android/app/` directory

5. **Configure Firebase for iOS** (if needed)
   - In Firebase Console, click on iOS icon
   - Register app with bundle ID
   - Download `GoogleService-Info.plist`
   - Place it in `ios/Runner/` directory

### Installation Steps

1. **Clone/Navigate to the project directory**
   ```bash
   cd c:\mailchat\mail
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Ensure `google-services.json` is in `android/app/`
   - Ensure `GoogleService-Info.plist` is in `ios/Runner/`

4. **Run the app**
   ```bash
   flutter run
   ```

## Firestore Database Structure

### Collections

**users/**
```json
{
  "uid": "string",
  "email": "string",
  "username": "string",
  "profileImageUrl": "string (optional)",
  "createdAt": "timestamp",
  "isOnline": "boolean",
  "lastSeen": "timestamp"
}
```

**chats/**
```json
{
  "chatId": "string",
  "participants": ["uid1", "uid2"],
  "lastMessage": "string",
  "lastMessageTime": "timestamp",
  "lastMessageSenderId": "string",
  "unreadCount": {
    "uid1": 0,
    "uid2": 0
  }
}
```

**chats/{chatId}/messages/**
```json
{
  "messageId": "string",
  "senderId": "string",
  "receiverId": "string",
  "message": "string",
  "timestamp": "timestamp",
  "isRead": "boolean",
  "chatId": "string"
}
```

## Security Rules (for Production)

Update Firestore Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /chats/{chatId} {
      allow read: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      allow create: if request.auth != null && 
        request.auth.uid in request.resource.data.participants;
      allow update: if request.auth != null && 
        request.auth.uid in resource.data.participants;
        
      match /messages/{messageId} {
        allow read: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        allow create: if request.auth != null && 
          request.auth.uid == request.resource.data.senderId;
      }
    }
  }
}
```

## Usage

1. **Sign Up**
   - Open the app
   - Click "Sign Up"
   - Enter email and password
   - A unique username will be generated automatically

2. **Search Users**
   - Click the search icon in the app bar
   - Enter username to search
   - Click "Chat" to start a conversation

3. **Send Messages**
   - Select a chat from the chat list
   - Type your message
   - Press send icon or Enter

4. **View Online Status**
   - Green dot indicates user is online
   - Last seen time shown for offline users

## Features Explanation

### Unique Username Generation
- Automatically creates username from email
- Adds random 4-digit suffix to ensure uniqueness
- Displayed after successful signup

### Real-time Updates
- Messages appear instantly using Firestore streams
- Online status updates in real-time
- Unread counts update automatically

### Read Receipts
- Single check: Message sent
- Double check: Message delivered and read
- Blue double check: Read (in future enhancement)

## Troubleshooting

**Firebase initialization error:**
- Ensure `google-services.json` is in correct location
- Run `flutter clean` and `flutter pub get`

**Build errors:**
- Update Flutter: `flutter upgrade`
- Clear cache: `flutter clean`
- Reinstall dependencies: `flutter pub get`

**Authentication errors:**
- Check Firebase Authentication is enabled
- Verify email/password provider is enabled

**Network errors:**
- Check internet connection
- Verify Firestore rules allow read/write

## Technologies Used

- **Flutter** - UI framework
- **Firebase Authentication** - User authentication
- **Cloud Firestore** - Real-time database
- **Provider** - State management
- **Intl** - Date formatting
- **UUID** - Unique ID generation

## License

This project is created for educational purposes.

## Support

For issues or questions, please create an issue in the repository.
