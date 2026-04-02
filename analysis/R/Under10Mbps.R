
library(dplyr)
library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)
library(tidycensus)
library(writexl)
setwd("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/analysis/R")

#----------loads fcc, tcac, and census data---------#
code10 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Copper_broadband_(10)/bdc_Copper.csv")
code40 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Cable_broadband_(40)/bdc_Cable.csv")
code50 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_FibertothePremises_broadband_(50)/bdc_Fiber.csv")

blocks_wo_broadband <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/NoBroadbandBayAreaBlocks.csv")
tcacData <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/Broadband Analysis/TCAClowOpp.csv")

CnsBlkHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlock2020households.csv")
CnsTctHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusTract2020households.csv")
CnsBlkGroupHousehold <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlockGroup2020households.csv")

ca_counties <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/Ca_CountiesID.csv")
BayAreaCounties <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/data/raw/BayArea_CountiesID.csv")

#--------Cleans TCAC data------#
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
  
#----Cleans blocks with no broadband coverage-----#
blocks_wo_broadband <- blocks_wo_broadband %>% rename(household_num = value)
blocks_wo_broadband$census_block <- as.character(blocks_wo_broadband$GEOID)
blocks_wo_broadband$census_block <- paste0("0",blocks_wo_broadband$census_block) #adds a leading zero to block code
blocks_wo_broadband$census_tract <- substr(blocks_wo_broadband$census_block,0,11)
blocks_wo_broadband$CountyId <- substr(blocks_wo_broadband$census_block,0,5)
blocks_wo_broadband <- blocks_wo_broadband %>% select(household_num,census_block,census_tract,CountyId)

#-----Cleans Census tract and block data -------#
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)
CnsTctHousehold$census_tract <- paste0("0",CnsTctHousehold$census_tract) #adds a leading zero to block code

CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value)
CnsBlkHousehold$census_block <- paste0("0",CnsBlkHousehold$census_block) #adds a leading zero to block code


CnsBlkGroupHousehold$block_group <- as.character(CnsBlkGroupHousehold$GEOID)
CnsBlkGroupHousehold$block_group <- paste0("0",CnsBlkGroupHousehold$block_group)

#merges the fcc data and deletes duplicate blocks keeping only the ones with the highest speeds
fcc_data <- bind_rows(code10,code40,code50) %>% 
  arrange(block_geoid, desc(max_advertised_download_speed )) %>% 
  distinct(block_geoid, .keep_all = TRUE)
  
#Renames columns
fcc_data <- fcc_data %>% rename(census_block =block_geoid, 
                                max_down =max_advertised_download_speed, 
                                max_up =max_advertised_upload_speed,
                                tech_code = technology)
#converts census blocks to string
fcc_data$census_block <- as.character(fcc_data$census_block)
fcc_data$census_block <- paste0("0",fcc_data$census_block) #adds a leading zero to block code
fcc_data$block_group <- substr(fcc_data$census_block,0,12)
fcc_data$census_tract <- substr(fcc_data$census_block,0,11)
fcc_data$CountyId <- substr(fcc_data$census_block,0,5)


#-------filters FCC data to under 10 mbps and blocks without broadband-----#
#Creates distinct list of census blocks greater than 10Mbps
list_over10 <- fcc_data %>%
  filter(max_down>=10)
  
#Removes CensusBlocks over 10Mbps from df 
Blocks_under10 <- fcc_data %>% 
  filter(!census_block %in% list_over10$census_block)
  
#combines the blocks under 10 with blocks that have no broadband coverage
Blocks_under10 <- full_join(Blocks_under10,blocks_wo_broadband, by="census_block")
  Blocks_under10 <- Blocks_under10 %>% mutate(
    census_tract = coalesce(census_tract.x,census_tract.y),
    CountyId = coalesce(CountyId.x,CountyId.y)) %>% 
    select(census_tract, CountyId,census_block, block_group, max_down,max_up,tech_code)
  Blocks_under10$block_group <- substr(Blocks_under10$census_block,0,12)
    
  #------Data validation----------
  blkIdsAll <- fcc_data$census_block %>% unique()
  blkIdsOver <- list_over10$census_block %>% unique()
  blkIdsUnder <-Blocks_under10$census_block %>% unique()
  
  #Merge Household with Broadband dataframe 
  Blocks_Under10_and_household <-left_join(Blocks_under10,CnsBlkHousehold, by="census_block")

blockgrouptest <- Blocks_under10$block_group %>% unique()
tract_test <- Blocks_under10$census_tract %>% unique()
sum(duplicated(Blocks_under10$census_block))
sum(duplicated(blocks_wo_broadband$census_block))
nrow(Blocks_under10)
length(unique(Blocks_under10$census_block))
#------Calculation by block group --------------------------------------------------------#
Under10_blockgroup <- Blocks_Under10_and_household %>%
  group_by(block_group) %>%
  summarise(BlockHHsUnder10 = sum(household_num, na.rm = TRUE),
            .groups = "drop")

Under10_blockgroup <- Under10_blockgroup%>%
  filter(!duplicated(block_group))

BlockGroupData <- left_join(CnsBlkGroupHousehold, Under10_blockgroup, by ="block_group")

#Calculates percent of households with under 10 mbps access by tract
BlockGroupData$PercentHH_under10 <- BlockGroupData$BlockHHsUnder10/BlockGroupData$households
#Converts Na values to 0
BlockGroupData$PercentHH_under10[is.na(BlockGroupData$PercentHH_under10)] <-0

