library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)
library(tidycensus)

setwd("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM")
code10 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Copper_broadband_(10)/bdc_Copper.csv")
code40 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Cable_broadband_(40)/bdc_Cable.csv")
code50 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_FibertothePremises_broadband_(50)/bdc_Fiber.csv")
#my_data <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021-v1.csv")
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


#Pulls 2021 CA household counts by census block
CnsBlkHousehold <- get_decennial(
  geography = "block",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
write.csv(CnsBlkHousehold,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlock2020households.csv", row.names=FALSE)

#Pulls 2021 CA household counts by census block
CnsTctHousehold <- get_decennial(
  geography = "tract",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
write.csv(CnsTctHousehold,"/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusTract2020households.csv", row.names=FALSE)

#Removes Columns from census household dataframe
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)

CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value)

#Cleans for low-fiber clustering
#Merge Census data to get household number by census tract
clean_fiber <- my_data1 %>%
  filter(tech_code == 50)

#delete duplicate census blocks leaving only blocks with highest value
FiberDeploy <- clean_fiber %>%
  group_by(census_block)%>%
  filter(max_down ==max(max_down))%>%
  ungroup()
FiberDeploy <- FiberDeploy [!duplicated(FiberDeploy$census_block),]

#merge with household data
FiberDeploy_and_household <-merge(CnsBlkHousehold,FiberDeploy,by="census_block")
FiberDeploy_and_household <- FiberDeploy_and_household %>%
  filter(household_num > 0)

#Sums household by tracts
FiberDeploy_and_household <- FiberDeploy_and_household %>%
  group_by(census_tract)%>%
  mutate(NumHHwFiberTracts=sum(household_num))%>%
  ungroup

#Data validation
CountCnsBlock <- FiberDeploy_and_household$census_block %>% unique()
HouseholdsSum <- sum(FiberDeploy_and_household$household_num)

## ------ not necessar at the moment
#Counts number of blocks in a tract with broadband up to 1000 mbps
#FiberDeploy_and_household <-FiberDeploy_and_household %>%
 # group_by(CensusTractFull)%>%
  #mutate(FiberBlocks_inTract =sum(Consumer,na.rm=TRUE))%>%
  #ungroup
##-------------------#

#delete duplicates and keeps highest fiber speeds for merge
FiberDeploy_and_household <- FiberDeploy_and_household %>%
  group_by(census_tract)%>%
  filter(max_down ==max(max_down))%>%
  ungroup()

FiberDeploy_and_household <- FiberDeploy_and_household%>%
  filter(!duplicated(census_tract))


#Merge tract household and block data
CnsTractData <- left_join(FiberDeploy_and_household,CnsTctHousehold, by="census_tract")
#Changes NA values to zero for tracts without any fiber
#CnsTractData$NumHHwFiberTracts[is.na(CnsTractData$NumHHwFiberTracts)] <- 0

#Creates column for percent of households in tract with fiber
CnsTractData$HHPercentwFiber <- CnsTractData$NumHHwFiberTracts / CnsTractData$value
CnsTractData <- subset(CnsTractData, select =c(census_tract,max_down, tech_code,NumHHwFiberTracts ,value,HHPercentwFiber))

#Merge tcac data
FiberandTCAC <- left_join(CnsTractData, tcacData, by ="census_tract")
FiberandTCAC <- FiberandTCAC %>% filter(Opportunity.Category == "Low Resource")

write.csv(CnsTractData, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Alltractswith_Fiber.csv", row.names=FALSE )
write.csv(FiberandTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/All_Fiber_TCAC.csv", row.names=FALSE)

#Writes data to box files
