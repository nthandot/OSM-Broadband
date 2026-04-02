// Initialize map
const map = L.map('map').setView([37.5, -119.5], 6);

// Store initial view for home button
const initialView = { center: [37.5, -119.5], zoom: 6 };

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

// Add Home button control
L.Control.Home = L.Control.extend({
  options: {
    position: 'topleft'
  },
  onAdd: function(map) {
    const container = L.DomUtil.create('div', 'leaflet-bar leaflet-control');
    const homeBtn = L.DomUtil.create('a', 'leaflet-control-home', container);
    homeBtn.href = '#';
    homeBtn.title = 'Reset to initial view';
    homeBtn.innerHTML =
      '<svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' +
      '<path fill="#000" d="M12 3l9 8h-3v9h-5v-6H11v6H6v-9H3z"/>' +
      '</svg>';
    homeBtn.style.width = '30px';
    homeBtn.style.height = '30px';
    homeBtn.style.lineHeight = '30px';
    homeBtn.style.textAlign = 'center';
    homeBtn.style.fontSize = '20px';
    homeBtn.style.color = '#000';
    
    L.DomEvent.on(homeBtn, 'click', L.DomEvent.preventDefault);
    L.DomEvent.on(homeBtn, 'click', () => {
      map.setView(initialView.center, initialView.zoom);
    });
    
    return container;
  }
});

L.control.home = function(opts) {
  return new L.Control.Home(opts);
};

L.control.home().addTo(map);

map.createPane('countyPane');
map.getPane('countyPane').style.zIndex = 800;

// Pane for scenario overlays so their strokes sit above counties
map.createPane('scenarioPane');
map.getPane('scenarioPane').style.zIndex = 750;

// Bay Area counties list
const bayAreaCounties = [
  '001', '013', '041', '055', '075', '081', '085', '095', '097',
  'Alameda', 'Contra Costa', 'Marin', 'Napa', 'San Francisco',
  'San Mateo', 'Santa Clara', 'Solano', 'Sonoma'
];

// Global reference data for block group lookups
const blockGroupRacePropsByGEOID = {}; // cache of block-group race/ethnicity attributes from AllBroadband dataset
const countyNameByCode = {}; // lookup from CA_counties.geojson COUNTYFP -> NAME
let currentRegionFilter = 'california'; // 'california' or 'bayarea'
let bayAreaCountyLayer = null;
let otherCountyLayer = null;
let allBroadbandBlockGroupPromise = null;
let allBroadbandBlockGroupLoaded = false;

