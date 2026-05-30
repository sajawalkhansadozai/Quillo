# Quillo — In-App Purchases Setup

Quillo uses **[RevenueCat](https://www.revenuecat.com)** (`purchases_flutter`) for subscriptions. The app already includes:

- Paywall screen (`lib/screens/paywall_screen.dart`)
- Purchase & restore via `SubscriptionService`
- Premium checks (ads off, higher scan limits)
- Supabase `users.subscription_status` sync

You need to configure the **stores** and **RevenueCat**, then add API keys to the app.

---

## 1. Product IDs (use these everywhere)

| Product | ID | Type |
|---------|-----|------|
| Monthly | `quillo.premium.monthly` | Auto-renewable subscription, 1 month |
| Yearly | `quillo.premium.yearly` | Auto-renewable subscription, 1 year |

**Entitlement ID (RevenueCat):** `premium`

---

## 2. Apple App Store Connect

1. Open [App Store Connect](https://appstoreconnect.apple.com) → your app → **Subscriptions**.
2. Create a **Subscription Group** (e.g. `Quillo Pro`).
3. Add two subscriptions with IDs above.
4. Set prices (e.g. £4.99/month, £44.99/year).
5. Optional: add a **free trial** (e.g. 7 days) on one product.
6. Submit subscription metadata for review with your app.

**Capabilities:** Xcode → Runner target → **Signing & Capabilities** → add **In-App Purchase**.

**Sandbox testing:** App Store Connect → Users and Access → Sandbox testers. Sign in on device: Settings → App Store → Sandbox Account.

---

## 3. Google Play Console

1. Open [Google Play Console](https://play.google.com/console) → your app → **Monetize** → **Subscriptions**.
2. Create subscriptions `quillo.premium.monthly` and `quillo.premium.yearly`.
3. Activate base plans and set prices.
4. Link a **payments profile** and complete merchant setup.

**Testing:** License testers in Play Console → add Gmail accounts. Install app via internal testing track.

---

## 4. RevenueCat

1. Create project at [app.revenuecat.com](https://app.revenuecat.com).
2. Add **iOS** and **Android** apps (bundle ID / package name must match Flutter app).
3. Connect **App Store Connect** (Shared Secret / App Store Connect API key).
4. Connect **Google Play** (service account JSON).
5. Create **Entitlement** named exactly: `premium`.
6. Create **Offering** `default` with packages:
   - Monthly → `quillo.premium.monthly`
   - Annual → `quillo.premium.yearly`
7. Copy **public API keys**:
   - iOS: `appl_...`
   - Android: `goog_...`

---

## 5. Add API keys to the Flutter app

**Option A — dart-define (recommended)**

```bash
flutter run \
  --dart-define=REVENUECAT_IOS_KEY=appl_YOUR_IOS_KEY \
  --dart-define=REVENUECAT_ANDROID_KEY=goog_YOUR_ANDROID_KEY
```

**Option B — edit defaults** in `lib/config/iap_config.dart` (not recommended for production keys in git).

Keys are read in `SubscriptionService.configure()` on app launch (`main.dart`).

---

## 6. Verify in the app

1. Run on a **real device** or simulator with sandbox / license tester account.
2. Open **Profile → Go Pro** (or hit scan limit).
3. Plans should show **live prices** from the store.
4. Tap subscribe → Apple/Google payment sheet.
5. After purchase: Profile shows **Active ✓**, ads hidden, scan limit raised.
6. Tap **Restore Purchases** on another device with same store account.

---

## 7. What happens after purchase

1. RevenueCat validates receipt.
2. `premium` entitlement becomes active.
3. App updates Supabase `users.subscription_status` → `premium`.
4. RPC `set_premium_limit` raises daily scan cap.
5. `DailyLimitService` / `AdBanner` respect premium status.

---

## 8. Troubleshooting

| Issue | Fix |
|-------|-----|
| "Products not available" | Check product IDs match exactly; offerings configured in RevenueCat; wait up to a few hours after creating products |
| **CONFIGURATION_ERROR / offerings empty** | **Bundle ID** in Xcode (`com.example.quillo`) must match App Store Connect + RevenueCat exactly. Finish subscription metadata. Link App Store Connect API in RevenueCat. Test on a real device with Sandbox account, or use `ios/Quillo.storekit` via Xcode Run scheme |
| "Add RevenueCat API keys" | Pass `--dart-define` keys or replace placeholders |
| Purchase works but not premium | Entitlement must be named `premium` |
| Restore finds nothing | Same Apple ID / Google account used for purchase |
| iOS simulator | Use StoreKit Configuration file or sandbox Apple ID |

---

## 9. App Store review notes

- Provide a **sandbox test account** in App Review notes.
- Document what **Quillo Pro** unlocks (unlimited scans, no ads, etc.).
- Link to Terms and Privacy URLs in App Store listing.

---

## Files reference

| File | Purpose |
|------|---------|
| `lib/config/iap_config.dart` | Product IDs, API keys |
| `lib/services/subscription_service.dart` | RevenueCat purchase logic |
| `lib/screens/paywall_screen.dart` | Subscription UI |
| `lib/services/daily_limit_service.dart` | Free vs premium limits |
