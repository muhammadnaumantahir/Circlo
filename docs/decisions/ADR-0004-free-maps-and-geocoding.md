# ADR-0004: Free map tiles, geocoding and directions
**Status:** Open — decide in a spike.
**Context:** Google Maps Platform requires a billing account (not allowed at $0). 
**Candidate approach:** `flutter_map` with an OSM-based tile source whose free-tier terms allow app use (the public OSM tile server has a usage policy that discourages app-scale use — verify), a free geocoder with rate limiting/caching, and directions by opening the device/web maps app by URL.
**Criteria:** licence/terms for a public app incl. attribution, rate limits, web+mobile support, reliability. If no free provider fits, options are: self-cached tiles for small regions, or reduce place search to "drop a pin" only.
