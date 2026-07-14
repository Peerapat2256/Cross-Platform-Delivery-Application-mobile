# Delivery Application

A cross-platform mobile delivery application built with Flutter. It provides dedicated interfaces for both riders and customers, using Firebase for database operations and real-time status updates.

## Demo

<p align="center">
  <img src="assets/images/register.png" width="220"/>
  <img src="assets/images/register member.png" width="220"/>
  <img src="assets/images/register rider.png" width="220"/>
  <img src="assets/images/login.png" width="220"/>
  <img src="assets/images/create job.png" width="220"/>
  <img src="assets/images/job preview.png" width="220"/>
  <img src="assets/images/accept job.png" width="220"/>
  <img src="assets/images/job history.png" width="220"/>
  <img src="assets/images/track job.png" width="220"/>

</p>


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
