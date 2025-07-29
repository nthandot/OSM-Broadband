library(tidyverse)
library(haven)
library(readr)
library(dplyr)
library(stringr)

my_data <- read.csv("C:/Users/admin_user/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021 (1)/CA-Fixed-Dec2021.csv")


#includes all providers
#Delete un-necessary columns LogRecNo, Provider_Id, FRN,HocoNum, HocoFinal, Business
my_data <- subset (my_data, select = -LogRecNo)
my_data <- subset (my_data, select = -Provider_Id)
my_data <- subset (my_data, select = -FRN)
my_data <- subset (my_data, select = -HocoNum)
my_data <- subset (my_data, select = -HocoFinal)
my_data <- subset (my_data, select = -Business)

#Link to field names and descriptions: https://www.fcc.gov/general/explanation-broadband-deployment-data 
#Column StateAbbr: 2-letter state abbreviation used by the US Postal Service
#BlockCode: 15-digit census block code used in the 2010 US Census
#TechCode: 2-digit code indicating the Technology of Transmission for broadband service

#Shows all column types
str(my_data)

#Shows first 10 rows of dataframe
head(my_data, n=1)
head(my_data[,10,11],1)

#Filters to CA only
filter(my_data, StateAbbr == 'CA')

#filters to FCC codes for DSL (10, 11), U-verse (12), and Fiber(50).
filter(my_data, TechCode==10 | TechCode==11 | TechCode ==12 |TechCode == 50)

#Creates BlockGroup Column
my_data$CensusBlockGroup <- substr(my_data$BlockCode,0,11)
my_data$CensusBlockGroup <- paste0("0",my_data$CensusBlockGroup)

write.csv(my_data, "C:/Users/admin_user/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021 (1)/CA.Broadband.BlockGroup.Clean.csv", row.names=FALSE)


#Create a column that only contains tracts. Census tracts are the first 11 digits
#https://www.census.gov/programs-surveys/geography/guidance/geo-identifiers.html
#Census Tract State (2)+County(3)+Tract(6)
my_data$CensusTract <- substr(my_data$BlockCode,0,10)
my_data$CensusTract <- paste0("0",my_data$CensusTract)



write.csv(my_data, "C:/Users/admin_user/Documents/OBI/Equity Metrics/OSM/CA-Fixed-Dec2021 (1)/CA.Broadband.CensusTract.Clean.csv", row.names=FALSE)
