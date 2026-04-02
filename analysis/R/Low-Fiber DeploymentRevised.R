library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)
library(tidycensus)
library(writexl)
library(janitor)

setwd("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM")
code50 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_FibertothePremises_broadband_(50)/bdc_Fiber.csv")
#my_data <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021-v1.csv")
tcacData <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/Broadband Analysis/TCAClowOpp.csv")

tcacData$census_tract <- as.character(tcacData$FIPS)
tcacData$census_tract <- paste0("0",tcacData$census_tract)

#--------Cleans FCC data ------#
#deletes unnecessary columns
fcc_data <- code50 %>% select(max_advertised_download_speed,max_advertised_upload_speed,block_geoid,business_residential_code)

#Renames columns
fcc_data <- fcc_data %>% rename(census_block =block_geoid, 
                                max_down =max_advertised_download_speed, 
                                max_up =max_advertised_upload_speed)
#converts census blocks to string
fcc_data$census_block <- as.character(fcc_data$census_block)
fcc_data$census_block <- paste0("0",fcc_data$census_block) #adds a leading zero to block code


#Gets census data from file generated from API pull
CnsBlkHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlock2020households.csv")
CnsTctHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusTract2020households.csv")
CnsBlkGroupHousehold <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlockGroup2020households.csv")


#Removes Columns from census household dataframe
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)
CnsTctHousehold$census_tract <- paste0("0",CnsTctHousehold$census_tract) #adds a leading zero to block code

CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value) #renames columns
CnsBlkHousehold$census_block <- paste0("0",CnsBlkHousehold$census_block) #adds a leading zero to block code
CnsBlkHousehold$census_tract <- substr(CnsBlkHousehold$census_block,0,11) #creates tract column
CnsBlkHousehold$CountyId <- substr(CnsBlkHousehold$census_block,0,5) #creates tract column

#Filters and cleans block group dataset
CnsBlkGroupHousehold <- CnsBlkGroupHousehold %>% 
  select(GEOID,households)
CnsBlkGroupHousehold$block_group <- as.character(CnsBlkGroupHousehold$GEOID)
CnsBlkGroupHousehold$block_group <- paste0("0",CnsBlkGroupHousehold$block_group)

#Creates business only and residential and business df's
fcc_all <- fcc_data %>% 
  filter(business_residential_code %in%c("X","R")) %>% 
  arrange(census_block, desc(max_down)) %>% 
  distinct(census_block, .keep_all = TRUE)

fcc_business_only <- fcc_data %>% 
  filter(business_residential_code %in%c("B")) %>% 
  arrange(census_block, desc(max_down)) %>% 
  distinct(census_block, .keep_all = TRUE)

#deletes blocks where residential or business fiber is present to leave business only blocks
list_residentialandbusiness <- fcc_all$census_block
fcc_business_only <- fcc_business_only %>% 
  filter(!fcc_business_only$census_block %in% list_residentialandbusiness)
#renames columns
fcc_business_only <- fcc_business_only %>% rename(b_max_down = max_down,
                                                  b_max_up = max_up)

#merge with household data
FiberDeploy_and_household <-left_join(CnsBlkHousehold,fcc_all,by="census_block")
FiberDeploy_and_household <-left_join(FiberDeploy_and_household,fcc_business_only,by="census_block")
#merges business and residential codes into one column
FiberDeploy_and_household <- FiberDeploy_and_household %>% 
  mutate(business_residential_code=coalesce(business_residential_code.x,business_residential_code.y),
         max_down = coalesce(max_down,b_max_down),
         max_up= coalesce(max_up,b_max_up))

FiberDeploy_and_household <- FiberDeploy_and_household %>% select(-business_residential_code.x,
                                                                  -business_residential_code.y,
                                                                  -b_max_down, -b_max_up)

#data validation-------
sum(!is.na(FiberDeploy_and_household$business_residential_code))
table(FiberDeploy_and_household$business_residential_code)

