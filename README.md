# Distill

An iOS app that distils books into their core learnings using AI, with a home screen widget.

- **Website:** https://trantjustin.github.io/Distill/
- **Support:** https://trantjustin.github.io/Distill/support.html
- **Privacy:** https://trantjustin.github.io/Distill/privacy.html

This repository hosts the GitHub Pages site for Distill (in [`docs/`](docs/)).

## Features

- **AI-Powered Learnings** — search or scan a book → AI generates 8 concise, actionable insights
- **Multi-Provider AI** — supports OpenAI, Claude, Gemini, and Perplexity
- **Book Artwork** — automatically fetches cover art from Open Library
- **Library** — browse all your books with cover art
- **Daily Review** — swipe through learnings with spaced-repetition style cards
- **Customisable Home Screen Widget** — small, medium, and large sizes; colour theme; refresh rate
- **Share Extension** — share text or URLs from any app to add books
- **On-device storage** — all data stored locally with SwiftData, never sent to any server

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- An API key from one of: [OpenAI](https://platform.openai.com), [Anthropic](https://console.anthropic.com), [Google AI Studio](https://aistudio.google.com), or [Perplexity](https://docs.perplexity.ai)
- Apple Developer account (required for App Groups / widget / share extension)

## Setup

1. Open `Distill.xcodeproj` in Xcode
2. **Set your Team**: Select the Distill, DistillWidget, and DistillShareExtension targets → Signing & Capabilities → set your development team
3. **App Group**: All targets need App Group `group.com.jtrant.distill`
4. **Bundle IDs**:
   - Distill: `com.jtrant.distill`
   - DistillWidget: `com.jtrant.distill.widget`
   - DistillShareExtension: `com.jtrant.distill.share`
5. Add the **TelemetryDeck** Swift package: `https://github.com/TelemetryDeck/SwiftSDK`
6. Build & run

## Adding an API Key

1. Launch the app → **Settings** tab
2. Paste your API key under the relevant provider
3. The provider unlocks automatically once a valid key is entered

## Widget Setup

1. Long-press the home screen → **+**
2. Search for **Distill**
3. Choose a size → tap **Add Widget**
4. Long-press the widget → **Edit Widget** to customise colour theme and refresh rate

## Project Structure

```
Distill/
├── Distill/
│   ├── DistillApp.swift
│   ├── Assets.xcassets/
│   └── Sources/
│       ├── Models/
│       │   ├── Book.swift
│       │   └── Learning.swift
│       ├── Views/
│       │   ├── ContentView.swift
│       │   ├── LibraryView.swift
│       │   ├── AddBookView.swift
│       │   ├── BookDetailView.swift
│       │   ├── ReviewView.swift
│       │   └── SettingsView.swift
│       ├── Services/
│       │   ├── AIService.swift
│       │   ├── BookCoverService.swift
│       │   └── OpenLibraryService.swift
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
