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

// Bay Area counties list
const bayAreaCounties = [
  '001', '013', '041', '055', '075', '081', '085', '095', '097',
  'Alameda', 'Contra Costa', 'Marin', 'Napa', 'San Francisco',
  'San Mateo', 'Santa Clara', 'Solano', 'Sonoma'
];

// Global reference for census tract layer (for filtering)
let censustractLayerGroup = null;
let currentRegionFilter = 'california'; // 'california' or 'bayarea'
let bayAreaCountyLayer = null;
let otherCountyLayer = null;

//Always visible layer: CA Census Tract Borders
fetch('./data/CA_census_tracts.geojson')
  .then(res => {
    if (!res.ok) throw new Error(`Failed to load CA_census_tracts.geojson`);
    return res.json();
  })
  .then(data => {
    censustractLayerGroup = L.featureGroup();
    
    const censustractLayer = L.geoJSON(data, {
      pane: 'censustractPane',
      style: {
        color: "#8d8c8cff",
        weight: 1,
        fillOpacity: 0.01
      },
      onEachFeature: (feature, layer) => {
        // Store county info on layer
        const countyName = feature.properties.county_name || feature.properties.COUNTYFP || '';
        layer.countyName = countyName;
        console.log('Census tract loaded:', { geoid: feature.properties.GEOID, countyName, inBayArea: bayAreaCounties.includes(countyName) });
        layer.on('click', (e) => {
          L.DomEvent.stopPropagation(e);
          console.log('Census tract clicked:', feature.properties);
          displayCensusTractChart(feature.properties);
          sidebar.open('legend');
        });
      }
    });
    
    // Store layer reference and apply to map
    censustractLayerGroup.addLayer(censustractLayer);
    censustractLayerGroup.addTo(map);
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
      // Split features into Bay Area and others using global bayAreaCounties list
      const bayAreaFeatures = data.features.filter(feature => {
        const countyName = feature.properties.name || feature.properties.NAME || '';
        return bayAreaCounties.includes(countyName);
      });

      const otherFeatures = data.features.filter(feature => {
        const countyName = feature.properties.name || feature.properties.NAME || '';
        return !bayAreaCounties.includes(countyName);
      });

      // Add non-Bay Area counties first (black outline)
      otherCountyLayer = L.geoJSON({
        type: 'FeatureCollection',
        features: otherFeatures
      }, {
        pane: 'countyPane',
        interactive: false,
        style: {
          color: "#070707ff",
          weight: 2,
          fillOpacity: 0
        }
      });
      otherCountyLayer.addTo(map);

      // Add Bay Area counties on top (blue outline)
      bayAreaCountyLayer = L.geoJSON({
        type: 'FeatureCollection',
        features: bayAreaFeatures
      }, {
        pane: 'countyPane',
        interactive: false,
        style: {
          color: "#2563eb",
          weight: 3,
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

const bayAreaOverlayNames = [
  "Broadband Low-Fiber Deployment + Low Opportunity",
  "Broadband Fiber Spatial Clustering + Low Opportunity"
];

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

// Track active layer
let currentActiveLayer = null;

function applyOverlayRegionFilter(region) {
  const activeLayer = overlayLayers[currentActiveLayer];
  if (!activeLayer) return;
  if (!bayAreaOverlayNames.includes(currentActiveLayer)) return;

  const color = colorMap[currentActiveLayer] || "#984ea3";
  let visibleCount = 0;
  let hiddenCount = 0;

  activeLayer.eachLayer(featureLayer => {
    const props = featureLayer.feature?.properties || {};
    const countyName = props.county_name || props.NAME || props.Name || props.NAME_1 || '';
    // Extract county code: handle concatenated codes like '6077003406' (state+county+tract)
    const countyCodeFull = (props.COUNTYFP || props.FIPS || props.CountyId || '').toString();
    let countyCode;
    if (countyCodeFull.length > 5) {
      // Concatenated code: extract first 4 chars (state+county), then last 3 (county only)
      countyCode = countyCodeFull.slice(0, 4).slice(-3);
    } else if (countyCodeFull.length > 3) {
      countyCode = countyCodeFull.slice(-3);
    } else {
      countyCode = countyCodeFull.padStart(3, '0');
    }
    const isBayArea = bayAreaCounties.includes(countyName) || bayAreaCounties.includes(countyCode);

    if (visibleCount + hiddenCount < 5) {
      console.log(`Feature properties:`, { countyName, countyCode, countyCodeFull, isBayArea, allProps: Object.keys(props) });
    }

    if (region === 'bayarea') {
      if (isBayArea) {
        featureLayer.setStyle({ color, weight: 1, fillColor: color, fillOpacity: 0.4, opacity: 1 });
        featureLayer.options.interactive = true;
        visibleCount++;
      } else {
        featureLayer.setStyle({ fillOpacity: 0, opacity: 0 });
        featureLayer.options.interactive = false;
        hiddenCount++;
      }
    } else {
      featureLayer.setStyle({ color, weight: 1, fillColor: color, fillOpacity: 0.4, opacity: 1 });
      featureLayer.options.interactive = true;
      visibleCount++;
    }
  });

  console.log(`Overlay filter (${currentActiveLayer}): visible=${visibleCount}, hidden=${hiddenCount}`);
}

// Change Layer on Dropdown Selection
document.getElementById("layerDropdown").addEventListener("change", (e) => {
  const selected = e.target.value;
  const californiaBtn = document.getElementById('californiaBtn');
  
  // Check if selected layer is Bay Area only (disable California button for statewide layers)
  const isBayAreaOnly = bayAreaOverlayNames.includes(selected);
  californiaBtn.disabled = !isBayAreaOnly;
  californiaBtn.classList.toggle('disabled', !isBayAreaOnly);
  
  // Remove currently active layer if any
  if (currentActiveLayer && overlayLayers[currentActiveLayer]) {
    map.removeLayer(overlayLayers[currentActiveLayer]);
  }
  
  // Add new layer if selected
  if (selected && overlayLayers[selected]) {
    map.addLayer(overlayLayers[selected]);
    currentActiveLayer = selected;
    
    // If statewide layer selected, auto-activate Bay Area filter and zoom
    if (!isBayAreaOnly) {
      filterCensusTractsByRegion('bayarea');
    } else {
      // For Bay Area layers, reapply region filter to ensure proper zoom and filtering
      filterCensusTractsByRegion(currentRegionFilter);
    }
  } else {
    currentActiveLayer = null;
  }
});

// Store chart instance
let currentChart = null;

// Function to display census tract properties as a chart
function readPercent(val) {
  if (val === undefined || val === null || val === '') return null;
  const num = Number(val);
  return Number.isFinite(num) ? num : null;
}

function displayCensusTractChart(properties) {
  const chartContainer = document.getElementById('chartContainer');

  if (!properties) {
    chartContainer.innerHTML = '<p>No data available</p>';
    return;
  }

  // ---- Title ----
  const tractInfo = document.createElement('div');
  tractInfo.style.marginBottom = '16px';
  const countyName = properties.county_name || properties.county || 'Unknown';
  tractInfo.innerHTML = `<h3>Census Tract: ${properties.GEOID ?? 'Unknown'}</h3><p style="margin: 4px 0; font-size: 14px; font-weight: bold;">County: ${countyName}</p>`;
  

  chartContainer.innerHTML = '';
  chartContainer.appendChild(tractInfo);

  // ---- Read values (ONLY from CA_census_tracts.geojson) ----
  let under10  = readPercent(properties.pctHHS_under10mbps);
  let tenTo25  = readPercent(properties.pctHHs_10to25mbps);
  let fiber    = readPercent(properties.ResidentialPercentwFiber);

  // OPTIONAL: if values are decimals (0–1), convert to percent
  const isDecimal = v => v !== null && v <= 1;
  if ([under10, tenTo25, fiber].some(isDecimal)) {
    under10 = under10 !== null ? under10 * 100 : null;
    tenTo25 = tenTo25 !== null ? tenTo25 * 100 : null;
    fiber   = fiber   !== null ? fiber   * 100 : null;
  }

  // ---- If ALL missing ----
  if ([under10, tenTo25, fiber].every(v => v === null)) {
    chartContainer.innerHTML += '<p>No broadband data available for this tract</p>';
    return;
  }

  // ---- Canvas ----
  const canvas = document.createElement('canvas');
  canvas.id = 'tractChart';
  chartContainer.appendChild(canvas);

  if (currentChart) currentChart.destroy();

  // ---- Grouped bar chart ----
  // Small plugin to draw value labels above bars
  const dataLabelPlugin = {
    id: 'dataLabelPlugin',
    afterDatasetsDraw(chart) {
      const ctx = chart.ctx;
      chart.data.datasets.forEach((dataset, dsIndex) => {
        const meta = chart.getDatasetMeta(dsIndex);
        if (!meta || !meta.data) return;
        meta.data.forEach((element, index) => {
          const value = dataset.data[index];
          if (value === null || value === undefined) return;
          const label = (Number.isFinite(value) ? value.toFixed(1) : value) + '%';
          const position = element.getCenterPoint ? element.getCenterPoint() : { x: element.x, y: element.y };
          ctx.save();
          ctx.font = '12px Arial';
          ctx.fillStyle = '#000';
          ctx.textAlign = 'center';
          ctx.textBaseline = 'bottom';
          ctx.fillText(label, position.x, position.y - 6);
          ctx.restore();
        });
      });
    }
  };

  currentChart = new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels: ['Broadband Availability'],
      datasets: [
        {
          label: '< 10 Mbps',
          data: [under10],
          backgroundColor: '#e41a1c'
        },
        {
          label: '10–25 Mbps',
          data: [tenTo25],
          backgroundColor: '#377eb8'
        },
        {
          label: 'Fiber',
          data: [fiber],
          backgroundColor: '#4daf4a'
        }
      ]
    },
    plugins: [dataLabelPlugin],
    options: {
      responsive: true,
      scales: {
        y: {
          beginAtZero: true,
          max: 100,
          ticks: {
            callback: v => v + '%'
          },
          title: {
            display: true,
            text: 'Percent of Households'
          }
        }
      },
      plugins: {
        tooltip: {
          callbacks: {
            label: ctx =>
              ctx.raw === null
                ? `${ctx.dataset.label}: No data`
                : `${ctx.dataset.label}: ${ctx.raw.toFixed(1)}%`
          }
        }
      }
    }
  });
// ---- Category label below chart ----
const categoryValue = properties.Category ?? 'Unknown';

const categoryDiv = document.createElement('div');
categoryDiv.style.marginTop = '12px';
categoryDiv.style.fontWeight = 'bold';
categoryDiv.textContent = `Category: ${categoryValue}`;

chartContainer.appendChild(categoryDiv);

// ---- Total Households label ----
const totalHouseholds = properties.TotalHouseholdsinTracts ?? 'Unknown';
const householdsDiv = document.createElement('div');
householdsDiv.style.marginTop = '8px';
householdsDiv.style.fontWeight = 'bold';
householdsDiv.textContent = `Total Households: ${totalHouseholds}`;

chartContainer.appendChild(householdsDiv);

}

// Region filter button handlers
function filterCensusTractsByRegion(region) {
  if (!censustractLayerGroup) return;
  
  currentRegionFilter = region;
  
  // Update button active states
  document.getElementById('bayAreaBtn').classList.toggle('active', region === 'bayarea');
  document.getElementById('californiaBtn').classList.toggle('active', region === 'california');
  
  console.log('Filtering to region:', region);
  let bayAreaCount = 0;
  let otherCount = 0;
  
  // Show/hide county layers based on region
  if (region === 'bayarea') {
    if (otherCountyLayer) map.removeLayer(otherCountyLayer);
    // Zoom to Bay Area
    if (bayAreaCountyLayer) {
      map.fitBounds(bayAreaCountyLayer.getBounds());
    }
  } else {
    if (otherCountyLayer && !map.hasLayer(otherCountyLayer)) {
      otherCountyLayer.addTo(map);
    }
    // Zoom back to California
    map.setView([37.5, -119.5], 6);
  }
  
  // Toggle visibility of census tracts
  censustractLayerGroup.eachLayer(featureGroup => {
    featureGroup.eachLayer(layer => {
      const countyName = layer.countyName || '';
      const isBayArea = bayAreaCounties.includes(countyName);
      
      if (isBayArea) bayAreaCount++;
      else otherCount++;
      
      if (region === 'bayarea') {
        // Only show Bay Area tracts
        if (isBayArea) {
          layer.setStyle({ fillOpacity: 0.01, opacity: 1 });
          layer.options.interactive = true;
        } else {
          layer.setStyle({ fillOpacity: 0, opacity: 0 });
          layer.options.interactive = false;
        }
      } else {
        // Show all tracts
        layer.setStyle({ fillOpacity: 0.01, opacity: 1 });
        layer.options.interactive = true;
      }
    });
  });
  
  console.log('Bay Area tracts:', bayAreaCount, 'Other tracts:', otherCount);

  // Apply overlay filtering for specific layers
  applyOverlayRegionFilter(region);
}

// Attach button handlers
document.getElementById('bayAreaBtn')?.addEventListener('click', () => {
  filterCensusTractsByRegion('bayarea');
});

document.getElementById('californiaBtn')?.addEventListener('click', () => {
  filterCensusTractsByRegion('california');
});
