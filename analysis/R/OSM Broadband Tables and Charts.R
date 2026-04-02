library(dplyr)
library(ggplot2)
library(openxlsx)
library(janitor)

setwd ("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/OSM html webmap/OSM-Broadband/analysis/R")

#----------------------------Creates tables and charts 
BlockGroupData <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BayAreaBlockGroupDataFiber.csv")
tcacData <- read.csv("C:/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/Broadband Analysis/TCAClowOpp.csv")
Under10 <- read.csv( "/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BlockGroupDataUnder10.csv")
ten_25 <- read.csv("/Users/nthando.thandiwe/Documents/OBI/Equity Metrics/OSM/Under10Mbps/BlockGroupData10to25.csv")
#----------------Creates master excel for all broadband speeds at the block level


AllBlockGroupData <- Under10 %>% 
  left_join(ten_25,by="GEOID") %>% 
  left_join(BlockGroupData, by = "GEOID")

AllBlockGroupData <-  subset (AllBlockGroupData, select =-c(block_group.x,census_tract.x,CountyId.x, households.x,
                                                            block_group.y,census_tract.y,CountyId.y, households.y))

tcacData <- tcacData %>% rename(census_tract= FIPS)
AllBlockGroupTCAC <- left_join(AllBlockGroupData,tcacData, by= "census_tract")
AllBlockGroupTCAC$CountyId <- substr(AllBlockGroupTCAC$census_tract,2,4)

BayAreaCounties <- data.frame(CountyId = c("001","013","041","055","075", "081","085","095","097"),
                              CountyName = c("Alameda","Contra Costa","Marin","Napa","San Francisco","San Mateo","Santa Clara","Solano","Sonoma"),
                              totalHouseholds =c(621958,423342,102728,45043,256642,247962,649398,162232,204742))

BayAreabgData <- AllBlockGroupTCAC %>% 
  filter(CountyId %in% BayAreaCounties$CountyId)
BayAreabgData <- left_join(BayAreabgData,BayAreaCounties, by = "CountyId")
BayAreabgData$totalHouseholds <- NULL
#Turns na to 0 for block groups
BayAreabgData$BlockHHsUnder10[is.na(BayAreabgData$BlockHHsUnder10)] <-0

#Sums low fiber for CA
sum(if_else(AllBlockGroupTCAC$Opportunity.Category == "Low Resource", AllBlockGroupTCAC$households,0),na.rm=TRUE)
sum(if_else(AllBlockGroupTCAC$Opportunity.Category == "Low Resource"& AllBlockGroupTCAC$PercentHH_fiber<=.294872, AllBlockGroupTCAC$BlockHHsFiber,0),na.rm=TRUE)

#Sums the number of CA block groups that are low-fiber
sum(AllBlockGroupTCAC$Opportunity.Category == "Low Resource"& AllBlockGroupTCAC$PercentHH_fiber<=.294872,na.rm=TRUE)

#sums the number of CA households that are low fiber
sum(if_else(AllBlockGroupTCAC$Opportunity.Category == "Low Resource"& AllBlockGroupTCAC$PercentHH_fiber<=.294872, AllBlockGroupTCAC$households,0),na.rm=TRUE)

