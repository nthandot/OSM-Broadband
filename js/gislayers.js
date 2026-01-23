// Initialize map
const map = L.map('map').setView([37.5, -119.5], 6);

// Initialize sidebar
const sidebar = L.control.sidebar({
  autopan: true,
  container: 'sidebar',
  position: 'right'
}).addTo(map);

// Open sidebar on page load
sidebar.open('layers');

// Welcome Modal Handler
document.addEventListener('DOMContentLoaded', () => {
  const modal = document.getElementById('welcomeModal');
  const beginBtn = document.getElementById('beginBtn');
  const closeBtn = document.getElementById('closeModalBtn');

  // Close modal when Begin button is clicked
  beginBtn.addEventListener('click', () => {
    modal.classList.add('hidden');
  });

  // Close modal when X button is clicked
  closeBtn.addEventListener('click', () => {
    modal.classList.add('hidden');
  });
});

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
map.getPane('countyPane').style.zIndex = 800;

// Pane for scenario overlays so their strokes sit above base tracts/counties
map.createPane('scenarioPane');
map.getPane('scenarioPane').style.zIndex = 750;

// Bay Area counties list
const bayAreaCounties = [
  '001', '013', '041', '055', '075', '081', '085', '095', '097',
  'Alameda', 'Contra Costa', 'Marin', 'Napa', 'San Francisco',
  'San Mateo', 'Santa Clara', 'Solano', 'Sonoma'
];

// Global reference for census tract layer (for filtering)
const tractPropsByGEOID = {}; // cache of base tract attributes for lookup when clicking overlays
const broadbandMetricsByGEOID = {}; // cache of broadband percentages across overlays
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
        color: "lightgray",
        weight: 0.5,
        fillOpacity: 0.01
      },
      onEachFeature: (feature, layer) => {
        // Store county info on layer
        const countyName = feature.properties.county || feature.properties.county_name || '';
        const geoid = feature.properties.GEOID || feature.properties.geoid || feature.properties.GEOID10 || '';
        if (geoid) {
          tractPropsByGEOID[geoid.toString()] = feature.properties;
        }
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
          color: "#8d8c8cff",
          weight: 1,
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
          color: "#070707ff",
          weight: 1.5,
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

// Cache broadband metrics per GEOID so the chart can show all three bars regardless of which overlay was clicked
function cacheBroadbandMetrics(layerName, props) {
  const geoid = props.GEOID || props.geoid || props.GEOID10 || props.census_tract || props.FIPS || '';
  if (!geoid) return;
  const key = geoid.toString();
  const entry = broadbandMetricsByGEOID[key] || {};

  const setMetric = (field, value) => {
    if (value !== null && value !== undefined) {
      const num = readPercent(value);
      if (num !== null) entry[field] = num;
    }
  };

  if (layerName === "Broadband Under 10 Mbps + Low Opportunity") {
    setMetric('under10', props.pctHHS_under10mbps ?? props.PercentHH_under10 ?? props.pct_hhs_under10mbps ?? props.PctHHs_Under10);
  } else if (layerName === "Broadband 10 Mbps to 25 Mbps + Low Opportunity") {
    setMetric('tenTo25', props.pctHHs_10to25mbps ?? props.PercentHH10to25 ?? props.PercentHH_10to25);
  } else if (layerName === "Broadband Low-Fiber Deployment + Low Opportunity" || layerName === "Broadband Fiber Spatial Clustering + Low Opportunity") {
    setMetric('fiber', props.ResidentialPercentwFiber ?? props.Residential_Pct_Fiber ?? props.TotalPercentwFiber);
  }

  broadbandMetricsByGEOID[key] = entry;
}

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
        pane: 'scenarioPane',
        onEachFeature: (feature, layer) => {
          cacheBroadbandMetrics(layerName, feature.properties);
          // On click, show the bar chart in the sidebar instead of a popup
          layer.on('click', (e) => {
            L.DomEvent.stopPropagation(e);
            displayCensusTractChart(feature.properties);
            sidebar.open('legend');
          });
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
    const countyName = props.county || props.county_name || props.NAME || props.Name || props.NAME_1 || '';
    // Extract county code: handle concatenated codes like '6077003406' (state+county+tract)
    const countyCodeFull = (props.COUNTYFYP || props.COUNTYFP || props.FIPS || props.CountyId || '').toString();
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

    // Keep county outlines above tracts/overlays
    if (otherCountyLayer) otherCountyLayer.bringToFront();
    if (bayAreaCountyLayer) bayAreaCountyLayer.bringToFront();
    
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

  // Merge in base tract attributes (from statewide layer) so all three metrics are available regardless of which overlay was clicked
  const geoidKey = (properties.GEOID || properties.geoid || properties.GEOID10 || '').toString();
  const baseProps = geoidKey && tractPropsByGEOID[geoidKey] ? tractPropsByGEOID[geoidKey] : null;
  const mergedProps = baseProps ? { ...baseProps, ...properties } : properties;
  const cachedMetrics = geoidKey && broadbandMetricsByGEOID[geoidKey] ? broadbandMetricsByGEOID[geoidKey] : {};

  // ---- Title ----
  const tractInfo = document.createElement('div');
  tractInfo.style.marginBottom = '16px';
  const countyName = mergedProps.county_name || mergedProps.county || 'Unknown';
  tractInfo.innerHTML = `<h3>Census Tract: ${mergedProps.GEOID ?? mergedProps.geoid ?? 'Unknown'}</h3><p style="margin: 4px 0; font-size: 14px; font-weight: bold;">County: ${countyName}</p>`;
  

  chartContainer.innerHTML = '';
  chartContainer.appendChild(tractInfo);

  // ---- Read values: always show the three broadband percentages when present ----
  const activeLayerName = currentActiveLayer;
  const readPct = (keyList) => {
    for (const k of keyList) {
      const v = mergedProps[k];
      const num = readPercent(v);
      if (num !== null) return num;
    }
    return null;
  };

  // Prioritize fields relevant to the selected scenario, then fall back to any known aliases
  const uniq = (arr) => Array.from(new Set(arr));
  const under10Keys = uniq([
    ...(activeLayerName === "Broadband Under 10 Mbps + Low Opportunity" ? ["pctHHS_under10mbps", "PercentHH_under10", "pct_hhs_under10mbps"] : []),
    "pctHHS_under10mbps", "PercentHH_under10", "pct_hhs_under10mbps", "PctHHs_Under10"
  ]);
  const tenTo25Keys = uniq([
    ...(activeLayerName === "Broadband 10 Mbps to 25 Mbps + Low Opportunity" ? ["pctHHs_10to25mbps", "PercentHH10to25", "PercentHH_10to25"] : []),
    "pctHHs_10to25mbps", "PercentHH10to25", "PercentHH_10to25"
  ]);
  const fiberKeys = uniq([
    ...(activeLayerName === "Broadband Low-Fiber Deployment + Low Opportunity" ? ["ResidentialPercentwFiber", "Residential_Pct_Fiber", "TotalPercentwFiber"] : []),
    "ResidentialPercentwFiber", "Residential_Pct_Fiber", "TotalPercentwFiber"
  ]);

  let under10 = readPct(under10Keys);
  let tenTo25 = readPct(tenTo25Keys);
  let fiber   = readPct(fiberKeys);

  if (under10 === null && cachedMetrics.under10 !== undefined) under10 = cachedMetrics.under10;
  if (tenTo25 === null && cachedMetrics.tenTo25 !== undefined) tenTo25 = cachedMetrics.tenTo25;
  if (fiber === null && cachedMetrics.fiber !== undefined) fiber = cachedMetrics.fiber;

  // OPTIONAL: if values are decimals (0–1), convert to percent
  const isDecimal = v => v !== null && v <= 1;
  if ([under10, tenTo25, fiber].some(isDecimal)) {
    under10 = under10 !== null ? under10 * 100 : null;
    tenTo25 = tenTo25 !== null ? tenTo25 * 100 : null;
    fiber   = fiber   !== null ? fiber   * 100 : null;
  }

  // Clean non-finite values to avoid NaN in chart
  const clean = v => (Number.isFinite(v) ? v : null);
  under10 = clean(under10);
  tenTo25 = clean(tenTo25);
  fiber   = clean(fiber);

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
          if (value === null || value === undefined || !Number.isFinite(value)) return;
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
        title: {
          display: true,
          text: 'Percent of Households per Tract by Download Speeds and Fiber Access'
        },
        tooltip: {
          callbacks: {
            label: ctx =>
              ctx.raw === null || !Number.isFinite(ctx.raw)
                ? `${ctx.dataset.label}: No data`
                : `${ctx.dataset.label}: ${ctx.raw.toFixed(1)}%`
          }
        }
      }
    }
  });