function extractCountyCode(properties = {}) {
  const countyFp = String(properties.COUNTYFP || '').trim();
  if (/^\d{3}$/.test(countyFp)) return countyFp;

  const raw = String(properties.COUNTYFYP || properties.CountyId || properties.CountyId_1 || properties.FIPS || '').replace(/\D/g, '');
  if (!raw) return '';

  if (raw.startsWith('06') && raw.length >= 5) return raw.slice(2, 5);
  if (raw.startsWith('6') && raw.length >= 4) return raw.slice(1, 4);

  return raw.slice(-3).padStart(3, '0');
}

  // Always visible layer: All CA Counties

  fetch('./data/CA_counties.geojson')
    .then(res => {
      if (!res.ok) throw new Error(`Failed to load CA_counties.geojson`);
      return res.json();
    })
    .then(data => {
      data.features.forEach(feature => {
        const props = feature.properties || {};
        const countyCode = extractCountyCode(props);
        const countyName = (props.NAME || '').toString().trim();
        if (countyCode && countyName) {
          countyNameByCode[countyCode] = countyName;
        }
      });

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
const layerLoadPromises = {};

const scenarioConfig = {
  "Broadband Under 10 Mbps + Low Opportunity": {
    blockGroupPath: "./data/BroadbandUnder10_BlockGroup.geojson",
    color: "#e41a1c"
  },
  "Broadband 10 Mbps to 25 Mbps + Low Opportunity": {
    blockGroupPath: "./data/Broadband10to25_BlockGroup.geojson",
    color: "#377eb8"
  },
  "Broadband Low-Fiber Deployment + Low Opportunity": {
    blockGroupPath: "./data/BroadbandLowFiber_BlockGroup.geojson",
    color: "#4daf4a"
  },
  "Broadband Fiber Spatial Clustering + Low Opportunity": {
    blockGroupPath: "./data/BroadbandLowFiber_ClusterAnalysisBlockGroupData.geojson",
    color: "#984ea3"
  }
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

function normalizeBlockGroupGeoId(value) {
  if (value === undefined || value === null || value === '') return '';
  const raw = String(value).trim();
  if (!raw) return '';
  if (/^\d+$/.test(raw) && raw.length === 11) return `0${raw}`;
  return raw;
}

function indexAllBroadbandBlockGroupProps(props) {
  if (!props) return;
  const keys = [props.GEOID, props.geoid, props.block_group, props.GEOID_1]
    .map(normalizeBlockGroupGeoId)
    .filter(Boolean);

  keys.forEach(key => {
    if (!blockGroupRacePropsByGEOID[key]) {
      blockGroupRacePropsByGEOID[key] = props;
    }
  });
}

function ensureAllBroadbandBlockGroupData() {
  if (allBroadbandBlockGroupLoaded) return Promise.resolve();
  if (allBroadbandBlockGroupPromise) return allBroadbandBlockGroupPromise;

  allBroadbandBlockGroupPromise = fetch('./data/AllBroadband_blockGroupData.geojson')
    .then(res => {
      if (!res.ok) throw new Error('Failed to load AllBroadband_blockGroupData.geojson');
      return res.json();
    })
    .then(data => {
      const features = Array.isArray(data?.features) ? data.features : [];
      features.forEach(feature => {
        indexAllBroadbandBlockGroupProps(feature?.properties);
      });
      allBroadbandBlockGroupLoaded = true;
    })
    .catch(err => {
      console.error('Error loading AllBroadband_blockGroupData.geojson:', err);
      throw err;
    });

  return allBroadbandBlockGroupPromise;
}

function getBlockGroupChartProperties(properties) {
  if (!properties) return Promise.resolve(properties);

  const mergeProps = () => {
    const keys = [properties.GEOID, properties.geoid, properties.block_group, properties.GEOID_1]
      .map(normalizeBlockGroupGeoId)
      .filter(Boolean);

    for (const key of keys) {
      const sourceProps = blockGroupRacePropsByGEOID[key];
      if (sourceProps) {
        return { ...properties, ...sourceProps };
      }
    }

    return properties;
  };

  if (allBroadbandBlockGroupLoaded) {
    return Promise.resolve(mergeProps());
  }

  return ensureAllBroadbandBlockGroupData()
    .then(() => mergeProps())
    .catch(() => properties);
}

const dropdown = document.getElementById("layerDropdown");

// Populate dropdown with scenarios immediately
for (const layerName of Object.keys(scenarioConfig)) {
  const option = document.createElement("option");
  option.value = layerName;
  option.textContent = layerName;
  dropdown.appendChild(option);
}

function ensureScenarioLayer(layerName) {
  if (overlayLayers[layerName]) {
    return Promise.resolve(overlayLayers[layerName]);
  }
  if (layerLoadPromises[layerName]) {
    return layerLoadPromises[layerName];
  }

  const config = scenarioConfig[layerName];
  const path = config.blockGroupPath;

  layerLoadPromises[layerName] = fetch(path)
    .then(res => {
      if (!res.ok) throw new Error(`Failed to load ${path}`);
      return res.json();
    })
    .then(data => {
      const layerOptions = {
        pane: 'scenarioPane',
        onEachFeature: (feature, layer) => {
          // On click, show the bar chart in the sidebar instead of a popup
          layer.on('click', (e) => {
            L.DomEvent.stopPropagation(e);
            getBlockGroupChartProperties(feature.properties).then(chartProps => {
              displayBlockGroupRaceBars(chartProps);
            });
            sidebar.open('legend');
          });
        }
      };

      const color = colorMap[layerName] || config.color || "#984ea3";
      layerOptions.style = {
        color,
        weight: 1,
        fillColor: color,
        fillOpacity: 0.4
      };

      const layer = L.geoJSON(data, layerOptions);
      overlayLayers[layerName] = layer;

      return layer;
    })
    .catch(err => {
      console.error("Error loading GeoJSON:", err);
      throw err;
    });

  return layerLoadPromises[layerName];
}

ensureAllBroadbandBlockGroupData().catch(() => {});

// Track active layer
let currentActiveLayer = null;

function applyOverlayRegionFilter(region) {
  const activeLayer = overlayLayers[currentActiveLayer];
  if (!activeLayer) return;
  if (!bayAreaOverlayNames.includes(currentActiveLayer)) return;

  const color = colorMap[currentActiveLayer] || "#984ea3";

  activeLayer.eachLayer(featureLayer => {
    const props = featureLayer.feature?.properties || {};
    const countyCode = extractCountyCode(props);
    const resolvedCountyName = countyNameByCode[countyCode] || props.county || props.county_name || props.Name || props.NAME_1 || '';
    const isBayArea = bayAreaCounties.includes(resolvedCountyName) || bayAreaCounties.includes(countyCode);

    if (region === 'bayarea') {
      if (isBayArea) {
        featureLayer.setStyle({ color, weight: 1, fillColor: color, fillOpacity: 0.4, opacity: 1 });
        featureLayer.options.interactive = true;
      } else {
        featureLayer.setStyle({ fillOpacity: 0, opacity: 0 });
        featureLayer.options.interactive = false;
      }
    } else {
      featureLayer.setStyle({ color, weight: 1, fillColor: color, fillOpacity: 0.4, opacity: 1 });
      featureLayer.options.interactive = true;
    }
  });

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
  if (currentActiveLayer) {
    const activeLayer = overlayLayers[currentActiveLayer];
    if (activeLayer && map.hasLayer(activeLayer)) {
      map.removeLayer(activeLayer);
    }
  }
  
  // Add new layer if selected
  if (selected) {
    currentActiveLayer = selected;
    ensureScenarioLayer(selected).then(layer => {
      if (currentActiveLayer !== selected) return;
      if (!map.hasLayer(layer)) map.addLayer(layer);

      // Keep county outlines above overlays
      if (otherCountyLayer) otherCountyLayer.bringToFront();
      if (bayAreaCountyLayer) bayAreaCountyLayer.bringToFront();
      
      // If statewide layer selected, auto-activate Bay Area filter and zoom
      if (!isBayAreaOnly) {
        filterByRegion('bayarea');
      } else {
        // For Bay Area layers, always zoom to Bay Area and apply Bay Area filter
        filterByRegion('bayarea');
      }
    });
  } else {
    currentActiveLayer = null;
  }
});

// Legend title button click handlers
document.querySelectorAll('.legend-title-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const layerName = btn.getAttribute('data-layer');
    const dropdown = document.getElementById('layerDropdown');
    dropdown.value = layerName;
    dropdown.dispatchEvent(new Event('change'));
  });
});

