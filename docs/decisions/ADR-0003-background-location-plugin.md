# ADR-0003: Native background location approach
**Status:** Owner preference confirmed — Life360-style background tracking on Android/iOS, including with screen locked, subject to platform restrictions. Implementation/plugin remains open until a 1–2 week spike on real Android (including Samsung/Xiaomi) and iOS devices.
**Candidates:** geolocator + compliant Android foreground service/workmanager (free, more custom work; preferred under $0); flutter_background_geolocation (robust, but licence cost must be checked).
**Criteria:** reliability when screen locked and app backgrounded/killed, battery ≤5%/day target, store-policy compliance, licence cost, maintenance, persistent Android foreground notification. These are targets, not guarantees. Web tracking stops when the tab closes.