// ---- Category label below chart ----
const categoryValue = mergedProps.Category ?? 'Unknown';

const categoryDiv = document.createElement('div');
categoryDiv.style.marginTop = '12px';
categoryDiv.style.fontWeight = 'bold';
categoryDiv.textContent = `Category: ${categoryValue}`;

chartContainer.appendChild(categoryDiv);

// ---- Total Households label ----
const totalHouseholds = mergedProps.TotalHouseholdsinTracts ?? mergedProps.TotalHouseholds ?? mergedProps.value ?? 'Unknown';
const householdsDiv = document.createElement('div');
householdsDiv.style.marginTop = '8px';
householdsDiv.style.fontWeight = 'bold';
householdsDiv.textContent = `Total Households: ${totalHouseholds}`;

chartContainer.appendChild(householdsDiv);

// ---- Footnote below chart ----
const noteDiv = document.createElement('div');
noteDiv.style.marginTop = '10px';
noteDiv.style.fontSize = '12px';
noteDiv.style.lineHeight = '1.4';
noteDiv.textContent = 'Percents are calculated by the number of households with access to the stated speeds. They do not total 100% because the remaining households could be served by other broadband connections such as wireless or satellite not modeled here.';
chartContainer.appendChild(noteDiv);

// ---- Additional explanation ----
const noteDiv2 = document.createElement('div');
noteDiv2.style.marginTop = '10px';
noteDiv2.style.fontSize = '12px';
noteDiv2.style.lineHeight = '1.4';
noteDiv2.textContent = 'Zero percent of households in a tract means that there are no households in the tract that are serviced by copper (10), cable (40), or Fiber (50), with a max download speed of less than 10 Mbps. This means that households could have access to other broadband services, such as wireless or satellite, which may or may not fall under the 10 Mbps threshold. Additionally, some census blocks are serviced by one of the three broadband codes noted above and have download speeds under 10 Mbps, but because the census block contains no households, when summed to the tract level, the analysis shows that 0% of households fall under the 10 Mbps threshold. ';
chartContainer.appendChild(noteDiv2);

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
      bayAreaCountyLayer.bringToFront();
    }
  } else {
    if (otherCountyLayer && !map.hasLayer(otherCountyLayer)) {
      otherCountyLayer.addTo(map);
    }
    // Ensure Bay Area counties stay on top
    if (bayAreaCountyLayer) {
      bayAreaCountyLayer.bringToFront();
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
