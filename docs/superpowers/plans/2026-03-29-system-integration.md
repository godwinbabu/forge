# System Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notifications, keyboard shortcuts, command palette, App Intents, widget data sync, and iCloud sync.

**Architecture:** Each sub-feature is independent. NotificationService wraps UNUserNotificationCenter. FuzzyMatcher (ForgeKit) provides testable search. App Intents enable Shortcuts.app integration. iCloudSyncService uses NSUbiquitousKeyValueStore.

**Tech Stack:** SwiftUI, UserNotifications, AppIntents, WidgetKit, ForgeKit, Swift Testing

---

## Task Overview

1. FuzzyMatcher (ForgeKit, TDD)
2. NotificationService
3. Keyboard Shortcuts
4. Command Palette (⌘K)
5. App Intents (StartBlock, GetStatus, Extend)
6. Widget Data Sync
7. iCloud Sync
8. Wire Notifications into BlockEngine/ScheduleEvaluator
9. Final verification
