// Initialize map
const map = L.map('map').setView([37.5, -119.5], 6);

// Initialize sidebar
const sidebar = L.control.sidebar({
  autopan: true,
  container: 'sidebar',
  position: 'right'
}).addTo(map);

// Grey basemap
L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
  attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
  subdomains: 'abcd',
  maxZoom: 19
}).addTo(map);

//Sets orders the z-index of the census tract layer to be on top
map.createPane('censustractPane');
map.getPane('censustractPane').style.zIndex = 650;

map.createPane('countyPane');
map.getPane('countyPane').style.zIndex = 700;

//Always visible layer: CA Census Tract Borders
fetch('./data/CA_census_tracts.geojson')
  .then(res => {
    if (!res.ok) throw new Error(`Failed to load CA_census_tracts.geojson`);
    return res.json();
  })
  .then(data => {
    const censustractLayer = L.geoJSON(data, {
      pane: 'censustractPane',
      style: {
        color: "#8d8c8cff",
        weight: 1,
        fillOpacity: 0
      }
    });
    censustractLayer.addTo(map);
  })
  .catch(err => {
    console.error("Error loading CA_census_tracts.geojson:", err);
  });

  // Always visible layer: All CA Counties

  fetch('./data/CA_counties.geojson')
    .then(res => {
      if (!res.ok) throw new Error(`Failed to load CA_counties.geojson`);
      return res.json();
    })
    .then(data => {
      // Bay Area counties that should have blue outline
      const bayAreaCounties = [
        'Alameda',
        'Contra Costa',
        'Marin',
        'Napa',
        'San Francisco',
        'San Mateo',
        'Santa Clara',
        'Solano',
        'Sonoma'
      ];

      // Split features into Bay Area and others
      const bayAreaFeatures = data.features.filter(feature => {
        const countyName = feature.properties.name || feature.properties.NAME || '';
        return bayAreaCounties.includes(countyName);
      });

      const otherFeatures = data.features.filter(feature => {
        const countyName = feature.properties.name || feature.properties.NAME || '';
        return !bayAreaCounties.includes(countyName);
      });

      // Add non-Bay Area counties first (black outline)
      const otherCountyLayer = L.geoJSON({
        type: 'FeatureCollection',
        features: otherFeatures
      }, {
        pane: 'countyPane',
        style: {
          color: "#070707ff",
          weight: 2,
          fillOpacity: 0
        }
      });
      otherCountyLayer.addTo(map);

      // Add Bay Area counties on top (blue outline)
      const bayAreaCountyLayer = L.geoJSON({
        type: 'FeatureCollection',
        features: bayAreaFeatures
      }, {
        pane: 'countyPane',
        style: {
          color: "#2563eb",
          weight: 2,
          fillOpacity: 0
        }
      });
      bayAreaCountyLayer.addTo(map);
      bayAreaCountyLayer.bringToFront();
    })
    
    .catch(err => {
      console.error("Error loading CA_counties.geojson:", err);
    });

// Layers setup
const overlayLayers = {};
const geojsonFiles = {
  "Broadband Under 10 Mbps + Low Opportunity": "./data/BroadbandUnder10and_low_opportunity.geojson",
  "Broadband 10 Mbps to 25 Mbps + Low Opportunity": "./data/Broadband10to25_low_opportunity.geojson",
  "Broadband Low-Fiber Deployment + Low Opportunity": "./data/BroadbandLowFiberDeployand_low_opportunity.geojson",
  "Broadband Fiber Spatial Clustering + Low Opportunity": "./data/BroadbandLowFiber_ClusterAnalysis.geojson"
};

const colorMap = {
  "Broadband Under 10 Mbps + Low Opportunity": "#e41a1c",
  "Broadband 10 Mbps to 25 Mbps + Low Opportunity": "#377eb8",
  "Broadband Low-Fiber Deployment + Low Opportunity": "#4daf4a",
  "Broadband Fiber Spatial Clustering + Low Opportunity": "#984ea3"
};

const dropdown = document.getElementById("layerDropdown");

// Populate dropdown with all layers immediately
for (const layerName of Object.keys(geojsonFiles)) {
  const option = document.createElement("option");
  option.value = layerName;
  option.textContent = layerName + " (loading...)";
  dropdown.appendChild(option);
}

// Load GeoJSON
for (const [layerName, path] of Object.entries(geojsonFiles)) {
  fetch(path)
    .then(res => {
      if (!res.ok) throw new Error(`Failed to load ${path}`);
      return res.json();
    })
    .then(data => {
      const layerOptions = {
        onEachFeature: (feature, layer) => {
          const popup = Object.entries(feature.properties)
            .map(([k,v]) => `<strong>${k}</strong>: ${v}`)
            .join("<br>");
          layer.bindPopup(popup);
        }
      };

      if (layerName.includes('Clustering') || layerName.includes('Cluster')) {
        layerOptions.style = {
          color: "#984ea3",
          weight: 1,
          fillColor: "#984ea3",
          fillOpacity: 0.4
        };
      } else {
        layerOptions.style = {
          color: colorMap[layerName],
          weight: 1,
          fillColor: colorMap[layerName],
          fillOpacity: 0.4
        };
      }

      const layer = L.geoJSON(data, layerOptions);
      overlayLayers[layerName] = layer;

      // Update dropdown text to remove "loading..."
      const option = Array.from(dropdown.options).find(opt => opt.value === layerName);
      if (option) option.textContent = layerName;
    })
    .catch(err => {
      console.error("Error loading GeoJSON:", err);
      const option = Array.from(dropdown.options).find(opt => opt.value === layerName);
      if (option) option.textContent = layerName + " (failed)";
    });
}

// Track active layers
const activeLayers = new Set();

// Add Layer
document.getElementById("addLayerBtn").addEventListener("click", () => {
  const selected = dropdown.value;
  if (selected && overlayLayers[selected] && !activeLayers.has(selected)) {
    map.addLayer(overlayLayers[selected]);
    map.fitBounds(overlayLayers[selected].getBounds());
    activeLayers.add(selected);
  }
});

// Remove Layer
document.getElementById("removeLayerBtn").addEventListener("click", () => {
  const selected = dropdown.value;
  if (selected && overlayLayers[selected] && activeLayers.has(selected)) {
    map.removeLayer(overlayLayers[selected]);
    activeLayers.delete(selected);
  }
});
