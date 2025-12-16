
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



#----test: merges the three datasets and deletes duplicate blocks keeping only the ones with the highest speeds
my_data1 <- bind_rows(code10,code40,code50) %>% 
  #arrange(block_geoid, desc(max_advertised_download_speed )) %>% 
  distinct(block_geoid, .keep_all = TRUE)

#Renames columns
my_data1 <- my_data1 %>% rename(census_block =block_geoid, 
                                max_down =max_advertised_download_speed, 
                                max_up =max_advertised_upload_speed,
                                tech_code = technology)

#--try this method to delete duplicates to determine if there is a different result ---old code that is unnecessary----#
#delete duplicate census blocks leaving only blocks with highest value
my_data1 <- my_data1 %>%
  group_by(census_block) %>%
  filter (max_down == max(max_down)) %>%
  ungroup()
my_data1 <- my_data1[!duplicated(my_data1$census_block),]
#----end old code


#-----edits made until here-------

Census_variables <- load_variables(2020,"dhc")
view(Census_variables)
#Pulls 2021 CA household counts by census block
CnsBlkHousehold <- get_decennial(
  geography = "block",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
#Pulls 2021 CA household counts by census tract
CnsTctHousehold <- get_decennial(
  geography = "tract",
  variables = "H1_001N", #total number of households
  state ="CA",
  #county = "Alameda",
  sumfile= 'pl',
  year = 2020,
)
#Removes Columns from census household dataframe
CnsTctHousehold <-subset (CnsTctHousehold, select =-c(variable,NAME))
CnsBlkHousehold <-subset (CnsBlkHousehold, select =-c(variable,NAME))
CnsTctHousehold$census_tract <- substr(CnsTctHousehold$GEOID,0,11)

CnsBlkHousehold <- CnsBlkHousehold %>% rename(census_block =GEOID,
                                              household_num = value)

#converts census blocks to tracts and county id's text
#https://www.census.gov/programs-surveys/geography/guidance/geo-identifiers.html
#Census Tract State (2)+County(3)+Tract(6)
my_data1$census_block <- as.character(my_data1$census_block)
my_data1$census_block <- paste0("0",my_data1$census_block) #adds a leading zero to block code
my_data1$census_tract <- substr(my_data1$census_block,0,11)
my_data1$CountyId <- substr(my_data1$census_block,0,5)


#Link to field names and descriptions: https://www.fcc.gov/general/explanation-broadband-deployment-data 
#Column StateAbbr: 2-letter state abbreviation used by the US Postal Service
#BlockCode: 15-digit census block code used in the 2010 US Census
#TechCode: 2-digit code indicating the Technology of Transmission for broadband service

#Shows all column types
#str(my_data1)


#for each row if Broadband speed >6 and nondistinct delete row
list_over10 <- my_data1 %>%
  filter(max_down>=10)

#Creates distinct list of census blocks greater than 6Mbps
#list_over10 <- distinct(list_over10,census_block)

#Removes CensusBlocks over 10Mbps from df 
clean_under10 <- my_data1 %>% 
  filter(!census_block %in% list_over10$census_block)

#Filters to CA only, Consumer Service Provided and Download speeds between 6 and 25 Mbps
list_over25<- my_data1 %>%
  filter(max_down >=25)
list_over25 <- distinct(list_over25, census_block)

clean_10to25 <- my_data1 %>%
  filter(!census_block %in% clean_under10$census_block & !census_block %in% list_over25$census_block)

#Data validation
blkIds6to25 <- clean_10to25$census_block %>% unique ()
blkIdsOver25 <- list_over25$census_block %>% unique ()
blkIdsAll <- my_data1$census_block %>% unique()

#Merge Household with Broadband dataframe and deletes any tracts with zero households
clean10to25_and_household <-merge(clean_10to25,CnsBlkHousehold, by="census_block")
clean10to25_and_household <- clean10to25_and_household %>%
  filter(household_num > 0)

#checks number of blocks in merge (difference is the number blocks with no households)
blkIduner10wHouseold <-clean10to25_and_household$BlockCode %>% unique()
#checks number of blocks in bay area
BayAreaBlocks10_25 <- clean10to25_and_household %>%filter(clean10to25_and_household$CountyId == "06001" | 
                                                               clean10to25_and_household$CountyId == "06013"| 
                                                               clean10to25_and_household$CountyId == "06041"|
                                                               clean10to25_and_household$CountyId == "06055"|
                                                               clean10to25_and_household$CountyId == "06085"|
                                                               clean10to25_and_household$CountyId == "06075"|
                                                               clean10to25_and_household$CountyId == "06081"|
                                                               clean10to25_and_household$CountyId == "06095"|
                                                               clean10to25_and_household$CountyId == "06097")

#-----data validation ----- check if needed
#blksbayarea <- CountbayAreaBlocks6_25$census_block %>% unique()
#trctsbayarea <- CountbayAreaBlocks6_25$CensusTract %>% unique()
#CountbayAreaBlocks6_25 <- CountbayAreaBlocks6_25[!duplicated(CountbayAreaBlocks6_25$BlockCode),]

#Sums household by tracts
BayAreaBlocks10_25 <- BayAreaBlocks10_25 %>%
  group_by(census_tract)%>%
  mutate(TractHHs10_25=sum(household_num),na.rm=TRUE)%>%
  ungroup

#-----may be a good check----Counts number of blocks in a tract with broadband between 6 and 25mbps
#BayAreaBlocks10_25 <-BayAreaBlocks10_25 %>%
 # group_by(census_tract)%>%
  #mutate(Blocks10_25inTract =sum(Consumer))%>%
  #ungroup

#creates new tract level df
CnsTract10to25HHs <- BayAreaBlocks10_25%>%
  filter(!duplicated(census_tract))


#Merge tract household and block data
CnsTractData <- left_join(CnsTract10to25HHs,CnsTctHousehold, by ="census_tract")
CnsTractData$PercentHH10to25 <- CnsTractData$TractHHs10_25/CnsTractData$value
CnsTractData <- subset(CnsTractData, select =c(census_tract,TractHHs10_25,value,PercentHH10to25))

#Merge tcac data
Broadband10_25andTCAC <- left_join(CnsTractData, tcacData, by ="census_tract")
Broadband10_25andTCAC <- Broadband10_25andTCAC %>% filter(Opportunity.Category == "Low Resource")

write.csv(CnsTractData, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/BayAreaAlltracts10_25.csv", row.names=FALSE)
write.csv(Broadband10_25andTCAC, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Broadband10_25andTCAC.csv", row.names=FALSE)

#Table of household by county
#totals number of households with 6 to 25 Mbps
CnsTractData$countyId <- substr(CnsTractData$GEOID,3,5)
HHbyCounty <- CnsTractData %>% 
  filter(countyId %in% c("001","013","041","055","075","081","085","095","097")) %>%
  group_by(countyId) %>% 
  summarize(
    CountyHHs6to25 = sum(TractHHs6_25)
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
HHCountytable$pctCountyHH <- (HHCountytable$CountyHHs6to25/HHCountytable$totalCountyHH)*100
HHCountytable <- HHCountytable %>% adorn_totals("row","col")
#old code


hist(CountbayAreaBlocks$CensusTractNum)
ggplot(CountbayAreaBlocks, aes (x=BlockCode,y=CensusTractNum))
FreqTracts<- table(CountbayAreaBlocks$CensusTractNum)
print(FreqTracts)