#Creates Bay Area County Table
HHbyCounty <- BayAreabgData %>% 
  group_by(CountyId) %>% 
  summarize(Households_in_County = sum(households, na.rm = TRUE),
            County_population = sum(total_pop, na.rm=TRUE),
            Total_tcac_under10_HH = sum(if_else(Opportunity.Category == "Low Resource" & BlockHHsUnder10>0, households,0),
                                               na.rm = TRUE),
            HH_Under10 = sum(if_else(Opportunity.Category == "Low Resource",BlockHHsUnder10,0),
                                          na.rm = TRUE),
            bg_under10=sum(Opportunity.Category=="Low Resource"& BlockHHsUnder10>0,na.rm=TRUE),
            BlackPopUnder10 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHsUnder10>0,total_pop*black_pct,0),na.rm=TRUE),
            WhitePopUnder10 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHsUnder10>0,total_pop*white_pct,0),na.rm=TRUE),
            HispanicPopUnder10 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHsUnder10>0,total_pop*hispanic_pct,0),na.rm=TRUE),
            TotalPopUnder10 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHsUnder10>0,total_pop,0),na.rm=TRUE),
            Total_tcac_10to25_HH = sum(if_else(Opportunity.Category == "Low Resource" & BlockHHs10_25>0, households,0),
                                        na.rm = TRUE),
            HH_10_25 = sum(if_else(Opportunity.Category == "Low Resource",BlockHHs10_25,0),
                                        na.rm = TRUE),
            BlackPop10to25 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHs10_25>0,total_pop*black_pct,0),na.rm=TRUE),
            WHitePop10to25 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHs10_25>0,total_pop*white_pct,0),na.rm=TRUE),
            HispanicPop10to25 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHs10_25>0,total_pop*hispanic_pct,0),na.rm=TRUE),
            TotalPop10to25 = sum(if_else(Opportunity.Category == "Low Resource"& BlockHHs10_25>0,total_pop,0),na.rm=TRUE),
            BG_10_25= sum(Opportunity.Category == "Low Resource"& BlockHHs10_25>0,na.rm=TRUE),
            Total_tcac_Fiber_HH = sum(if_else(Opportunity.Category == "Low Resource", households,0),
                                        na.rm = TRUE),
            HH_LowFiber = sum(if_else(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,BlockHHsFiber,0),
                                           na.rm = TRUE),
            BlackPopLowFiber = sum(if_else(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,total_pop*black_pct,0),na.rm=TRUE),
            WHitePopLowFiber = sum(if_else(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,total_pop*white_pct,0),na.rm=TRUE),
            HispanicPopLowFiber = sum(if_else(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,total_pop*hispanic_pct,0),na.rm=TRUE),
            TotalPopLowFiber = sum(if_else(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,total_pop,0),na.rm=TRUE),
            BG_LowFiber = sum(Opportunity.Category == "Low Resource"& PercentHH_fiber<=.294872,na.rm=TRUE)),
            BlackPopinCounty = sum(total_pop*black_pct, na.rm=TRUE),
            WhitePopinCounty = sum(total_pop*white_pct, na.rm=TRUE),
            HispanicPopinCounty = sum(total_pop*hispanic_pct, na.rm=TRUE)
  )
HHbyCounty <- adorn_totals(HHbyCounty,"row")
#combines county information for county names
HHbyCounty <- left_join(HHbyCounty,BayAreaCounties, by = "CountyId")
HHbyCounty <- HHbyCounty %>% 
  mutate(
    PercentHH_Under10 = (HH_Under10/Total_tcac_under10_HH)*100,
    PercentHH_10to25= (HH_10_25/Total_tcac_10to25_HH)*100,
    PercentHH_LowFiber = (HH_LowFiber/Total_tcac_Fiber_HH)*100,
    blackPopPctUnder10 = (BlackPopUnder10/TotalPopUnder10)*100,
    whitePopPctUnder10 = (WhitePopUnder10/TotalPopUnder10)*100,
    hispPopPctUnder10 = (HispanicPopUnder10/TotalPopUnder10)*100,
    BlackPopPct10to25 = (BlackPop10to25/TotalPop10to25)*100,
    WhitePopPct10to25 = (WHitePop10to25/TotalPop10to25)*100,
    HispPopPct10to25 = (HispanicPop10to25/TotalPop10to25)*100,
    BlackPopPctLowFiber = (BlackPopLowFiber/TotalPopLowFiber)*100,
    WHitePopPctLowFiber = (WHitePopLowFiber/TotalPopLowFiber)*100,
    HispanicPopPctLowFiber =(HispanicPopLowFiber/TotalPopLowFiber)*100,
    TotalBlackPctinCounty = (BlackPopinCounty/County_population)*100,
    TotalWhitePctinCounty = (WhitePopinCounty/County_population)*100,
    TotalHispanicPctinCounty = (HispanicPopinCounty/County_population)*100,
  )

HHbyCountyClean <- HHbyCounty %>% select(CountyId,CountyName,Households_in_County,County_population,
                                         TotalBlackPctinCounty,TotalWhitePctinCounty,TotalHispanicPctinCounty,
                                         PercentHH_Under10,blackPopPctUnder10,whitePopPctUnder10,hispPopPctUnder10,
                                         PercentHH_10to25,BlackPopPct10to25,WhitePopPct10to25,HispanicPop10to25,
                                         PercentHH_LowFiber,BlackPopPctLowFiber,WHitePopPctLowFiber,HispanicPopLowFiber)
  #subset (HHbyCounty, select =-c())