// Store chart instance
let currentChart = null;

// Shared numeric parser
function readPercent(val) {
  if (val === undefined || val === null || val === '') return null;
  const num = Number(val);
  return Number.isFinite(num) ? num : null;
}

function displayBlockGroupRaceBars(properties) {
  const chartContainer = document.getElementById('chartContainer');

  if (!properties) {
    chartContainer.innerHTML = '<p>No data available</p>';
    return;
  }

  const toPct = (val) => {
    const num = readPercent(val);
    if (num === null) return null;
    return num <= 1 ? num * 100 : num;
  };

  const readPct = (keyList) => {
    for (const key of keyList) {
      const num = toPct(properties[key]);
      if (num !== null) return num;
    }
    return null;
  };

  const clampPct = (val) => {
    if (!Number.isFinite(val)) return null;
    return Math.max(0, Math.min(100, val));
  };

  const under10 = clampPct(readPct([
    'PercentHH_under10', 'percentHH_under10', 'PercentHH_under_10',
    'pctHHS_under10mbps', 'PercentHH_under10', 'pct_hhs_under10mbps', 'PctHHs_Under10'
  ]));
  const tenTo25 = clampPct(readPct([
    'PercentHH_10_25', 'PercentHH10to25', 'PercentHH_10to25',
    'pctHHs_10to25mbps'
  ]));
  const fiber = clampPct(readPct([
    'PercentHH_fiber', 'PercentHH_Fiber', 'ResidentialPercentwFiber',
    'Residential_Pct_Fiber', 'TotalPercentwFiber'
  ]));

  const rows = [
    {
      label: 'Black',
      value: clampPct(toPct(properties.black_pct ?? properties.black_percent ?? properties.pct_black ?? properties.black))
    },
    {
      label: 'White',
      value: clampPct(toPct(properties.white_pct ?? properties.white_percent ?? properties.pct_white ?? properties.white))
    },
    {
      label: 'Hispanic',
      value: clampPct(toPct(properties.hispanic_pct ?? properties.hispanic_percent ?? properties.pct_hispanic ?? properties.hispanic))
    }
  ];

  const countyCode = extractCountyCode(properties);
  const countyNameFromCA = countyCode ? countyNameByCode[countyCode] : '';
  const countyName = countyNameFromCA || properties.county_name || properties.county || properties.NAME || properties.Name || properties.NAME_1 || 'Unknown';
  const blockGroupId = properties.block_group || properties.GEOID || properties.geoid || 'Unknown';

  chartContainer.innerHTML = `
    <div class="race-header">
      <h3>Block Group: ${blockGroupId}</h3>
      <p class="race-subtitle">County: ${countyName}</p>
    </div>
  `;

  if (currentChart) {
    currentChart.destroy();
    currentChart = null;
  }

  const hasBroadband = [under10, tenTo25, fiber].some(value => value !== null);
  if (hasBroadband) {
    const canvas = document.createElement('canvas');
    canvas.id = 'blockGroupChart';
    canvas.style.height = '300px';
    canvas.style.maxHeight = '300px';
    canvas.style.marginBottom = '14px';
    chartContainer.appendChild(canvas);

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
            const label = `${value.toFixed(1)}%`;
            const position = element.getCenterPoint ? element.getCenterPoint() : { x: element.x, y: element.y };
            ctx.save();
            ctx.font = '16px Arial';
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
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            ticks: {
              callback: v => v + '%',
              font: { size: 16 }
            },
            title: {
              display: true,
              text: 'Percent of Households',
              font: { size: 16 }
            }
          }
        },
        plugins: {
          title: {
            display: true,
            fullSize: true,
            text: ['Percent of Households Per Block Group', 'By Download Speeds And Fiber Access'],
            font: { size: 20 }
          },
          tooltip: {
            callbacks: {
              label: ctx =>
                ctx.raw === null || !Number.isFinite(ctx.raw)
                  ? `${ctx.dataset.label}: No data`
                  : `${ctx.dataset.label}: ${ctx.raw.toFixed(1)}%`
            }
          },
          legend: {
            labels: {
              font: { size: 16 }
            }
          }
        }
      }
    });
  } else {
    chartContainer.insertAdjacentHTML('beforeend', '<p>No broadband household percentage data available for this block group</p>');
  }

  const hasAnyRace = rows.some(row => row.value !== null);
  if (!hasAnyRace) {
    chartContainer.insertAdjacentHTML('beforeend', '<p>No race/ethnicity data available for this block group</p>');
    return;
  }

  chartContainer.insertAdjacentHTML('beforeend', `
    <table class="race-table" aria-label="Race and ethnicity percentages">
      <thead>
        <tr>
          <th>Group</th>
          <th>Percent</th>
          <th>Value</th>
        </tr>
      </thead>
      <tbody>
        ${rows.map(row => {
          const value = row.value;
          const safeValue = value === null ? 0 : Math.max(0, Math.min(100, value));
          const label = value === null ? 'No data' : `${safeValue.toFixed(1)}%`;
          return `
            <tr>
              <td class="race-label">${row.label}</td>
              <td class="race-bar-cell">
                <div class="race-bar-wrap" role="presentation">
                  <div class="race-bar" style="width: ${safeValue}%;"></div>
                </div>
              </td>
              <td class="race-value">${label}</td>
            </tr>
          `;
        }).join('')}
      </tbody>
    </table>
  `);
}

// Region filter button handlers
function filterByRegion(region) {
  currentRegionFilter = region;
  
  // Update button active states
  document.getElementById('bayAreaBtn').classList.toggle('active', region === 'bayarea');
  document.getElementById('californiaBtn').classList.toggle('active', region === 'california');
  
  console.log('Filtering to region:', region);
  
  // Show/hide county layers based on region
  if (region === 'bayarea') {
    if (otherCountyLayer) map.removeLayer(otherCountyLayer);
    if (bayAreaCountyLayer) {
      map.fitBounds(bayAreaCountyLayer.getBounds());
      bayAreaCountyLayer.bringToFront();
    }
  } else {
    if (otherCountyLayer && !map.hasLayer(otherCountyLayer)) {
      otherCountyLayer.addTo(map);
    }
    if (bayAreaCountyLayer) {
      bayAreaCountyLayer.bringToFront();
    }
    map.setView([37.5, -119.5], 6);
  }

  applyOverlayRegionFilter(region);
}

// Attach button handlers
document.getElementById('bayAreaBtn')?.addEventListener('click', () => {
  filterByRegion('bayarea');
});

document.getElementById('californiaBtn')?.addEventListener('click', () => {
  filterByRegion('california');
});
