# ADR-0003: Background location approach
**Status:** Open — decide after a 1–2 week spike on real Android (Samsung/Xiaomi) and iOS devices.
**Candidates:** `flutter_background_geolocation` (robust, paid licence for Android release), `geolocator` + foreground service/`workmanager` (free, more custom work).
**Criteria:** reliability when app killed, battery ≤5%/day, store-policy compliance, licence cost, maintenance.