# HHbyCounty Notes
#Households_in_County = "Number of Households in the county",
   # TotalHH_Under10 = "Total number of households in tcac low opportunity block groups that contain at least one block with a household that has access to less than 10Mbps",
   # HH_Under10 = "Number of households with broadband under 10 Mbps",
   # TotalHH_10_25 = "Total number of households in tcac low opportunity block groups that contain at least one block with a household that has access to between 10 and 25Mbps",
   # HH_10_25 = "explaination",
   # TotalHH_Fiber ="explaination",
   # HH_LowFiber ="explination"


#--------------scatterplot function------------------------------
ScatterplotFunction <- function(data, xvar, yvar,title,filter_var = NULL){
    data <- BayAreabgData %>%
      filter(Opportunity.Category == "Low Resource",
             households > 0,
             {{yvar}} > 0)

  plot <- ggplot(data, aes(x = {{xvar}},y = {{yvar}},color=CountyName)) +
    geom_point()+
    labs(title=title)
  #Adds horizontal line for fiber charts
  if(!is.null(filter_var)){
    plot<- plot+ geom_hline(yintercept = 0.294872, linetype ="dashed")
  }
  return(plot)
}
#---------------------------Scatter plots for under 10 Mbps --------------------------
BroadbandUnder10mbps <- ScatterplotFunction(data = BayAreabgData,
                                                 xvar = households,
                                                 yvar= PercentHH_under10,
                                                 title= "Percent Households with Broadband under 10mbps by Block Group")

ggsave("graphs/BroadbandUnder10mbps.png", plot=BroadbandUnder10mbps, width = 6, height =4, dpi =300)

WhiteBroadbandUnder10mbps <- ScatterplotFunction(data = BayAreabgData,white_pct,PercentHH_under10,"Percent under 10mbps and White Population")
BlackBroadbandUnder10mbps <- ScatterplotFunction(BayAreabgData,black_pct,PercentHH_under10,"Percent Under 10 and Black Population")
AsianBroadbandUnder10mbps <- ScatterplotFunction(BayAreabgData,asian_pct,PercentHH_under10,"Percent Under 10 and Asian Population")
american_indian_alaska_native_BroadbandUnder10mbps <- ScatterplotFunction(BayAreabgData,american_indian_alaska_native_pct,PercentHH_under10,"Percent Under 10 and American Indian/ alaska Native population")
hawaian_pacific_island_BroadbandUnder10mbps <- ScatterplotFunction(BayAreabgData,hawaian_pacific_island_pct,PercentHH_under10, "Percent Under 10 and Hawaian Pacific Island population")
hispanic_BroadbandUnder10mbps <- ScatterplotFunction(BayAreabgData,hispanic_pct,PercentHH_under10, "Percent under 10 and Hispanic population")

ggsave("graphs/WhiteBroadbandUnder10mbps.png", plot=WhiteBroadbandUnder10mbps, width = 6, height =4, dpi =300)
ggsave("graphs/BlackBroadbandUnder10mbps.png", plot=BlackBroadbandUnder10mbps, width = 6, height =4, dpi =300)
ggsave("graphs/AsianBroadbandUnder10mbps.png", plot=AsianBroadbandUnder10mbps, width = 6, height =4, dpi =300)
ggsave("graphs/american_indian_alaska_native_BroadbandUnder10mbps.png", plot=american_indian_alaska_native_BroadbandUnder10mbps, width = 6, height =4, dpi =300)
ggsave("graphs/hawaian_pacific_island_BroadbandUnder10mbps.png", plot=hawaian_pacific_island_BroadbandUnder10mbps, width = 6, height =4, dpi =300)
ggsave("graphs/hispanic_BroadbandUnder10mbps.png", plot=hispanic_BroadbandUnder10mbps, width = 6, height =4, dpi =300)

#-----------------------------Scatter plots for 10 to 25 Mbps------------------------------
Broadband10_25mbps <- ScatterplotFunction(data = BayAreabgData,
                                            xvar = households,
                                            yvar= PercentHH_10_25,
                                            title= "Percent Households with broadband 10 to 25mbps by Block Group")
ggsave("graphs/Broadband10_25mbps.png", plot=Broadband10_25mbps, width = 6, height =4, dpi =300)

WhiteBroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,white_pct,PercentHH_10_25,"Percent 10 to 25 Mbps and White population")
BlackBroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,black_pct,PercentHH_10_25,"Percent 10 to 25 Mbps and Black population")
AsianBroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,asian_pct,PercentHH_10_25,"Percent 10 to 25 Mbps and Asian population")
american_indian_alaska_native_BroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,american_indian_alaska_native_pct,PercentHH_10_25, "Percent 10 to 25 Mbps and American Indian/ alaska Native population")
hawaian_pacific_island_BroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,hawaian_pacific_island_pct,PercentHH_10_25, "Percent 10 to 25 Mbps and Hawaian Pacific Island population")
hispanic_BroadbandUnder10_25 <- ScatterplotFunction(BayAreabgData,hispanic_pct,PercentHH_10_25, "Percent 10 to 25 Mbps and Hispanic population")

ggsave("graphs/WhiteBroadbandUnder10_25.png", plot=WhiteBroadbandUnder10_25, width = 6, height =4, dpi =300)
ggsave("graphs/BlackBroadbandUnder10_25.png", plot=BlackBroadbandUnder10_25, width = 6, height =4, dpi =300)
ggsave("graphs/AsianBroadbandUnder10_25.png", plot=AsianBroadbandUnder10_25, width = 6, height =4, dpi =300)
ggsave("graphs/american_indian_alaska_native_BroadbandUnder10_25.png", plot=american_indian_alaska_native_BroadbandUnder10_25, width = 6, height =4, dpi =300)
ggsave("graphs/hawaian_pacific_island_BroadbandUnder10_25.png", plot=hawaian_pacific_island_BroadbandUnder10_25, width = 6, height =4, dpi =300)
ggsave("graphs/hispanic_BroadbandUnder10_25.png", plot=hispanic_BroadbandUnder10_25, width = 6, height =4, dpi =300)

#----------------------------------------Fiber----------------------------------------
Broadband_Fiber <- ScatterplotFunction(data = BayAreabgData,
                                          xvar = households,
                                          yvar= PercentHH_fiber,
                                          filter_var=BayAreabgData$BlockHHsFiber,
                                          title= "Percent Households with Fiber by Block Group")
ggsave("graphs/Broadband_Fiber.png", plot=Broadband_Fiber, width = 6, height =4, dpi =300)

White_Fiber <- ScatterplotFunction(BayAreabgData,white_pct,PercentHH_fiber,title= "Block Groups Household Percents with Fiber and White population",BayAreabgData$BlockHHsFiber)
Black_Fiber <- ScatterplotFunction(BayAreabgData,black_pct,PercentHH_fiber,"Block Groups Household Percents with Fiber and Black population",BayAreabgData$BlockHHs10_25)
Asian_Fiber<- ScatterplotFunction(BayAreabgData,asian_pct,PercentHH_fiber,"Block Groups Household Percents with Fiber and Asian population",BayAreabgData$BlockHHs10_25)
American_indian_alaska_native_Fiber <- ScatterplotFunction(BayAreabgData,american_indian_alaska_native_pct,PercentHH_fiber, "Block Groups Household Percents with Fiber and American Indian/ alaska Native population",BayAreabgData$BlockHHs10_25)
Hawaian_pacific_island_Fiber <- ScatterplotFunction(BayAreabgData,hawaian_pacific_island_pct,PercentHH_fiber, "Block Groups Household Percents with Fiber and Hawaian Pacific Island population",BayAreabgData$BlockHHs10_25)
Hispanic_Fiber <- ScatterplotFunction(BayAreabgData,hispanic_pct,PercentHH_fiber, "Block Groups Household Percents with Fiber and Hispanic population",BayAreabgData$BlockHHs10_25)

ggsave("graphs/White_Fiber.png", plot=White_Fiber, width = 6, height =4, dpi =300)
ggsave("graphs/Black_Fiber.png", plot=Black_Fiber, width = 6, height =4, dpi =300)
ggsave("graphs/Asian_Fiber.png", plot=Asian_Fiber, width = 6, height =4, dpi =300)
ggsave("graphs/American_indian_alaska_native_Fiber.png", plot=American_indian_alaska_native_Fiber, width = 6, height =4, dpi =300)
ggsave("graphs/Hawaian_pacific_island_Fiber.png", plot=Hawaian_pacific_island_Fiber , width = 6, height =4, dpi =300)
ggsave("graphs/Hispanic_Fiber.png", plot=Hispanic_Fiber, width = 6, height =4, dpi =300)

