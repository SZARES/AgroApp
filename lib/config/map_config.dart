/// Satellite basemap tiles (Esri World Imagery); no API key needed.
const mapTileUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

/// Credit the tile provider requires on every map.
const mapTileAttribution = 'Esri, Maxar, Earthstar Geographics';

/// Sent with tile requests so the provider can identify the app.
const mapUserAgentPackageName = 'com.example.hackathon';

/// Closest zoom the imagery is requested at.
const mapMaxZoom = 18.0;
