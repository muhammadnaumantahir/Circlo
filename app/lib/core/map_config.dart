/// Map tile source. The default is the public OpenStreetMap tile server, which is meant for
/// light/development use only (see ADR-0004). Before a public release, set MAP_TILE_URL to a
/// provider whose free-tier terms allow this app, and keep its attribution.
const String kMapTileUrl = String.fromEnvironment(
  'MAP_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);
const String kMapAttribution = String.fromEnvironment(
  'MAP_ATTRIBUTION',
  defaultValue: '© OpenStreetMap contributors',
);