#----------------Exports workbook -------------------------
wb1 <- createWorkbook()
addWorksheet(wb1, sheetName = "Overview")
addWorksheet(wb1, sheetName = "Under10Mbps")
addWorksheet(wb1, sheetName = "10to25Mbps")
addWorksheet(wb1, sheetName = "Fiber")

writeData(wb1, sheet = "Overview", x=HHbyCountyClean, startRow = 1, startCol =1)
insertImage( wb1, sheet = "Overview", file="graphs/BroadbandUnder10mbps.png",width =6,height =4, startRow = 20, startCol =1)
insertImage( wb1, sheet = "Overview", file="graphs/Broadband10_25mbps.png",width =6,height =4, startRow = 40, startCol =1)
insertImage( wb1, sheet = "Overview", file="graphs/Broadband_Fiber.png",width =6,height =4, startRow = 60, startCol =1)

insertImage( wb1, sheet = "Under10Mbps", file="graphs/WhiteBroadbandUnder10mbps.png",width =6,height =4, startRow = 1, startCol =1)
insertImage( wb1, sheet = "Under10Mbps", file="graphs/BlackBroadbandUnder10mbps.png",width =6,height =4, startRow = 20, startCol =1)
insertImage( wb1, sheet = "Under10Mbps", file="graphs/AsianBroadbandUnder10mbps.png",width =6,height =4, startRow = 40, startCol =1)
insertImage( wb1, sheet = "Under10Mbps", file="graphs/american_indian_alaska_native_BroadbandUnder10mbps.png",width =6,height =4, startRow = 60, startCol =1)
insertImage( wb1, sheet = "Under10Mbps", file="graphs/hawaian_pacific_island_BroadbandUnder10mbps.png",width =6,height =4, startRow = 80, startCol =1)
insertImage( wb1, sheet = "Under10Mbps", file="graphs/hispanic_BroadbandUnder10mbps.png",width =6,height =4, startRow = 100, startCol =1)

insertImage( wb1, sheet = "10to25Mbps", file="graphs/WhiteBroadbandUnder10_25.png",width =6,height =4, startRow = 1, startCol =1)
insertImage( wb1, sheet = "10to25Mbps", file="graphs/BlackBroadbandUnder10_25.png",width =6,height =4, startRow = 20, startCol =1)
insertImage( wb1, sheet = "10to25Mbps", file="graphs/AsianBroadbandUnder10_25.png",width =6,height =4, startRow = 40, startCol =1)
insertImage( wb1, sheet = "10to25Mbps", file="graphs/american_indian_alaska_native_BroadbandUnder10_25.png",width =6,height =4, startRow = 60, startCol =1)
insertImage( wb1, sheet = "10to25Mbps", file="graphs/hawaian_pacific_island_BroadbandUnder10_25.png",width =6,height =4, startRow = 80, startCol =1)
insertImage( wb1, sheet = "10to25Mbps", file="graphs/hispanic_BroadbandUnder10_25.png",width =6,height =4, startRow = 100, startCol =1)

insertImage( wb1, sheet = "Fiber", file="graphs/White_Fiber.png",width =6,height =4, startRow = 1, startCol =1)
insertImage( wb1, sheet = "Fiber", file="graphs/Black_Fiber.png",width =6,height =4, startRow = 20, startCol =1)
insertImage( wb1, sheet = "Fiber", file="graphs/Asian_Fiber.png",width =6,height =4, startRow = 40, startCol =1)
insertImage( wb1, sheet = "Fiber", file="graphs/American_indian_alaska_native_Fiber.png",width =6,height =4, startRow = 60, startCol =1)
insertImage( wb1, sheet = "Fiber", file="graphs/Hawaian_pacific_island_Fiber.png",width =6,height =4, startRow = 80, startCol =1)
insertImage( wb1, sheet = "Fiber", file="graphs/Hispanic_Fiber.png",width =6,height =4, startRow = 100, startCol =1)

saveWorkbook(wb1,"graphs/BroadbandResults.xlsx", overwrite = TRUE)

