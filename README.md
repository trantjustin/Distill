# Distill

An iOS app that distils books into their core learnings using AI, with a home screen widget.

- **Website:** https://trantjustin.github.io/Distill/
- **Support:** https://trantjustin.github.io/Distill/support.html
- **Privacy:** https://trantjustin.github.io/Distill/privacy.html

This repository hosts the GitHub Pages site for Distill (in [`docs/`](docs/)).

## Features

- **AI-Powered Learnings** — search or scan a book → AI generates 8 concise, actionable insights
- **Subscription Access** — 7-day free trial, then $2.99/month for unlimited generations
- **Book Artwork** — automatically fetches cover art from Open Library
- **Library** — browse all your books with cover art
- **Daily Review** — swipe through learnings with spaced-repetition style cards
- **Customisable Home Screen Widget** — small, medium, and large sizes; refresh rate and attribution
- **Share Extension** — share text or URLs from any app to add books
- **On-device storage** — all book data stored locally with SwiftData

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- Apple Developer account (required for App Groups / widget / share extension / IAP)
- A Cloudflare Workers backend (see [`DistillBackend/`](../DistillBackend))
- A Groq API key

## Setup

1. Open `Distill.xcodeproj` in Xcode
2. **Set your Team**: Select the Distill, DistillWidget, and DistillShareExtension targets → Signing & Capabilities → set your development team
3. **App Group**: All targets need App Group `group.com.jtrant.distill`
4. **Bundle IDs**:
   - Distill: `com.jtrant.distill`
   - DistillWidget: `com.jtrant.distill.widget`
   - DistillShareExtension: `com.jtrant.distill.share`
5. Add the **TelemetryDeck** Swift package: `https://github.com/TelemetryDeck/SwiftSDK`
6. Set your backend URL in `Distill/Sources/Models/BackendConfig.swift`
7. Build & run

## App Store Connect Configuration

Before shipping, configure in-app purchases:

1. Create an **Auto-Renewable Subscription** with ID `com.jtrant.distill.subscription.monthly`
2. Set the price to **$2.99 / month**
3. Add a **7-day free trial** introductory offer
4. Generate an **App-Specific Shared Secret** and add it to your Cloudflare Worker secrets
5. Upload the paid apps agreement and tax/banking information to enable IAP

## Testing Subscriptions Locally

1. Open **Product → Scheme → Edit Scheme → Run → Options**
2. Set **StoreKit Configuration** to `Distill.storekit`
3. Run the app and use a sandbox Apple ID to test the 7-day trial flow

## Widget Setup

1. Long-press the home screen → **+**
2. Search for **Distill**
3. Choose a size → tap **Add Widget**
4. Long-press the widget → **Edit Widget** to customise refresh rate and attribution

## Project Structure

```
Distill/
├── Distill/
│   ├── DistillApp.swift
│   ├── Assets.xcassets/
│   ├── Distill.storekit         # Local StoreKit test configuration
│   └── Sources/
│       ├── Models/
│       │   ├── BackendConfig.swift
│       │   ├── Book.swift
│       │   └── Learning.swift
│       ├── Views/
│       │   ├── ContentView.swift
│       │   ├── LibraryView.swift
│       │   ├── AddBookView.swift
│       │   ├── BookDetailView.swift
│       │   ├── ReviewView.swift
│       │   ├── SettingsView.swift
│       │   └── PaywallView.swift
│       ├── Services/
│       │   ├── AIService.swift
│       │   ├── BookCoverService.swift
│       │   ├── OpenLibraryService.swift
│       │   ├── ReceiptProvider.swift
│       │   └── SubscriptionManager.swift
│       └── Utilities/
│           └── CoverColors.swift
├── DistillWidget/
│   └── Sources/
│       └── DistillWidget.swift
├── DistillShareExtension/
│   └── ShareViewController.swift
├── Shared/
│   └── WidgetDataManager.swift
└── docs/                          # GitHub Pages site
```
