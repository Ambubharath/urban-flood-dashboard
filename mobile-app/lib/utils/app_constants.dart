class AppConstants {
  static const appName = 'FloodWatchApp';
  static const mapAttribution = '© OpenStreetMap contributors';

  // ── Google Maps API key ──────────────────────────────────────────────────
  // Replace with your own key from https://console.cloud.google.com/
  // Enable: Maps SDK for Android, Maps SDK for iOS, Directions API
  static const googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  // Routing: hazard reports older than this are ignored
  static const hazardWindowHours = 12;

  // Routing: points within this radius of a hazard are considered dangerous
  static const hazardRadiusMetres = 300.0;
}
