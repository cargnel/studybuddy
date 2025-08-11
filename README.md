# studybuddy

A new Flutter project.

## Description

The "Study Buddy" Flutter application is designed to help users manage their study and leisure time effectively. It incorporates a Pomodoro timer for focused work sessions and a separate timer to track gaming activities. Key functionalities include:

*   **Study Timer (Pomodoro):** Users can start a Pomodoro timer for focused study sessions. The duration of work and short breaks are configurable in the settings. The timer can be started, paused, resumed, and stopped. Study sessions are logged.
*   **Game Timer:** Users can track the time they spend gaming. This timer can also be started, paused, resumed, and stopped. Game sessions are logged.
*   **Malus System:** To encourage focused study, a "malus" system is implemented. If a user plays games before achieving a daily study goal (defaulted to 120 minutes) or if they already have malus time, playing games will increase their malus time. This malus time is calculated based on the duration of the game session and a configurable ratio.
*   **User Authentication:** Users sign in via their Google accounts. Firebase Authentication is used for this.
*   **Settings:** Users can customize:
    *   Pomodoro work duration.
    *   Pomodoro short break duration.
    *   The ratio used to calculate malus time from game time.
    These settings are saved per user in Firestore.
*   **Data Persistence:** Timer states (e.g., current time, whether a timer is running/paused) and user settings are saved using Firebase Firestore, allowing data to persist across sessions. Session logs (study and game) are also stored.
*   **Daily Totals:** The application tracks and displays the total time spent on study and gaming for the current day.
*   **Navigation:** The app includes navigation between the login page, a home page (dashboard), separate pages for the Pomodoro and Game timers, and a settings page.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
