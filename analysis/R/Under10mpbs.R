
library(dplyr)
library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)
library(tidycensus)
#census_api_key("356cc07a59d8c77671c672771e51a7b8a64b4954",install=TRUE)
setwd("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM")
code10 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Copper_broadband_(10)/bdc_Copper.csv")
code40 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Cable_broadband_(40)/bdc_Cable.csv")
code50 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_FibertothePremises_broadband_(50)/bdc_Fiber.csv")
my_data <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021-v1.csv")
tcacData <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/Broadband Analysis/TCAClowOpp.csv")

tcacData$census_tract <- as.character(tcacData$FIPS)
tcacData$census_tract <- paste0("0",tcacData$census_tract)

#--------Cleans FCC data ------#
#Keeps only blocks with residential broadband x- Business and Residential service, R - Residential-only service
code10<-code10 %>% filter(business_residential_code %in%c("X","R"))
code40<-code40 %>% filter(business_residential_code %in%c("X","R"))
code50<-code50 %>% filter(business_residential_code %in%c("X","R"))
#deletes unnecessary columns
code10 <- code10 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code40 <- code40 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code50 <- code50 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)

#merges the three datasets and deletes duplicate blocks keeping only the ones with the highest speeds
my_data1 <- bind_rows(code10,code40,code50) %>% 
  arrange(block_geoid, desc(max_advertised_download_speed )) %>% 
  distinct(block_geoid, .keep_all = TRUE)

#Renames columns
my_data1 <- my_data1 %>% rename(census_block =block_geoid, 
                               max_down =max_advertised_download_speed, 
                               max_up =max_advertised_upload_speed,
                               tech_code = technology)
#converts census blocks to string
my_data1$census_block <- as.character(my_data1$census_block)
my_data1$census_block <- paste0("0",my_data1$census_block) #adds a leading zero to block code
my_data1$census_tract <- substr(my_data1$census_block,0,11)
my_data1$CountyId <- substr(my_data1$census_block,0,5)

#------loads census data --------#
Census_variables <- load_variables(2020,"dhc")
#view(Census_variables)
#Pulls 2021 CA household counts by census block
CnsTctHousehold <- get_decennial(
  geography = "tract",
  variables = "H1_001N", #total number of households
  state ="CA",
  sumfile= 'pl',
  year = 2020,
)

Census_variables <- load_variables(2020,"dhc")
#view(Census_variables)
#Pulls 2021 CA household counts by census block
CnsBlkHousehold <- get_decennial(
  geography = "block",
  variables = "H1_001N", #total number of households
  state ="CA",
  sumfile= 'pl',
  year = 2020,
)

#Removes Columns from census household dataframe
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)

CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value)

#-------filters FCC data to under 10 mbps -----#
#Creates distinct list of census blocks greater than 6Mbps
list_over10 <- my_data1 %>%
  filter(max_down>10)

#Removes CensusBlocks over 6Mbps from df 
clean_under10 <- my_data1 %>% 
  filter(!census_block %in% list_over10$census_block)

#------Data validation----------
blkIdsAll <- my_data1$census_block %>% unique()
blkIdsOver <- list_over10$census_block %>% unique()
blkIdsUnder <- clean_under10$census_block %>% unique()

#Shows first 10 rows of dataframe
head(clean_under10, n=10)
#head(my_data1[,10,11],1)

#Merge Household with Broadband dataframe and deletes any blocks with zero households
Under10_and_household <-merge(clean_under10,CnsBlkHousehold, by="census_block")
Under10_and_household <- Under10_and_household %>%
  filter(household_num > 0)

#blkIduner6wHouseold <-Under6_and_household$census_block %>% unique() #don't need just a quality check

#Reduces to only blocks in bay area nine county region
CountybayAreaBlocks <- Under10_and_household %>%filter(Under10_and_household$CountyId == "06001" | 
                                                       Under10_and_household$CountyId == "06013"| 
                                                       Under10_and_household$CountyId == "06041"|
                                                       Under10_and_household$CountyId == "06055"|
                                                       Under10_and_household$CountyId == "06085"|
                                                       Under10_and_household$CountyId == "06075"|
                                                       Under10_and_household$CountyId == "06081"|
                                                       Under10_and_household$CountyId == "06095"|
                                                       Under10_and_household$CountyId == "06097")
#------Quality control checks
blksbayarea <- CountybayAreaBlocks$BlockCode %>% unique()
trctsbayarea <- CountybayAreaBlocks$CensusTract %>% unique()

#Sums household by tracts
CountybayAreaBlocks <- CountybayAreaBlocks %>%
  group_by(census_tract)%>%
  mutate(TractHHsUnder10=sum(household_num),na.rm=TRUE)%>%
  ungroup

#delete duplicates for merge ---- don't think this is necessary
CnsTractUnder10HHs <- CountybayAreaBlocks%>%
  filter(!duplicated(census_tract))

#Merge tract household and block data
CnsTractData <- left_join(CnsTractUnder10HHs,CnsTctHousehold, by ="census_tract")

#Deletes unnecessary columns
CnsTractData$PercentHH_under10 <- CnsTractData$TractHHsUnder10/CnsTractData$value
CnsTractData <- subset(CnsTractData, select =c(census_tract,TractHHsUnder10,value,PercentHH_under10))

#Merge tcac data
Under10andTCAC <- left_join(CnsTractData, tcacData, by ="census_tract")
Under10andTCAC <- Under10andTCAC %>% filter(Opportunity.Category == "Low Resource")

#Writes CSV File
write.csv(Under10andTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/TractsUnder10andTCAC.csv", row.names=FALSE)
write.csv(CnsTractData,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM//Under10Mbps/AllBayTractsUnder10.csv", row.names=FALSE)

#--------Creates tables of HHs 
CnsTractData$countyId <- substr(CnsTractData$GEOID,3,5)
HHbyCounty <- CnsTractData %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>%
  group_by(countyId) %>% 
  summarize(
    CountyHHsunder6 = sum(TractHHsUnder6)
  )

CnsTctHousehold$countyId <- substr(CnsTctHousehold$GEOID,3,5)

#totals number of households in bay area counties
TotalHHsbyCounty <- CnsTctHousehold %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>% 
  group_by(countyId) %>% 
  summarize(
    totalCountyHH = sum(value)
  )
HHCountytable <- left_join(HHbyCounty,TotalHHsbyCounty, by="countyId")
HHCountytable$pctCountyHH <- (HHCountytable$CountyHHsunder6/HHCountytable$totalCountyHH)*100
HHCountytable <- HHCountytable %>% adorn_totals("row","col")

