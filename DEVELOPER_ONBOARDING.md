# 👨‍💻 Developer Onboarding: Admin Panel Development

**Project**: SMS Gateway Pro - Admin Panel  
**Domain**: smsgetway.techwareafrica.tech  
**Repository**: LWENA27/sms_getway

---

## 🎯 What You'll Be Building

A Flutter web admin panel for managing SMS Gateway operations:
- User authentication and multi-tenant access
- Contact and group management
- Bulk SMS sending and logs
- API key management
- Sender ID requests
- Settings backup/restore

---

## 📋 Prerequisites & Access Required

### Accounts
1. **GitHub**: Request collaborator access to `LWENA27/sms_getway`
2. **Supabase**: Get invited to the project or credentials for local instance
3. **Netlify**: Access to deploy site (or team will add you)

### Tools (install these)
```bash
# Flutter SDK
flutter --version  # Should be 3.24.5 or compatible

# Android SDK (for mobile testing)
flutter doctor --android-licenses

# Netlify CLI (optional, for manual deploys)
npm install -g netlify-cli

# Git
git --version
```

---

## 🚀 Quick Setup (5 minutes)

### 1. Clone and Install
```bash
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway
flutter pub get
```

### 2. Run Against Local Supabase
Ask team lead to start local Supabase or use your own:
```bash
# In separate terminal (ask for the techwareafricaadimn folder location)
cd ~/techwareafricaadimn
supabase start

# Back to project folder
cd ~/sms_getway

# Run web app
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

### 3. Verify It Works
- App opens in Chrome
- Login screen appears
- Can create account or sign in
- Dashboard loads (may be empty if no data in local DB)

---

## 📚 Important Documentation

Read these in order:

1. **[SUPABASE.md](./SUPABASE.md)** ← START HERE
   - Database schema
   - Multi-tenant architecture
   - RLS policies
   - Local dev setup

2. **[NETLIFY_DEPLOYMENT.md](./NETLIFY_DEPLOYMENT.md)**
   - How to deploy to smsgetway.techwareafrica.tech
   - GitHub Actions CI/CD
   - Environment variables
   - Domain configuration

3. **[RELEASE_CHECKLIST.md](./RELEASE_CHECKLIST.md)**
   - Mobile app release process
   - Android signing
   - Play Store submission

4. **[ARCHITECTURE.md](./ARCHITECTURE.md)** (if exists)
   - App structure
   - State management
   - Code organization

---

## 🔐 Environment & Secrets

### For Local Development
Use `--dart-define` flags (see Quick Setup above). Never commit secrets!

### For Netlify (Web Deployment)
Set in Netlify Dashboard → Site settings → Environment variables:
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

### For GitHub Actions (CI/CD)
Repository secrets (Settings → Secrets and variables → Actions):
```
NETLIFY_AUTH_TOKEN=<ask team lead>
NETLIFY_SITE_ID=<ask team lead>
SUPABASE_URL=<ask team lead>
SUPABASE_ANON_KEY=<ask team lead>
```

⚠️ **NEVER** commit to git:
- `.env` files with keys
- `android/key.properties`
- `*.jks` keystore files

---

## 🗂️ Project Structure

```
sms_getway/
├── lib/
│   ├── main.dart              # App entry point
│   ├── core/
│   │   ├── constants.dart      # Supabase config (with fromEnvironment)
│   │   ├── theme.dart
│   │   └── tenant_service.dart
│   ├── screens/
│   │   ├── bulk_sms_screen.dart
│   │   ├── contacts_screen.dart
│   │   ├── groups_screen.dart
│   │   └── sms_logs_screen.dart
│   ├── api/
│   │   └── supabase_service.dart
│   └── ...
├── database/
│   ├── schema.sql              # DB schema
│   └── sender_id_requests_table.sql
├── android/                    # Android native project
├── web/                        # Web assets
├── .github/workflows/          # CI/CD
│   └── deploy-netlify.yml      # Auto-deploy to Netlify
├── netlify.toml               # Netlify config
├── pubspec.yaml               # Flutter dependencies
└── README.md                  # This file
```

---

## 🛠️ Development Workflow

### Daily Work
```bash
# 1. Pull latest
git pull origin main

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Run app locally
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH

# 4. Make changes, test, commit
git add .
git commit -m "feat: add awesome feature"

