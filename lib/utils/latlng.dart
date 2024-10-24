import 'dart:math';

double addMetersToLongitude(double longitude, double meters) {
  const double earthRadius = 6378137; // Radius of the Earth in meters
  return longitude + (meters / earthRadius) * (180 / pi);
}
