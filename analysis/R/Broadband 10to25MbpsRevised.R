
library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)
library(tidycensus)
#census_api_key("356cc07a59d8c77671c672771e51a7b8a64b4954",install=TRUE)

setwd("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM")
#my_data <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021-v1.csv")
code10 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Copper_broadband_(10)/bdc_Copper.csv")
code40 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Cable_broadband_(40)/bdc_Cable.csv")
code50 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_FibertothePremises_broadband_(50)/bdc_Fiber.csv")
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

#---merges the three datasets and deletes duplicate blocks keeping only the ones with the highest speeds
fcc_data <- bind_rows(code10,code40,code50) %>% 
  arrange(block_geoid, desc(max_advertised_download_speed )) %>% 
  distinct(block_geoid, .keep_all = TRUE)

#Renames columns
fcc_data <- fcc_data %>% rename(census_block =block_geoid, 
                                max_down =max_advertised_download_speed, 
                                max_up =max_advertised_upload_speed,
                                tech_code = technology)

#converts census blocks to tracts and county id's text
#https://www.census.gov/programs-surveys/geography/guidance/geo-identifiers.html
#Census Tract State (2)+County(3)+Tract(6)
fcc_data$census_block <- as.character(fcc_data$census_block)
fcc_data$census_block <- paste0("0",fcc_data$census_block) #adds a leading zero to block code
fcc_data$census_tract <- substr(fcc_data$census_block,0,11)
fcc_data$CountyId <- substr(fcc_data$census_block,0,5)

#loads census household data
CnsBlkHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlock2020households.csv")
CnsTctHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusTract2020households.csv")
CnsBlkGroupHousehold <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlockGroup2020households.csv")


#Removes Columns from census household dataframe
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)
CnsTctHousehold$census_tract <- paste0("0",CnsTctHousehold$census_tract) #adds a leading zero to block code

CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value)
CnsBlkHousehold$census_block <- paste0("0",CnsBlkHousehold$census_block) #adds a leading zero to block code
CnsBlkHousehold$block_group <- substr(CnsBlkHousehold$census_block,0,12)

#Filters and cleans block group dataset
CnsBlkGroupHousehold <- CnsBlkGroupHousehold %>% 
  select(GEOID,households)
CnsBlkGroupHousehold$block_group <- as.character(CnsBlkGroupHousehold$GEOID)
CnsBlkGroupHousehold$block_group <- paste0("0",CnsBlkGroupHousehold$block_group)

#Link to field names and descriptions: https://www.fcc.gov/general/explanation-broadband-deployment-data 
#Column StateAbbr: 2-letter state abbreviation used by the US Postal Service
#BlockCode: 15-digit census block code used in the 2010 US Census
#TechCode: 2-digit code indicating the Technology of Transmission for broadband service

#Shows all column types
#str(fcc_data)

#--------Filters fcc data to blocks between 10 and 25 Mbps---------
#Creates distinct list of census blocks greater than 10Mbps
list_over10 <- fcc_data %>%
  filter(max_down>=10)

#Removes CensusBlocks over 10Mbps from df 
clean_under10 <- fcc_data %>% 
  filter(!census_block %in% list_over10$census_block)

#Creates distinct list over 25
list_over25<- fcc_data %>%
  filter(max_down >25)
list_over25 <- distinct(list_over25, census_block)
#Creates fcc data set of blocks with coverage between 10 and 25 Mbps
clean_10to25 <- fcc_data %>%
  filter(!census_block %in% clean_under10$census_block & !census_block %in% list_over25$census_block)

#Data validation
blkIds6to25 <- clean_10to25$census_block %>% unique ()
blkIdsOver25 <- list_over25$census_block %>% unique ()
blkIdsAll <- fcc_data$census_block %>% unique()

#Merge Household with Broadband dataframe and deletes any tracts with zero households
clean10to25_and_household <-merge(clean_10to25,CnsBlkHousehold, by="census_block")

#Creates df with bay area counties
BayAreaCounties <- data.frame(CountyId = c("6001","6013","6041","6055","6085", "6075","6081","6095","6097"))

#-------sum by block group--------------------------------------------------------
ten_25_blockgroup <- clean10to25_and_household %>%
  group_by(block_group) %>%
  summarise(BlockHHs10_25 = sum(household_num, na.rm = TRUE),
            .groups = "drop")

ten_25_blockgroup <- ten_25_blockgroup%>%
  filter(!duplicated(block_group))

BlockGroupData <- left_join(CnsBlkGroupHousehold, ten_25_blockgroup, by ="block_group")

