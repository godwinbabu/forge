# Competitive Landscape Research

**Date:** 2026-03-27
**Purpose:** Inform SelfControl v5 feature decisions based on competitor analysis

---

## Freedom (freedom.to)

**Approach:** Local HTTP/HTTPS proxy on port 7769
**Platforms:** macOS, Windows, iOS, Android, Chromebook, Chrome extension

### Features
- Website blocking across all browsers (system-level proxy)
- App blocking (hide or force-quit on Mac)
- Full internet blocking mode
- Allowlist mode (block everything except specified sites)
- Custom and preset blocklists (social media, news, games, shopping, gambling)
- Advance scheduling with recurring sessions
- "Always-on" 24-hour persistent blocks
- **Locked Mode** — irreversible commitment, cannot end session early
- **Focus Sounds** — built-in ambient audio (Brain.fm tracks, cafe, library, nature)
- Cross-device sync (single session syncs across all enrolled devices)
- Chrome extension for supplementary blocking

### Technical Details
- Local proxy intercepts all web traffic (never leaves device)
- Compiled regex for real-time filtering
- Non-proxy mode available for VPN compatibility (1-2 second delay)
- iOS: local VPN profile (traffic stays on-device), Screen Time APIs on iOS 16+

### Differentiators
- Only app that syncs a single session across Mac/Win/iOS/Android simultaneously
- Anti-gamification philosophy — no streaks, points, or leaderboards
- Privacy-first — no activity tracking, no browsing logs

### Pricing
- Free: basic blocking, custom lists, sync, sounds, app blocking
- Monthly: $8.99 (adds scheduling, locked mode, >2h sessions)
- Yearly: $3.33/mo ($39.99/year)
- Lifetime: ~$100-160 one-time

---

## Cold Turkey (getcoldturkey.com)

**Approach:** OS-level blocking + browser extension
**Platforms:** Windows, macOS only

### Features
- Website blocking via browser extension (all major browsers)
- Application blocking (Pro only)
- Entire internet blocking with allowlist exceptions
- **"Frozen Turkey"** — locks computer, logs off, or shuts down entirely
- Click-and-drag weekly schedule builder (Pro)
- **5 Lock Types:**
  - Duration lock (cannot disable during set time)
  - Randomized text lock (type 1-999 random chars to unlock)
  - Time range locks (changes only during certain hours)
  - Restart lock (must restart computer to unlock)
  - Password lock (for accountability partners)
- Application and website usage time tracking
- "Biggest time-wasters" identification
- Charts and graphs for usage patterns
- All data stored locally, never collected

### Differentiators
- Strongest anti-bypass reputation ("The Toughest Website Blocker on the Internet")
- One-time purchase model
- Privacy-first (all data local)
- Multiple creative lock types
- Companion products: Cold Turkey Writer, Micromanager

### Pricing
- Free: basic website blocking
- Pro: $39 one-time (scheduling, app blocking, advanced locks, lifetime updates)

---

## Focus (heyfocus.com)

**Approach:** macOS-native blocking
**Platforms:** macOS only

### Features
- Website blocking across all browsers
- Application blocking
- "Entire Internet" blocking with allowlist
- Daily, weekly, weekend scheduling
- **Pomodoro timer** with configurable work rounds
- **Profiles** — task/project-specific blocking configs, switchable via Tab key
- **Scripting hooks** — custom scripts at session start/end/break
- Third-party Mac app integration via scripting
- Global keyboard shortcuts
- **Locked Mode** with optional password protection
- Daily/weekly/monthly/yearly performance metrics
- Streak tracking
- **Project time logging** (useful for freelancers)

### Differentiators
- Scripting hooks at session start/end/break (unique in category)
- Profiles with instant switching (Tab key)
- macOS-native, deeply integrated
- Project time tracking
- One-time purchase

### Pricing
- v1: $19 (core features)
- v2: $49 (adds Pomodoro, stats, profiles)
- Lifetime: $99 (all features + lifetime updates)
- Also on Setapp

---

## Opal (opal.so)

**Approach:** Screen Time API (iOS) + native app (Mac/Android)
**Platforms:** iOS, macOS, Android

### Features
- App-level blocking via "Focus Blocks"
- **"Deep Focus"** — nuclear option, prevents bypass
- **"App Lock"** — semi-permanent restrictions with limited daily unlocks
- **"App Limits"** — auto-blocking when daily thresholds hit
- Adjustable friction via "Snooze & Difficulty"
- Recurring daily/weekly Focus Blocks
- Profile-based configurations
- **"Focus Score"** — real-time screen time tracking
- Weekly progress reports with peer benchmarking
- Community annual Screen Time Report
- **Heavy gamification:** "Focus Gems" collectible rewards, leaderboards

