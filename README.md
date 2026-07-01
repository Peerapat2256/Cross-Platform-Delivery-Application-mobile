# Delivery Application

A cross-platform mobile delivery application built with Flutter. It provides dedicated interfaces for both riders and customers, using Firebase for database operations and real-time status updates.

## Features

* **User Features**:
  * Registration and login interface.
  * Create new delivery jobs with location and item details.
  * View delivery history and track active orders in real-time.
* **Rider Features**:
  * Registration and login interface.
  * Job preview panel to browse available deliveries.
  * Accept delivery jobs and update status (picking up, delivering, completed).
* **Firebase Integration**: Uses Cloud Firestore for real-time data synchronization and tracking.

## How to Run

### Prerequisites
* Flutter SDK installed.
* An active emulator/simulator or physical device connected.

### Compilation and Execution

1. Get the package dependencies:
   ```bash
   flutter pub get
   ```

2. Run the application:
   ```bash
   flutter run
   ```