BlockGroupData$PercentHH_10_25 <- BlockGroupData$BlockHHs10_25/BlockGroupData$households
#Converts Na values to 0
BlockGroupData$PercentHH_10_25[is.na(BlockGroupData$PercentHH_10_25)] <-0

#puts back in county and census tract Id's
BlockGroupData$CountyId <- substr(BlockGroupData$GEOID,1,4) 
BlockGroupData$census_tract <- substr(BlockGroupData$block_group, 0,11)

#-----data check ---- 
blockgroupcheck <- BlockGroupData$block_group %>% unique()

#merge with tcac 
BG_10_25andTCAC <- left_join(BlockGroupData,tcacData,by ="census_tract")
BG_10_25andTCAC <- BG_10_25andTCAC %>%  
  rename(OpportunityCategory = Opportunity.Category,
         OpportunityScore = Opportunity.Score,
         CountyName = County.Name,
  )
BG_10_25andTCAC <- BG_10_25andTCAC %>% 
  filter(PercentHH_10_25 >0,
         OpportunityCategory == "Low Resource")

#Reorders columns
BG_10_25andTCAC <- BG_10_25andTCAC %>% 
  relocate(block_group,census_tract,CountyId,.after = GEOID)

#Deletes unnecessary columns
BG_10_25andTCAC <- BG_10_25andTCAC %>% 
  select(GEOID,block_group,census_tract,CountyId,households,BlockHHs10_25,PercentHH_10_25, OpportunityCategory,OpportunityScore,CountyName)

BG_10_25andTCAC <- BG_10_25andTCAC %>% filter(CountyId %in%BayAreaCounties$CountyId)

write_xlsx(BG_10_25andTCAC,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BayAreaBlockGroupData10to25.xlsx")
write.csv(BlockGroupData,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BlockGroupData10to25.csv", row.names = FALSE)
#-----data validation -----------------------------------check if needed
#blksbayarea <- CountbayAreaBlocks6_25$census_block %>% unique()
trcts <- clean10to25_and_household$census_tract %>% unique()
#CountbayAreaBlocks6_25 <- CountbayAreaBlocks6_25[!duplicated(CountbayAreaBlocks6_25$BlockCode),]

#Sums household by tracts
clean10to25_and_household  <- clean10to25_and_household  %>%
  group_by(census_tract)%>%
  mutate(TractHHs10_25=sum(household_num),na.rm=TRUE)%>%
  ungroup

#creates new tract level df
CnsTractData <- clean10to25_and_household%>%
  filter(!duplicated(census_tract))


#Merge tract household and block data
CnsTractData <- left_join(CnsTctHousehold,CnsTractData, by ="census_tract")
CnsTractData$PercentHH10to25 <- CnsTractData$TractHHs10_25/CnsTractData$value
#Converts Na values to 0
CnsTractData$PercentHH10to25[is.na(CnsTractData$PercentHH10to25)] <-0
CnsTractData$CountyId <- substr(CnsTractData$census_tract,2,5)
CnsTractData <- subset(CnsTractData, select =c(census_tract,CountyId,TractHHs10_25,value,PercentHH10to25))

#Merge tcac data
Broadband10_25andTCAC <- left_join(tcacData,CnsTractData, by ="census_tract")
Broadband10_25andTCAC <- Broadband10_25andTCAC %>% filter(CountyId %in%BayAreaCounties$County)
#deletes tracts where there are no households with under 10 mbps
Broadband10_25andTCAC <- Broadband10_25andTCAC%>%
  filter(PercentHH10to25 > 0)

write.csv(CnsTractData, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CAtracts10_25.csv", row.names=FALSE)
write.csv(Broadband10_25andTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Broadband10_25andTCAC.csv", row.names=FALSE)

check <- fcc_data %>% filter(census_tract== "06075061000")
#-----Table of household by county
#totals number of households with 6 to 25 Mbps
CnsTractData$countyId <- substr(CnsTractData$census_tract,3,5)
HHbyCounty <- CnsTractData %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>%
  group_by(countyId) %>% 
  summarize(
    CountyHHs10to25 = sum(TractHHs10_25)
  )

CnsTctHousehold$countyId <- substr(CnsTctHousehold$census_tract,3,5)

#totals number of households in bay area counties
TotalHHsbyCounty <- CnsTctHousehold %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>% 
  group_by(countyId) %>% 
  summarize(
    totalCountyHH = sum(value)
  )
HHCountytable <- left_join(HHbyCounty,TotalHHsbyCounty, by="countyId")
HHCountytable$pctCountyHH <- (HHCountytable$CountyHHs10to25/HHCountytable$totalCountyHH)*100






