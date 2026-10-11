/// Google satellite basemap tiles (no Maps SDK key required for tile URLs).
const mapTileUrl =
    'https://mt{s}.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';

/// Google tile host shards.
const mapTileSubdomains = ['0', '1', '2', '3'];

/// Credit shown on every map.
const mapTileAttribution = 'Google';

/// Sent with tile requests so the provider can identify the app.
const mapUserAgentPackageName = 'com.example.hackathon';

/// Closest zoom the imagery is requested at.
const mapMaxZoom = 20.0;

/// Piura city centre — default when the farmer has not picked a point yet.
const mapDefaultLatitude = -5.19449;
const mapDefaultLongitude = -80.63282;
