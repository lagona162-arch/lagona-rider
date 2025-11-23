# Lagona Rider App

A Flutter mobile application specifically designed for **Riders** in the Lagona delivery and logistics network.

## Overview

This is a **Rider-only application** that enables riders to:
- Register using Loading Station Code (LSCODE)
- Receive and accept delivery requests (Pabili and Padala)
- View pickup and drop-off locations
- Track deliveries using Google Maps
- Request top-up credits from Loading Stations
- View balance, commission, and earnings
- Update delivery status and complete deliveries

## Features

### EPIC 1: Rider Registration
- **Rider Registration with LSCODE**: Riders register using a Loading Station Code (LSCODE) to link to their assigned Loading Station
- **Account Verification**: Riders wait for admin approval after registration
- **Rider-Only App**: This app is exclusively for riders; other roles are not supported

### EPIC 2: Commission and Top-Up System
- **Commission Tracking**: Riders can view their commission rate and earnings
- **Top-Up Requests**: Riders can request top-up credits from their Loading Station
- **Balance Management**: Real-time balance tracking and display
- **Top-Up History**: View past top-up requests and transactions

### EPIC 3: Pabili Module (Food & Grocery Delivery)
- **Receive Delivery Requests**: Riders receive Pabili delivery requests from their Loading Station
- **Accept Deliveries**: Riders can accept available deliveries
- **View Pickup and Drop-off Points**: Google Maps integration for route viewing
- **Update Delivery Status**: Mark orders as picked up, in transit, and completed
- **Complete Deliveries**: Confirm delivery completion

### EPIC 4: Padala Module (Parcel Delivery Service)
- **Receive Padala Requests**: Riders receive Padala (parcel) delivery requests
- **View Pickup and Drop-off Addresses**: Clear display of delivery addresses
- **Track Deliveries**: Real-time tracking through Google Maps
- **Delivery Confirmation**: Confirm delivery completion at drop-off location

### EPIC 7: Google Maps Routing Integration
- **Route Viewing**: View pickup and drop-off locations on map
- **Route Optimization**: View optimized routes (pending implementation)
- **Real-time Tracking**: Track delivery progress (pending implementation)
- **Navigation Support**: Google Maps integration for navigation (pending implementation)

## Project Structure

```
lib/
├── core/
│   ├── config/
│   │   └── supabase_config.dart        # Supabase configuration
│   ├── constants/
│   │   ├── app_constants.dart          # App constants (roles, statuses, etc.)
│   │   └── app_colors.dart             # App color constants
│   ├── models/
│   │   ├── user_model.dart             # User model
│   │   ├── rider_model.dart            # Rider model
│   │   ├── delivery_model.dart         # Delivery model
│   │   └── topup_model.dart            # Top-up model
│   ├── providers/
│   │   └── auth_provider.dart          # Authentication provider
│   └── services/
│       ├── supabase_service.dart       # Supabase client
│       ├── auth_service.dart           # Authentication service (Rider only)
│       ├── delivery_service.dart       # Delivery management (Rider operations)
│       ├── rider_service.dart          # Rider management
│       ├── topup_service.dart          # Top-up management (Rider requests)
│       ├── registration_service.dart   # Registration and LSCODE validation
│       └── location_service.dart       # Location services (GPS, geocoding)
└── screens/
    ├── auth/
    │   ├── login_screen.dart           # Login screen
    │   ├── register_screen.dart        # Registration screen (Rider only, LSCODE required)
    │   └── auth_wrapper.dart           # Auth wrapper (routes to Rider home)
    ├── rider/
    │   ├── rider_home_screen.dart      # Rider dashboard
    │   ├── rider_deliveries_screen.dart # Delivery list (available and assigned)
    │   ├── rider_profile_screen.dart   # Rider profile, balance, and status
    │   └── rider_topup_request_screen.dart # Top-up request to Loading Station
    └── delivery/
        └── delivery_detail_screen.dart # Delivery details, route, and actions
```

## Setup

### Prerequisites
- Flutter SDK (3.9.2 or higher)
- Dart SDK
- Android Studio / Xcode
- Supabase account
- Google Maps API key

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd lagona_rider_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Supabase:
   - The Supabase credentials are already configured in `lib/core/config/supabase_config.dart`
   - Ensure your Supabase project has the database schema set up

4. Configure Google Maps:
   - Replace `YOUR_GOOGLE_MAPS_API_KEY` in `android/app/src/main/AndroidManifest.xml` with your Google Maps API key
   - For iOS, add your API key to `ios/Runner/AppDelegate.swift`

5. Run the app:
```bash
flutter run
```

## User Flow

### Registration
1. Rider opens the app
2. Clicks "Sign Up"
3. Enters full name, email, password, phone (optional)
4. Enters Loading Station Code (LSCODE)
5. Submits registration
6. Waits for admin approval

### Accepting Deliveries
1. Rider sees available deliveries in the "Deliveries" tab
2. Clicks on a delivery to view details
3. Clicks "Accept Delivery" to accept
4. Rider status changes to "busy"

### Completing Deliveries
1. Rider accepts delivery
2. Marks as "Picked Up" when at pickup location
3. Marks as "In Transit" when starting delivery
4. Marks as "Completed" when customer confirms receipt
5. Rider status changes back to "available"

### Requesting Top-Up
1. Rider goes to Profile tab
2. Clicks "Request Top-Up"
3. Enters amount
4. Submits request to Loading Station
5. Waits for approval and credit

## Key Features

### Rider Status Management
- **Available**: Rider is available for new deliveries
- **Busy**: Rider has an active delivery
- **Offline**: Rider is not available

### Delivery Status Flow
1. **Pending**: Delivery request created, waiting for rider
2. **Accepted**: Rider accepted the delivery
3. **Picked Up**: Rider picked up the items
4. **In Transit**: Rider is delivering
5. **Completed**: Delivery completed and confirmed

### Top-Up System
- Riders request top-up credits from their Loading Station
- Minimum top-up amount: ₱100
- Top-up requests are sent to Loading Station for approval
- Once approved, credits are added to rider's balance

## Database Schema

The app uses Supabase with the following main tables:
- `users` - User accounts
- `riders` - Rider information (status, balance, commission, vehicle)
- `deliveries` - Delivery orders (Pabili and Padala)
- `loading_stations` - Loading Station information
- `topups` - Top-up transactions
- `transaction_logs` - Transaction history

## Development

### Adding New Features
1. Create models in `lib/core/models/`
2. Create services in `lib/core/services/`
3. Create screens in `lib/screens/rider/`
4. Update providers if needed

### Testing
```bash
flutter test
```

### Building
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## Important Notes

1. **Rider-Only App**: This app is specifically for riders. Other roles (Customer, Merchant, Admin, Loading Station, Business Hub) should use their respective apps.

2. **LSCODE Required**: Riders must have a valid Loading Station Code (LSCODE) to register.

3. **Google Maps API Key**: You must provide a valid Google Maps API key in the Android manifest for map functionality.

4. **Location Permissions**: The app requires location permissions for Google Maps and delivery tracking.

5. **Supabase Configuration**: The Supabase credentials are already configured. Ensure your database has the correct schema.

## License

This project is private and proprietary.

## Support

For support, contact the development team.
