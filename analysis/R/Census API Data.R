# Census API Pulls
#census_api_key("356cc07a59d8c77671c672771e51a7b8a64b4954",install=TRUE)

#Pulls 2021 CA household counts by census block
CnsBlkHousehold <- get_decennial(
  geography = "block",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
CnsBlkHousehold <- CnsBlkHousehold %>%
  select(GEOID, NAME, variable, value) %>%
  tidyr::pivot_wider(names_from = variable, values_from = value)
write.csv(CnsBlkHousehold,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/CensusBlock2020households.csv", row.names=FALSE)

#Pulls 2021 CA household counts by census block group
CnsBlkGroupHousehold <- get_decennial(
  geography = "block group",
  variables = c(
    households = "H1_001N", #total number of households,
    total_pop = "P1_001N",
    white = "P1_003N",
    black = "P1_004N",
    asian = "P1_006N",
    american_indian_alaska_native = "P1_005N",
    hawaian_pacific_island = "P1_007N",
    hispanic = "P2_002N"
  ),
  state ="CA",
  sumfile= 'pl',
  year = 2020,
)
CnsBlkGroupHousehold <- CnsBlkGroupHousehold %>%
  select(GEOID, NAME, variable, value) %>%
  tidyr::pivot_wider(names_from = variable, values_from = value)

write.csv(CnsBlkGroupHousehold ,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/CensusBlockGroup2020households.csv", row.names=FALSE)

#Pulls 2021 CA household counts by census block
CnsTctHousehold <- get_decennial(
  geography = "tract",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
CnsTctHousehold <- CnsTctHousehold %>%
  select(GEOID, NAME, variable, value) %>%
  tidyr::pivot_wider(names_from = variable, values_from = value)
write.csv(CnsTctHousehold,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/CensusTract2020households.csv", row.names=FALSE)

ca_counties <- data.frame(
  county = c("Alameda","Alpine","Amador","Butte","Calaveras","Colusa","Contra Costa",
             "Del Norte","El Dorado","Fresno","Glenn","Humboldt","Imperial","Inyo",
             "Kern","Kings","Lake","Lassen","Los Angeles","Madera","Marin","Mariposa",
             "Mendocino","Merced","Modoc","Mono","Monterey","Napa","Nevada","Orange",
             "Placer","Plumas","Riverside","Sacramento","San Benito","San Bernardino",
             "San Diego","San Francisco","San Joaquin","San Luis Obispo","San Mateo",
             "Santa Barbara","Santa Clara","Santa Cruz","Shasta","Sierra","Siskiyou",
             "Solano","Sonoma","Stanislaus","Sutter","Tehama","Trinity","Tulare",
             "Tuolumne","Ventura","Yolo","Yuba"),
  CountyId  = c("06001","06003","06005","06007","06009","06011","06013","06015","06017",
                "06019","06021","06023","06025","06027","06029","06031","06033","06035",
                "06037","06039","06041","06043","06045","06047","06049","06051","06053",
                "06055","06057","06059","06061","06063","06065","06067","06069","06071",
                "06073","06075","06077","06079","06081","06083","06085","06087","06089",
                "06091","06093","06095","06097","06099","06101","06103","06105","06107",
                "06109","06111","06113","06115")
)
write.csv(ca_counties,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/Ca_CountiesID.csv", row.names=FALSE)

BayAreaCounties <- data.frame(CountyId = c("06001","06013","06041","06055","06075", "06081","06085","06095","06097"),
                              CountyName = c("Alameda","Contra Costa","Marin","Napa","San Francisco","San Mateo","Santa Clara","Solano","Sonoma"),
                              totalHouseholds =c(621958,423342,102728,45043,256642,247962,649398,162232,204742))
write.csv(BayAreaCounties,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/BayArea_CountiesID.csv", row.names=FALSE)
