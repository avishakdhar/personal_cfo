# FinPilot.ai — Personal CFO

A full-featured personal finance management Flutter app powered by AI. Track accounts, expenses, budgets, investments, debts, and goals — with built-in AI insights, receipt scanning, and voice input.

---

## Features

| Category | Features |
|----------|----------|
| Accounts | Multiple accounts, balance tracking, transfers |
| Transactions | Income, expense, transfer, edit, soft-delete, search & filter |
| Budgets | Category-based monthly budgets with overspend alerts |
| Goals | Savings goals with progress tracking and contributions |
| Investments | Portfolio tracking, profit/loss, current value |
| Debts | Loan/EMI management with outstanding balance tracking |
| Recurring | Automated recurring transactions (daily/weekly/monthly/yearly) |
| AI Assistant | Chat with an AI financial advisor (Claude, OpenAI, Gemini) |
| AI Insights | Anomaly detection, subscription detection, cash flow prediction |
| Receipt Scanning | Scan receipts using camera/gallery with AI extraction |
| Reports | Monthly spending reports, category breakdown, CSV export |
| Backup | Full JSON backup and restore |
| Security | PIN lock, biometric auth support |

---

## Tech Stack

- **Framework:** Flutter 3.x / Dart 3.x
- **State Management:** Riverpod 2.x
- **Database:** SQLite via `sqflite` (local, offline-first)
- **AI Providers:** Anthropic Claude, OpenAI GPT-4o, Google Gemini
- **Charts:** fl_chart
- **Security:** flutter_secure_storage (API key encryption)
- **Notifications:** flutter_local_notifications
- **Voice Input:** speech_to_text
- **Export:** CSV + JSON backup

---

## Screenshots

> Add screenshots here after running the app.

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── navigation_screen.dart       # Bottom nav + drawer routing
├── core/
│   ├── database/                # SQLite helper, migrations (v3)
│   ├── models/                  # 9 data models
│   ├── providers/               # Riverpod providers (25+)
│   └── services/                # AI, export, notification services
├── features/
│   ├── accounts/                # Account management
│   ├── ai/                      # AI chat, insights, receipt scan
│   ├── auth/                    # PIN lock screen
│   ├── budgets/                 # Budget management
│   ├── dashboard/               # Home dashboard
│   ├── debts/                   # Debt & EMI tracker
│   ├── goals/                   # Savings goals
│   ├── investments/             # Portfolio tracker
│   ├── onboarding/              # First-run setup
│   ├── recurring/               # Recurring transactions
│   ├── reports/                 # Reports & CSV export
│   ├── settings/                # App settings & backup
│   └── transactions/            # Transaction management
└── widgets/                     # Reusable chart widgets
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.x ([install guide](https://docs.flutter.dev/get-started/install))
- An AI API key from one of:
  - [Anthropic (Claude)](https://console.anthropic.com) — recommended
  - [OpenAI](https://platform.openai.com/api-keys)
  - [Google Gemini](https://aistudio.google.com/app/apikey)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/avishakdhar/personal_cfo.git
cd personal_cfo

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Configure AI

On first launch, the onboarding screen will ask for your AI API key. You can also set or change it later in **Settings → AI Provider**.

The app supports:
- **Anthropic Claude** — best results for financial analysis
- **OpenAI GPT-4o** — widely available
- **Google Gemini** — free tier available

> Your API key is stored encrypted on-device using `flutter_secure_storage`. It is never sent anywhere except directly to the AI provider's official API.

---

## Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Mac + Xcode)
flutter build ios --release
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.

## Author

Avishak Dhar
