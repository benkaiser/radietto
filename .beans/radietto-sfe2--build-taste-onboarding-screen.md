---
# radietto-sfe2
title: Build taste onboarding screen
status: completed
type: feature
priority: normal
created_at: 2026-04-28T13:53:09Z
updated_at: 2026-04-28T14:00:43Z
parent: radietto-6vo6
blocking:
    - radietto-adth
---

Create the genre preference slider screen shown on first launch.

## Design:
- Clean, welcoming screen with app branding
- Title: "Tune Your Radio" or similar
- Subtitle explaining that sliders shape the music mix
- Grid/list of genre sliders:
  - Rock, Pop, Jazz, Classical, Metal, Electronic, Hip-Hop, Country, R&B, Folk, Reggae, Blues
  - Each slider: 0 (dislike) to 10 (love), default 5 (neutral)  
  - Show genre name and current value
- "Start Listening" primary button
- "Skip - Just Play Everything" text button (uses all defaults)

## Behavior:
- First launch: show this screen
- Save preferences to SharedPreferences
- Navigate to main radio screen after saving
- Accessible later from settings to re-tune

## Checklist
- [x] Create lib/screens/taste_onboarding_screen.dart
- [x] Genre slider widget with label and value display
- [x] Start Listening button that saves and navigates
- [x] Skip button that uses defaults and navigates
- [x] Persist preferences via TasteProvider