# 5. Push and open PR
git push origin feature/your-feature-name
# Open pull request on GitHub
```

### Before Pushing
```bash
# Format code
flutter format .

# Analyze for issues
flutter analyze

# Run tests (if any)
flutter test
```

### PR Review Checklist
- [ ] Code formatted (`flutter format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Tested locally with local Supabase
- [ ] No hardcoded secrets or keys
- [ ] Description explains what/why
- [ ] Screenshots if UI changes

---

## 🧪 Testing

### Run Locally
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

### Test on Android Device
```bash
# List devices
flutter devices

# Run on specific device (replace IP with your machine's local IP)
flutter run -d <device-id> \
  --dart-define=SUPABASE_URL=http://192.168.1.10:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

### Build for Web (Production)
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://kzjgdeqfmxkmpmadtbpb.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<production-key>

# Serve locally to test
python3 -m http.server --directory build/web 8080
# Open http://localhost:8080
```

---

## 🗄️ Database Migrations

### Viewing Schema
1. Open Supabase Studio: `http://127.0.0.1:54323`
2. Navigate to Table Editor
3. Check `sms_gateway` schema

### Applying Migrations
```bash
# Option 1: Supabase CLI
cd ~/techwareafricaadimn
supabase db push

# Option 2: SQL Editor in Studio
# Copy SQL from database/*.sql files
# Paste into Studio → SQL Editor → Run
```

### Creating Test Data
See `database/sample_test_data.sql` for examples.

---

## 🚀 Deploying to Netlify

### Automatic (Recommended)
Just push to `main`:
```bash
git push origin main
```

GitHub Actions will:
1. Build Flutter web
2. Deploy to Netlify
3. Available at smsgetway.techwareafrica.tech

### Manual Deploy
```bash
# Build
flutter build web --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key>

# Deploy
netlify deploy --prod --dir=build/web
```

---

## ❓ Troubleshooting

### "No devices connected"
See main project README or ask team lead. Common fixes:
- Enable USB debugging on phone
- Install udev rules (Linux)
- Run `adb kill-server && adb start-server`

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### "Can't connect to Supabase"
- Check local Supabase is running: `supabase status`
- Verify URL in `--dart-define` matches `supabase status` output
- Check no firewall blocking port 54321

### "RLS policy violation"
- Your user may not be in the tenant
- Check `client_product_access` table in Supabase Studio
- Ask team lead to add you as admin

---

## 📞 Getting Help

1. **Documentation**: Check SUPABASE.md, NETLIFY_DEPLOYMENT.md
2. **Code Questions**: Open a GitHub Discussion
3. **Bugs**: Open a GitHub Issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots
   - Console errors
4. **Team Lead**: @LWENA27 on GitHub

---

## ✅ Onboarding Checklist

Complete these to prove you're ready:

- [ ] Clone repo successfully
- [ ] Run `flutter pub get` with no errors
- [ ] Run app locally with local Supabase
- [ ] Log in or create account
- [ ] View contacts/groups screens
- [ ] Make a small code change (e.g., change a label)
- [ ] Create a PR with the change
- [ ] Read SUPABASE.md and understand multi-tenant model
- [ ] Read NETLIFY_DEPLOYMENT.md
- [ ] Understand where NOT to commit secrets

**When done**: Create a PR titled "chore: onboarding complete - [Your Name]" with a small change (e.g., add your name to a contributors list or fix a typo in docs).

---

## 🎯 Your First Tasks (Suggestions)

1. **Fix a small bug** from GitHub Issues
2. **Add a UI enhancement** (e.g., loading spinner, better empty state)
3. **Write a test** for an existing feature
4. **Improve documentation** (add examples, fix typos)
5. **Add a new admin feature** (e.g., user management page)

---

## 📋 Key Project Notes

- **Multi-tenant**: All data isolated by `tenant_id`
- **RLS enforced**: Database-level security, never bypass
- **Schema prefix**: Always use `sms_gateway.table_name`
- **Web + Mobile**: Same codebase, different platform features
- **Local dev first**: Test on local Supabase before production
- **CI/CD**: Push to main auto-deploys web to Netlify

---

**Welcome to the team!** 🎉

Start with SUPABASE.md, run the app locally, then pick your first task.
