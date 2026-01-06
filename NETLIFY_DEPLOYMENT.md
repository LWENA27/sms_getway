# 🚀 Netlify Deployment Guide

Deploy SMS Gateway Pro web admin to **smsgetway.techwareafrica.tech**

---

## ⚡ Quick Summary

This project uses **GitHub Actions** for automated build and deployment to Netlify:
- ✅ Push to `main` branch → GitHub Actions builds Flutter web → Deploys to Netlify
- ✅ No manual builds needed
- ✅ Environment variables handled securely via GitHub Secrets
- ✅ Automatic deployment on every commit

---

## 📋 Prerequisites

1. **GitHub Repository**: Code pushed to `LWENA27/sms_getway`
2. **Netlify Account**: Signed up at [netlify.com](https://netlify.com)
3. **Domain Access**: DNS control for `techwareafrica.tech`
4. **Supabase Project**: Production or local instance running
5. **GitHub Secrets Configured**: NETLIFY_AUTH_TOKEN, NETLIFY_SITE_ID, SUPABASE_URL, SUPABASE_ANON_KEY

---

## 🔧 Setup Steps

### 1. Connect Repository to Netlify

**Option A: Via Netlify Dashboard (Recommended)**
1. Go to [app.netlify.com](https://app.netlify.com)
2. Click "Add new site" → "Import an existing project"
3. Choose "GitHub" and authorize Netlify
4. Select repository: `LWENA27/sms_getway`
5. **Build settings**:
   - **Build command**: `echo 'Build is handled by GitHub Actions' && ls -la`
   - **Publish directory**: `build/web`
   - **Branch**: `main`
   - ⚠️ **Important**: Netlify won't build; GitHub Actions will deploy built files
6. Click "Deploy site"

**Option B: Manual Deploy (Quick Test)**
1. Build locally:
   ```bash
   flutter clean
   flutter pub get
   flutter build web --release \
     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
     --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
   ```
2. Install Netlify CLI:
   ```bash
   npm install -g netlify-cli
   netlify login
   ```
3. Deploy:
   ```bash
   netlify deploy --prod --dir=build/web
   ```

### 2. Configure Custom Domain

1. In Netlify Dashboard → Site settings → Domain management
2. Click "Add custom domain"
3. Enter: `smsgetway.techwareafrica.tech`
4. Netlify will provide DNS instructions

**DNS Configuration** (in your domain provider):
```
Type: CNAME
Name: smsgetway
Value: <your-site-name>.netlify.app
TTL: 3600
```

Or if using Netlify DNS:
```
Type: ALIAS or ANAME
Name: smsgetway.techwareafrica.tech
Value: apex-loadbalancer.netlify.com
```

5. Wait for DNS propagation (5-60 minutes)
6. Netlify will auto-provision SSL certificate (Let's Encrypt)

### 3. Set Environment Variables

In Netlify Dashboard → Site settings → Build & deploy → Environment → Environment variables:

| Variable | Value | Notes |
|----------|-------|-------|
| `SUPABASE_URL` | `http://127.0.0.1:54321` or production URL | Required |
| `SUPABASE_ANON_KEY` | `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH` | Safe for browser |

**For local Supabase (development)**:
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```

**For production Supabase**:
```
SUPABASE_URL=https://kzjgdeqfmxkmpmadtbpb.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6amdkZXFmbXhrbXBtYWR0YnBiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyOTk3NjQsImV4cCI6MjA2NDg3NTc2NH0.NTEzbvVCQ_vNTJPS5bFPSOm5XNRjUrFpSUPEWQDm434
```

⚠️ **Never commit** these values to git! Always use Netlify environment variables.

### 4. Setup GitHub Actions for Auto-Deploy

GitHub secrets required (Settings → Secrets and variables → Actions → New repository secret):

| Secret Name | How to Get It |
|-------------|---------------|
| `NETLIFY_AUTH_TOKEN` | Netlify → User settings → Applications → Personal access tokens → New token |
| `NETLIFY_SITE_ID` | Netlify → Site settings → General → Site details → API ID |
| `SUPABASE_URL` | From your Supabase project or local instance |
| `SUPABASE_ANON_KEY` | From Supabase project settings → API → anon public |

The workflow file `.github/workflows/deploy-netlify.yml` is already created. It will:
- ✅ Build Flutter web on every push to `main`
- ✅ Run `flutter analyze`
- ✅ Deploy to Netlify automatically
- ✅ Comment on PRs with preview URLs

---

## 🏗️ Build Process

### Automated (via GitHub Actions)
Push to main branch:
```bash
git add .
git commit -m "Update web app"
git push origin main
```

GitHub Actions will:
1. Checkout code
2. Install Flutter
3. Run `flutter pub get`
4. Run `flutter analyze`
5. Build with `flutter build web --release`
6. Deploy `build/web` to Netlify
7. Result available at `smsgetway.techwareafrica.tech`

### Manual Build (Local)
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for production with Supabase config
flutter build web --release \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH

# Output: build/web/
```

Then deploy using Netlify CLI:
```bash
netlify deploy --prod --dir=build/web
```

---

## 🧪 Testing Deployment

### Local Test Before Deploy
```bash
# Build
flutter build web --release \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH

# Serve locally
python3 -m http.server --directory build/web 8080

# Open: http://localhost:8080
```

Test checklist:
- [ ] Login works
- [ ] Dashboard loads
- [ ] Contacts page shows data from local Supabase
- [ ] Groups page works
- [ ] SMS log displays
- [ ] No console errors
- [ ] Network calls go to `127.0.0.1:54321` (check DevTools)

### Production Test
After deploy, test at `https://smsgetway.techwareafrica.tech`:
- [ ] HTTPS works (green padlock)
- [ ] Login redirects properly
- [ ] SPA routing works (refresh on any page)
- [ ] API calls go to production Supabase
- [ ] No CORS errors
- [ ] Mobile responsive

---

## 🔍 Troubleshooting

### Build Fails: "flutter: command not found"
- **Solution**: Use GitHub Actions (already configured) or manual deploy
- Netlify build image doesn't have Flutter by default
- GitHub Actions installs Flutter in CI

### Error: "Can't redefine existing key [build]"
- **Cause**: Duplicate `[build]` section in `netlify.toml`
- **Solution**: Fixed in latest commit - only one `[build]` section now

### SPA Routing Not Working (404 on refresh)
- **Cause**: Missing redirect rule
- **Solution**: Already in `netlify.toml`:
  ```toml
  [[redirects]]
    from = "/*"
    to = "/index.html"
    status = 200
  ```

### CORS Errors
- **Supabase local**: Add your Netlify URL to Supabase allowed origins
- **Supabase cloud**: Usually auto-configured, but check project settings

### Environment Variables Not Working
1. Check they're set in Netlify UI (not just GitHub secrets)
2. Rebuild site (Netlify → Deploys → Trigger deploy → Clear cache and deploy)
3. Verify in browser DevTools → Network → see request URLs

### SSL Certificate Issues
- Wait 60 minutes for DNS propagation
- Verify DNS with: `dig smsgetway.techwareafrica.tech`
- Check Netlify → Domain settings → HTTPS → Renew certificate

---

## 📊 Monitoring

### Netlify Analytics
- Real-time visitor stats
- Bandwidth usage
- Deploy history

### Supabase Logs
- API usage
- Auth events
- Database queries

### Browser Console
Check for:
- Network errors
- API response codes
- WebSocket connections (if using Realtime)

---

## 🔄 CI/CD Pipeline

```
┌─────────────────────────────────────────────────┐
│  Developer pushes to main                       │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│  GitHub Actions triggered                       │
│  - Install Flutter 3.24.5                       │
│  - Run flutter pub get                          │
│  - Run flutter analyze                          │
│  - Build web with --dart-define (Supabase keys) │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│  Deploy to Netlify                              │
│  - Upload build/web/* to CDN                    │
│  - Invalidate old cache                         │
│  - Generate deploy preview                      │
└────────────────┬────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────────────┐
│  Live at https://smsgetway.techwareafrica.tech  │
└─────────────────────────────────────────────────┘
```

---

## 🎯 Next Steps

1. ✅ Push code to GitHub
2. ✅ Connect Netlify to repo
3. ✅ Add GitHub secrets (NETLIFY_AUTH_TOKEN, NETLIFY_SITE_ID, SUPABASE_*)
4. ✅ Configure custom domain in Netlify
5. ✅ Update DNS records
6. ✅ Push to main → auto-deploy
7. ✅ Verify at smsgetway.techwareafrica.tech

---

## 📞 Support Contacts

- **Netlify Support**: https://answers.netlify.com/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Flutter Web Docs**: https://docs.flutter.dev/platform-integration/web

---

## 🔐 Security Checklist

- [ ] HTTPS enabled (automatic via Netlify)
- [ ] Environment variables never committed to git
- [ ] Only `anon` key used in browser (never service_role)
- [ ] RLS policies enabled in Supabase
- [ ] Security headers configured (in netlify.toml)
- [ ] CORS properly configured
- [ ] Rate limiting on API (Supabase built-in)

---

**Status**: Ready to deploy! 🚀

Run `git push origin main` to trigger auto-deploy via GitHub Actions.