#puts back in county and census tract Id's
BlockGroupData$CountyId <- substr(BlockGroupData$GEOID,1,4) 
BlockGroupData$census_tract <- substr(BlockGroupData$block_group, 0,11)
#Cleans the merged dataframe
BlockGroupData  <- subset(BlockGroupData , select =-c(NAME))
BlockGroupData <- BlockGroupData %>% 
  relocate(block_group,census_tract,CountyId,.after = GEOID)

blockgroupcheck <- BlockGroupData$block_group %>% unique()

#Calculates racial and ethnic percentages
BlockGroupData$white_pct <- BlockGroupData$white/BlockGroupData$total_pop
BlockGroupData$black_pct <- BlockGroupData$black/BlockGroupData$total_pop
BlockGroupData$asian_pct <- BlockGroupData$asian/BlockGroupData$total_pop
BlockGroupData$american_indian_alaska_native_pct <- BlockGroupData$american_indian_alaska_native/BlockGroupData$total_pop
BlockGroupData$hawaian_pacific_island_pct <- BlockGroupData$hawaian_pacific_island/BlockGroupData$total_pop
BlockGroupData$hispanic_pct <- BlockGroupData$hispanic/BlockGroupData$total_pop
#deletes unnecessary racial count columns
BlockGroupData  <- subset(BlockGroupData , select =-c(white,black,asian,american_indian_alaska_native,hawaian_pacific_island,hispanic))


#merge with tcac
BG_Under10andTCAC <- left_join(BlockGroupData,tcacData,by ="census_tract")
BG_Under10andTCAC <- BG_Under10andTCAC %>%  
  rename(OpportunityCategory = Opportunity.Category,
         OpportunityScore = Opportunity.Score,
         CountyName = County.Name,
         )
#--------Data Check
tract_check <- BG_Under10andTCAC$census_tract %>% unique

#-----------------------------------------

BG_Under10andTCAC <- BG_Under10andTCAC %>% 
  filter(PercentHH_under10 >0,
         OpportunityCategory == "Low Resource")

BG_Under10andTCAC <- BG_Under10andTCAC %>% filter(CountyId %in%BayAreaCounties$CountyId)
BG_Under10andTCAC <- subset(BG_Under10andTCAC, select = -c(FIPS,Share...200..Poverty.Score,Share.with.Bachelors..Score,Employment.Rate.Score,
                                                           Median.Home.Value.Score,Share.Proficient.in.Math.Score,Share.Proficient.in.Reading.Score,
                                                           High.School.Grad.Rate.Score,Students.not.in.Poverty.Score,Environmental.Score, High.Poverty...Segregated,Region.Code))
#----- final data validation-----
tract_check <- BG_Under10andTCAC$census_tract %>% unique ()
blockgroupcheck <- BG_Under10andTCAC$block_group %>% unique()

write.csv(BlockGroupData, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BlockGroupDataUnder10.csv", row.names=FALSE)
write_xlsx(BG_Under10andTCAC,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BayAreaBlockGroupData.xlsx")

# --------Calculation by tract ------Sums household by tracts
  Under10_byTract <- Blocks_Under10_and_household %>%
    group_by(census_tract)%>%
    mutate(TractHHsUnder10=sum(household_num),na.rm=TRUE)%>%
    ungroup
  
  #delete duplicates for merge ---- don't think this is necessary
  Under10_byTract <- Under10_byTract%>%
    filter(!duplicated(census_tract))
  
  #Merge tract household and block data
  CnsTractData <- left_join(CnsTctHousehold, Under10_byTract, by ="census_tract")
  
  #Calculates percent of households with under 10 mbps access by tract
  CnsTractData$PercentHH_under10 <- CnsTractData$TractHHsUnder10/CnsTractData$value
  #Converts Na values to 0
  CnsTractData$PercentHH_under10[is.na(CnsTractData$PercentHH_under10)] <-0
  
  #cleans census tract dataset
  CnsTractData$CountyId <- substr(CnsTractData$census_tract,0,5)
  CnsTractData <- subset(CnsTractData, select =c(census_tract,CountyId,value,TractHHsUnder10,PercentHH_under10))
  
#----------Merge tcac data-------------#
  Under10andTCAC <- left_join(tcacData,CnsTractData, by ="census_tract")
  Under10andTCAC$CountyId <- substr(Under10andTCAC$CountyId, 2,5)
  Under10andTCAC <- Under10andTCAC %>% filter(CountyId %in%BayAreaCounties$CountyId)
  #deletes tracts where there are no households with under 10 mbps
  Under10andTCAC <- Under10andTCAC%>%
    filter(PercentHH_under10 > 0)

#Writes CSV File
write.csv(Under10andTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/TractsUnder10andTCAC.csv", row.names=FALSE)
write.csv(CnsTractData,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/CATractsUnder10.csv", row.names=FALSE)

check <- Under10andTCAC %>% filter(census_tract== "06001409000")
#--------Creates tables of HHs 
CnsTractData$countyId <- substr(CnsTractData$census_tract,3,5)
HHbyCounty <- CnsTractData %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>%
  group_by(countyId) %>% 
  summarize(
    CountyHHsunder10 = sum(TractHHsUnder10)
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
HHCountytable$pctCountyHH <- (HHCountytable$CountyHHsunder10/HHCountytable$totalCountyHH)*100



