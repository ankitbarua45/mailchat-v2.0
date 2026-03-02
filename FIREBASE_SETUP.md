# Quick Firebase Setup Guide

## ⚠️ IMPORTANT: Complete Firebase Setup Before Running

Your MailChat app is ready, but you need to configure Firebase first!

## Step-by-Step Firebase Configuration

### 1. Create Firebase Project (5 minutes)

1. Go to https://console.firebase.google.com/
2. Click **"Create a project"** or select existing
3. Name: **MailChat** (or any name you prefer)
4. Disable Google Analytics (optional)
5. Click **Create Project**

### 2. Enable Authentication (2 minutes)

1. In your Firebase project, click **Authentication** in left menu
2. Click **Get Started**
3. Click **Email/Password** tab
4. Toggle **Enable** switch
5. Click **Save**

### 3. Create Firestore Database (3 minutes)

1. Click **Firestore Database** in left menu
2. Click **Create database**
3. Choose **Start in test mode** (for development)
4. Select your preferred location
5. Click **Enable**

### 4. Add Android App (5 minutes)

1. In Project Overview, click the **Android** icon
2. **Android package name:** `com.example.mail`
3. Click **Register app**
4. **Download** `google-services.json`
5. **IMPORTANT:** Place `google-services.json` in:
   ```
   c:\mailchat\mail\android\app\
   ```
6. Click **Next** → **Next** → **Continue to console**

### 5. Add iOS App (Optional - 5 minutes)

1. In Project Overview, click the **iOS** icon
2. **iOS bundle ID:** `com.example.mail`
3. Click **Register app**
4. **Download** `GoogleService-Info.plist`
5. Place in: `c:\mailchat\mail\ios\Runner\`
6. Click **Next** → **Next** → **Continue to console**

## Verify Setup

After completing the above steps, you should have:

- ✅ Firebase project created
- ✅ Email/Password authentication enabled
- ✅ Firestore database created (test mode)
- ✅ `google-services.json` in `android/app/`
- ✅ (iOS) `GoogleService-Info.plist` in `ios/Runner/`

## Run the App

```bash
cd c:\mailchat\mail
flutter run
```

## Test the App

1. **Sign Up**
   - Enter email: `test@example.com`
   - Enter password: `password123`
   - Note your generated username

2. **Create Second Account** (use another device/emulator)
   - Enter email: `test2@example.com`
   - Enter password: `password123`

3. **Search and Chat**
   - Click search icon
   - Search for the other user's username
   - Click "Chat" and start messaging!

## Troubleshooting

**"Default FirebaseApp not initialized" error:**
- Ensure `google-services.json` is in correct location
- Run: `flutter clean` then `flutter pub get`

**Authentication errors:**
- Verify Email/Password is enabled in Firebase Console
- Check internet connection

**Build errors:**
- Update Flutter: `flutter upgrade`
- Clean project: `flutter clean`
- Get dependencies: `flutter pub get`

## Security (Production)

For production deployment, update Firestore Rules in Firebase Console:

1. Go to **Firestore Database** → **Rules**
2. Copy the security rules from `SETUP_GUIDE.md`
3. Click **Publish**

## Firebase Console URLs

- **Project:** https://console.firebase.google.com/project/YOUR_PROJECT_ID
- **Authentication:** https://console.firebase.google.com/project/YOUR_PROJECT_ID/authentication
- **Firestore:** https://console.firebase.google.com/project/YOUR_PROJECT_ID/firestore

---

## Current Progress: ✅ Code Complete | ⏳ Firebase Setup Pending

Once Firebase is configured, your app will have:
- User signup/login with auto-generated usernames
- Real-time messaging
- User search functionality
- Online/offline status
- Read receipts
- Modern WhatsApp-like UI

Need help? Check `SETUP_GUIDE.md` for detailed information!