### Differentiators
- Largest user base (4M+ users, 100K+ reviews, 4.8 rating)
- Heavy gamification (gems, leaderboards)
- Use-case segmentation (Students, Work, Wellbeing, Parents)
- Scientifically-backed claims

### Pricing
- Freemium, Pro ~$99.99/year, Family Sharing

---

## One Sec (one-sec.app)

**Approach:** Friction/delay — breathing exercises before app access
**Platforms:** iOS, Android, macOS, Windows, Linux, ChromeOS, browser extensions

### Features
- Breathing exercises before app opens (4-7-8 breathing, box breathing)
- Mirror reflection (shows user's face)
- **Conversational AI reflection**
- Phone rotation requirement
- Random text typing task, math problems
- Emotion and intention tracking prompts
- Journaling prompt before access
- **"Strict Block"** and **"Block timer"** for full blocking
- Emergency brake for time-limited access
- Re-interventions at set intervals
- Weekday/time-specific scheduling
- Category-based blocking
- "Always Ask" mode (set intended time before each use)
- Progress visualization, comparative statistics
- **LENGO integration** — forces vocabulary learning before social media

### Differentiators
- Fundamentally different philosophy: friction/mindfulness, not hard blocking
- Richest intervention type library
- Peer-reviewed: 57% average reduction in app usage (Max Planck Institute)
- Broadest platform support of any competitor
- Privacy-first (all logic local)

### Pricing
- Free: 1 app, breathing exercise only
- Pro: EUR 3.99/month, EUR 14.99/year, EUR 99.99 lifetime

---

## Quittr

**Approach:** Blocking + addiction recovery therapy
**Platforms:** iOS, Android, Web, Chrome extension
**Niche:** Primarily marketed for porn/addiction recovery

### Features
- "Advanced Blocker" for harmful content
- Multi-device protection
- Streak monitoring
- Achievement system (12 "Orb" levels)
- **"Melius"** — 24/7 AI therapist chatbot
- **"Panic Button"** — shows user's face with motivational messages during urges
- CBT (Cognitive Behavioral Therapy) principles
- Community forum (1.7M+ members)
- Meditation, journaling, relaxing sounds

### Pricing
- ~$9.99/month, ~$29.99-39.99/year

---

## Comparative Summary

| Feature | Freedom | Cold Turkey | Focus | Opal | One Sec | SelfControl v5 |
|---------|---------|------------|-------|------|---------|----------------|
| Website blocking | Yes | Yes | Yes | Limited | Via ext | Yes |
| App blocking | Yes | Yes (Pro) | Yes | Yes | Yes | Yes |
| Full internet block | Yes | Yes | Yes | No | No | Yes (allowlist) |
| Anti-bypass | Medium | Highest | High | Medium | Low | Highest (3 layers) |
| DoH bypass protection | No | Unknown | Unknown | No | No | Yes |
| Scheduling | Yes | Yes (Pro) | Yes + Pomodoro | Yes | Yes | Yes |
| Lock modes | Locked Mode | 5 types | Locked + password | Deep Focus | Strict Block | Commitment (time-locked) |
| Analytics | None | Local usage | Stats + project time | Rich + social | Progress | Focus time + blocks |
| Gamification | None | None | Streaks | Heavy | None | Minimal (streaks) |
| Privacy | Local only | Local only | Local only | Cloud-based | Local only | Local + optional iCloud |
| Open source | No | No | No | No | No | Yes |
| Pricing | $3-9/mo or $100 | $39 one-time | $19-99 one-time | ~$100/year | ~EUR 15/year | TBD |
| Platforms | All | Win + Mac | Mac only | iOS/Mac/Android | All | Mac only |

## Key Takeaways for SelfControl v5

1. **Anti-bypass credibility is SelfControl's strongest brand asset** — preserve and strengthen it with three enforcement layers
2. **Scheduling is table stakes** — every competitor except Quittr has it
3. **Local/privacy-first is a competitive advantage** — Cold Turkey, Focus, One Sec all emphasize it
4. **One-time purchase models work** — Cold Turkey ($39) and Focus ($19-99) prove it
5. **Scripting/automation hooks are underexplored** — Focus is the only one doing it
6. **Analytics expected but keep it simple** — basic stats, not Opal-level social gamification
7. **Profiles/contexts matter** — Cold Turkey and Focus both support multiple blocking configurations
8. **One Sec's friction approach is innovative** — worth considering as a future add-on to hard blocking
9. **DoH awareness is a gap in the market** — no competitor explicitly addresses encrypted DNS bypass
10. **Open source is unique** — SelfControl is the only open-source option in the entire category