FiberDeploy_and_household$block_group <- substr(FiberDeploy_and_household$census_block,0,12)
#-----------Sum by block group ---------------------------------
fiber_blockgroup <- FiberDeploy_and_household %>%
  group_by(block_group) %>%
  summarise(BlockHHsFiber = sum(household_num[business_residential_code %in% c("X","R")], na.rm = TRUE),
            .groups = "drop")

fiber_blockgroup <- fiber_blockgroup%>%
  filter(!duplicated(block_group))

BlockGroupData <- left_join(CnsBlkGroupHousehold, fiber_blockgroup, by ="block_group")

BlockGroupData$PercentHH_fiber <- BlockGroupData$BlockHHsFiber/BlockGroupData$households
#Converts Na values to 0
BlockGroupData$PercentHH_fiber[is.na(BlockGroupData$PercentHH_fiber)] <-0

#puts back in county and census tract Id's
BlockGroupData$CountyId <- substr(BlockGroupData$GEOID,1,4) 
BlockGroupData$census_tract <- substr(BlockGroupData$block_group, 0,11)

#-----data check ---- 
blockgroupcheck <- BlockGroupData$block_group %>% unique()

#merge with tcac 
BG_fiberandTCAC <- left_join(BlockGroupData,tcacData,by ="census_tract")
BG_fiberandTCAC <- BG_fiberandTCAC %>%  
  rename(OpportunityCategory = Opportunity.Category,
         OpportunityScore = Opportunity.Score,
         CountyName = County.Name,
  )

#Reorders columns
BG_fiberandTCAC <- BG_fiberandTCAC %>% 
  relocate(block_group,census_tract,CountyId,.after = GEOID)

#Deletes unnecessary columns
BG_fiberandTCAC <- BG_fiberandTCAC %>% 
  select(GEOID,block_group,census_tract,CountyId,households, OpportunityCategory,OpportunityScore,CountyName)

sum(BG_fiberandTCAC$OpportunityCategory == "Low Resource", na.rm = TRUE)

