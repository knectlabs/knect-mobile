import 'dart:math';

/// Great-circle distance in meters (haversine), matching the API's check.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371008.8;
  double rad(double degrees) => degrees * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * earthRadius * asin(min(1, sqrt(a)));
}

/// "35 m" or "7.6 km".
String formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';
