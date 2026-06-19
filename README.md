# ClassGuard

## Overview
ClassGuard is a comprehensive mobile application designed to maintain academic integrity and enhance student focus during class sessions and examinations. By utilizing robust background services and system-level application-locking mechanisms, ClassGuard ensures that students remain engaged with their academic tasks without digital distractions.

## Core Features
* **Automated Schedule Management:** Set personal routines to automatically activate Focus Mode, silencing the device and restricting access to specified applications.
* **Classroom Synchronization:** Teachers can generate unique access codes for virtual rooms. Once students join, the application enforces synchronous focus rules (Silent Mode and App Lock) across all enrolled devices.
* **Secure Exam Mode:** Hosts can deploy a strict examination environment. The application actively monitors student presence and locks devices into the exam interface until formal submission.
* **Deep Doze Bypass & Background Persistence:** Implements native Android MethodChannels to utilize `AlarmManager.setAlarmClock()` and Foreground Services. This ensures scheduled restrictions execute reliably, bypassing aggressive manufacturer battery optimizations (Deep Doze).
* **Anti-Tampering Security:** Continuously monitors accessibility and overlay permissions. If a student attempts to disable required permissions during an active session, a non-dismissible monochrome warning interface is deployed.
* **FCM Warmup Scheduler:** Utilizes GitHub Actions and Firebase Cloud Messaging (FCM) to trigger a device warmup sequence five minutes before a scheduled session, ensuring protection services remain active even under aggressive battery optimization policies.

## Technology Stack
* **Frontend Framework:** Flutter (Dart)
* **Backend Integration:** Firebase (Authentication, Cloud Firestore, Cloud Messaging)
* **Native Android Architecture:** Kotlin (Broadcast Receivers, Foreground Services, Method Channels)
* **Automation & Scheduling:** GitHub Actions

## Project Structure
The application follows a highly modular **Feature-First Architecture** to maintain scalability and separation of concerns.

```text
lib/
├── core/
│   ├── background/        (Native communication and alarm services)
│   ├── routes/            (Application routing logic)
│   ├── services/          (Global Firebase and Firestore services)
│   ├── theme/             (Centralized styling and typography)
│   └── utils/             (Helper functions, e.g., time formatting)
├── features/
│   ├── auth/              (Authentication logic and screens)
│   ├── classroom/         (Multi-user synchronization and teacher dashboards)
│   ├── dashboard/         (Main user interface and schedule creation)
│   ├── exam/              (Secure testing environment and history)
│   └── onboarding/        (System permission requests and tutorials)
├── models/
│   ├── course.dart        (Data model for schedules and classrooms)
│   └── exam.dart          (Data model for examination sessions)
├── shared/                (Reusable UI Components)
│   ├── dialogs/
│   │   └── confirm_dialog.dart
│   ├── feedback/
│   │   ├── empty_state.dart
│   │   ├── info_banner.dart
│   │   └── status_badge.dart
│   └── widgets/
│       ├── app_selection_tile.dart
│       ├── classroom_card.dart
│       ├── custom_bottom_sheet.dart
│       ├── day_selector.dart
│       ├── exam_card.dart
│       ├── exam_type_chip.dart
│       ├── loading_overlay.dart
│       ├── permission_tile.dart
│       ├── primary_button.dart
│       ├── schedule_card.dart
│       ├── section_header.dart
│       ├── setting_card.dart
│       └── time_info_row.dart
└── main.dart

Prerequisites
To build and run this project, ensure the following tools are installed:

Flutter SDK (Latest stable version)

Android Studio with the latest Android SDK

A valid google-services.json file for Firebase integration (must be placed in the android/app/ directory)

Installation & Setup
Clone the repository to your local machine:

git clone [https://github.com/](https://github.com/)[Your-Username]/ClassGuard.git

Navigate to the project directory and install the required Dart dependencies:

flutter pub get

Configure the necessary Android device permissions. For optimal background performance on custom Android operating systems (e.g., MIUI, ColorOS, OriginOS, OneUI), ensure the following permissions are granted manually during the initial application setup:

Do Not Disturb

Usage Access

Accessibility Services

Display Over Other Apps (Overlay)

Auto-Start / Allow Background Execution

Unrestricted Battery Usage

Compile and run the application:

flutter run

Contributors
Wildan Ariel Heradi - Lead Developer & Native Android Architecture
Ardian Biahlil Badri
Muhammad Hafidin Zakaria