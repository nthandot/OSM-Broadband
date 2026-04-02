#Cleaning and checking data

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
#All other code
code60 <- read.csv ("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_GSOSatellite_broadband_(60)/GSOSatellite.csv")
code61 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_NGSOSatellite_broadband_(61)/NGSOSatellite.csv")
code70 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_UnlicensedFixedWireless_broadband_(70)/UnlicensedFixedWireless.csv")
code71 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_LicensedFixedWireless_broadband_(71)/LicensedFixedWireless.csv")
code72 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_LBRFixedWireless_broadband_(72)/LBRFixedWireless.csv")
code0 <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/FCC Data/bdc_Other_broadband_(0)/Other_fixed_broadband.csv")

CnsBlkHousehold <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM Broadband Box Files/data/raw/CensusBlock2020households.csv")
CnsBlkHousehold$census_block <- as.character(CnsBlkHousehold$GEOID)
CnsBlkHousehold$census_block <- paste0("0",CnsBlkHousehold$census_block) #adds a leading zero to block code
CnsBlkHousehold$census_tract <- substr(CnsBlkHousehold$census_block,0,11)
CnsBlkHousehold$CountyId <- substr(CnsBlkHousehold$census_block,0,5)

#--------Cleans FCC data ------#
#Keeps only blocks with residential broadband x- Business and Residential service, R - Residential-only service
code10<-code10 %>% filter(business_residential_code %in%c("X","R"))
code40<-code40 %>% filter(business_residential_code %in%c("X","R"))
code50<-code50 %>% filter(business_residential_code %in%c("X","R"))
code60<-code60 %>% filter(business_residential_code %in%c("X","R"))
code61<-code61 %>% filter(business_residential_code %in%c("X","R"))
code70<-code70 %>% filter(business_residential_code %in%c("X","R"))
code71<-code71 %>% filter(business_residential_code %in%c("X","R"))
code72<-code72 %>% filter(business_residential_code %in%c("X","R"))
code0<-code0 %>% filter(business_residential_code %in%c("X","R"))


#deletes unnecessary columns
code10 <- code10 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code40 <- code40 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code50 <- code50 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code60 <-code60 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code61 <-code61 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code70 <-code70 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code71 <-code71 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code72 <-code72 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)
code0 <-code0 %>% select(max_advertised_download_speed,max_advertised_upload_speed,technology,block_geoid)

#merges the three datasets and deletes duplicate blocks keeping only the ones with the highest speeds
#Code0 or Other only has 5 blocks where broadband is only provided to businesses
fcc_data_all <- bind_rows(code10,code40,code50,code60,code61,code70,code71,code72) %>% 
  arrange(block_geoid, desc(max_advertised_download_speed )) %>% 
  distinct(block_geoid, .keep_all = TRUE)

#Renames columns
fcc_data_all <- fcc_data_all %>% rename(census_block =block_geoid, 
                                max_down =max_advertised_download_speed, 
                                max_up =max_advertised_upload_speed,
                                tech_code = technology)

fcc_data_all$census_block <- as.character(fcc_data_all$census_block)
fcc_data_all$census_block <- paste0("0",fcc_data_all$census_block) #adds a leading zero to block code
fcc_data_all$census_tract <- substr(fcc_data_all$census_block,0,11)
fcc_data_all$CountyId <- substr(fcc_data_all$census_block,0,5)

#Leaves only blocks with no broadband codes
blocks_wo_broadband <- CnsBlkHousehold %>% filter(!census_block %in% fcc_data_all$census_block)

write.csv(blocks_wo_broadband, "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/NoBroadbandBayAreaBlocks.csv", row.names=FALSE)
