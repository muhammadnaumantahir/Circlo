# ADR-0003: Background location approach
**Status:** Open — decide after a 1–2 week spike on real Android (Samsung/Xiaomi) and iOS devices.
**Candidates:** `flutter_background_geolocation` (robust, but a paid licence for Android release is likely outside the $0 budget — verify), `geolocator` + foreground service/`workmanager` (free, more custom work; preferred under $0 budget).
**Criteria:** reliability when app killed, battery ≤5%/day, store-policy compliance, licence cost, maintenance.