write_xlsx(BlockGroupData,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BayAreaBlockGroupDataFiber.xlsx")
write.csv(BlockGroupData,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BayAreaBlockGroupDataFiber.csv",row.names = FALSE)



#---------------------Sums household by tracts and if residential or business---------------------------------------
CnsTractData <- FiberDeploy_and_household %>%
  group_by(census_tract) %>%
  summarise(
    HH_ResidentialFiber = sum(household_num[business_residential_code %in% c("X","R")], na.rm = TRUE),
    HH_BusinessFiber = sum(household_num[business_residential_code == "B"], na.rm = TRUE),
    HH_BusinessandResFiber = sum(household_num[business_residential_code %in% c("X","R","B")], na.rm = TRUE),
    Codes_Present = paste(sort(unique(na.omit(business_residential_code))),collapse = ","),
    TotalHouseholdsinTracts = sum(household_num),
    .groups = "drop"
  )

#Creates column for percent of households in tract with fiber
CnsTractData$ResidentialPercentwFiber <- CnsTractData$HH_ResidentialFiber / CnsTractData$TotalHouseholdsinTracts
CnsTractData$BusinessOnlyPercentwFiber <- CnsTractData$HH_BusinessFiber / CnsTractData$TotalHouseholdsinTracts
CnsTractData$TotalPercentwFiber <- CnsTractData$HH_BusinessandResFiber / CnsTractData$TotalHouseholdsinTracts
CnsTractData$CountyId <- substr(CnsTractData$census_tract,0,5) #creates county column

#Converts nulls to 0 for tracts with 0 households
CnsTractData <- CnsTractData %>% mutate(across(c(ResidentialPercentwFiber,BusinessOnlyPercentwFiber,TotalPercentwFiber), ~replace_na(.x,0)))

#-----Data validation
hhstractsinblocksdata <- sum(FiberDeploy_and_household$household_num)
hhsincensus <- sum(CnsTctHousehold$value)
CountCnsBlock <- FiberDeploy_and_household$census_block %>% unique()
HouseholdsSum <- sum(FiberDeploy_and_household$household_num)
BusinessTracts <- sum(CnsTractData$Codes_Present=="B", na.rm=TRUE)
CnsTractCount <- CnsTractData$census_tract %>% unique()
nullcount <- sum(is.na(CnsTractData$ResidentialPercentwFiber))
#--------

#Merge tcac data
FiberandTCAC <- left_join(CnsTractData, tcacData, by ="census_tract")
FiberandTCAC <- FiberandTCAC %>% filter(Opportunity.Category == "Low Resource")

write.csv(CnsTractData, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/interim/Fiber/Alltractswith_Fiber.csv", row.names=FALSE )
write.csv(FiberandTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/interim/Fiber/All_Fiber_TCAC.csv", row.names=FALSE)


#Creates one excel that includes Fiber, under 10mbps and 10 to 25 mbps percents

TractsUnder10 <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/CATractsUnder10.csv")
Tracts10to25 <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CAtracts10_25.csv")

#Reduces df to only necessary variables
Tracts10to25 <- Tracts10to25 %>% select(census_tract,PercentHH10to25)
TractsUnder10 <- TractsUnder10 %>% select(census_tract,PercentHH_under10)

TractsUnder10$census_tract <- as.character(TractsUnder10$census_tract)
TractsUnder10$census_tract <- paste0("0",TractsUnder10$census_tract)

Tracts10to25$census_tract <- as.character(Tracts10to25$census_tract)
Tracts10to25$census_tract <- paste0("0",Tracts10to25$census_tract)

all_data <- left_join(CnsTractData, TractsUnder10, by ="census_tract")
all_data <- left_join(all_data, Tracts10to25, by ="census_tract")
all_data <- left_join(all_data, tcacData, by ="census_tract")

#creates list of counties to merge
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

all_data <- left_join(all_data, ca_counties, by="CountyId")

all_data <- all_data %>% select(census_tract,TotalHouseholdsinTracts,Codes_Present,ResidentialPercentwFiber,BusinessOnlyPercentwFiber,TotalPercentwFiber,
                                CountyId,PercentHH_under10,PercentHH10to25,Opportunity.Category,county)

BayAreaCounties <- data.frame(CountyId = c("06001","06013","06041","06055","06075", "06081","06085","06095","06097"),
                              CountyName = c("Alameda","Contra Costa","Marin","Napa","San Francisco","San Mateo","Santa Clara","Solano","Sonoma"),
                              totalHouseholds =c(621958,423342,102728,45043,256642,247962,649398,162232,204742))

MethodologyTable <- all_data %>% 
  transmute(
    CountyId = CountyId,
    county= county,
    ResidentialPercentwFiber = ResidentialPercentwFiber,
    Opportunity.Category = Opportunity.Category,
    TotalHouseholdsinTracts = TotalHouseholdsinTracts,
    HHunder10 = PercentHH_under10*TotalHouseholdsinTracts,
    HH10to25 = PercentHH10to25*TotalHouseholdsinTracts,
    HHwFiber = ResidentialPercentwFiber*TotalHouseholdsinTracts
    )
CAFiberTable <- MethodologyTable %>% 
  filter(Opportunity.Category == "Low Resource" & ResidentialPercentwFiber<=.294872) %>% 
  group_by(CountyId) %>% 
  summarize(
    n=n(),
    HHwFiber = sum(HHwFiber)
  )
CAFiberTable %>% adorn_totals()

BayAreaFiberTable <- MethodologyTable %>% 
  filter(CountyId %in%BayAreaCounties$CountyId)

BayAreaBB_TCAC_Table <- MethodologyTable %>% 
  filter(CountyId %in%BayAreaCounties$CountyId & Opportunity.Category == "Low Resource") %>% 
  group_by(CountyId) %>% 
  summarize(
    totalHHs = sum(TotalHouseholdsinTracts),
    HHUnder10Mbps = sum(HHunder10),
    HH10to25Mbps = sum(HH10to25),
  )
MethodologyTable <- merge(MethodologyTable, BayAreaCounties, by = "CountyId")

write.csv(all_data, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/interim/Fiber/All_Broadband.csv", row.names=FALSE)
