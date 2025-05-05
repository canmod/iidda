

# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_diarent_ca_1945-55_wk_prov"
digitization = "cdi_diarent_ca_1945-55_wk_prov"
metadata_path = "pipelines/cdi_ca_1924-55_wk_prov_dbs_statcan/tracking"
# ----------------------------------------
options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(plyr)
library(dplyr)
library(iidda)
library(tidyxl)
library(unpivotr)
library(tidyr)
library(zoo)
library(lubridate)
library(stringr)
library(purrr)

get_sheet_names =function(data){
  grep("^19[2-5]+[0-9]+", unique(data$sheet), value = TRUE)
}

# Extract year and disease info from each sheet. Format changes once Newfoundland is added (1950)
get_sheet_info = function(focal_sheet, data){
  year=(data
        %>% filter(row==2, sheet==focal_sheet)
        %>% .$character
        %>% grep('19[2-5]+[0-9]+', . ,value = TRUE))

  disease=(data
           %>% filter(address=='C2', sheet==focal_sheet)
           %>% .$character
  )

  nlist(year, disease)
}

behead_sheet = function(focal_sheet, data) {
  (data
   %>% filter(sheet == focal_sheet, between(row, 3, 59), between(col, 2, 24))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', location)
   %>% behead('N', stat_name)
   %>% behead('W', week_ending)
   %>% mutate(stat_name = ifelse(stat_name == 'mt', 'mo', stat_name))
   %>% mutate(fixed_statname=ifelse(is.na(location), 'mo', 'wk'))
   %>% mutate(stat_name=ifelse(is.na(stat_name), fixed_statname, stat_name))
   %>% select(-fixed_statname)
   %>% mutate(collection_year = focal_sheet)
  )
}

# For the years 1924-51, monthly totals are calculated over uneven months. This switches from 1952-55 to being calculated over 4 weekly periods.
# This function calculates what 4 weekly period each week_ending date falls in, and returns the start and end date for that period.
one_four_weekly_period = local({

  # Calculating the start date and end date of 4 weekly periods for 1953-55.
  startdate1952_53 = ymd(19520105) - 6 + days(28 * 0:26)
  startdate54_55 = ymd(19540131) + days(28*0:24)
  period_start_date = as.character(append(startdate1952_53, startdate54_55))

  enddate1952_53 = head(startdate1952_53, -1) + days(27)
  enddate1952_53 = append(enddate1952_53, ymd(19540130))
  enddate54_55 = startdate54_55 + days(27)
  period_end_date = as.character(append(enddate1952_53, enddate54_55))

  fourwkly_start_end = data.frame(period_start_date, period_end_date)
  fourwklydates = mutate(fourwkly_start_end, first_week_ending_date = as.Date(period_start_date)+6)
  fourwklydates = mutate(fourwklydates, last_week_ending_date = as.Date(period_end_date)+6)
  first_week_ending_date = pull(fourwklydates, first_week_ending_date)
  last_week_ending_date = pull(fourwklydates, last_week_ending_date)

  list(
    index = function(week_ending_date) {
      stopifnot(length(week_ending_date) == 1L)
      period_index = which((week_ending_date >= first_week_ending_date) & (week_ending_date <= last_week_ending_date))
    },
    start_date = function(period_index) {
      period_start_date[period_index]
    },
    end_date = function(period_index) {
      period_end_date[period_index]
    }
  )
})
four_weekly_period = lapply(one_four_weekly_period, Vectorize)

clean_sheet=function(beheaded_sheet, focal_sheet_info){
  clean_weeks = (beheaded_sheet
                 %>% filter(!grepl('^WK', week_ending))
                 %>% mutate(month=str_extract(week_ending, "[A-z]+"))
                 %>% mutate(day=str_extract(week_ending, "[1-3]?[0-9]{1}"))
                 %>% mutate(month=na.locf(month))
                 %>% unite(cases_this_period, c(numeric, character), sep='', na.rm=TRUE)
                 %>% mutate(location=na.locf(location))
                 
                 %>% filter(!is.na(week_ending))
                 
                 # Fixing case where months are abbreviated to 1 letter 
                 %>% mutate(month=case_when((month == "J" & row < 10) ~ 'Jan',
                                            (month == "F") ~ 'Feb',
                                            (month == "M" & row > 10 & row < 20) ~ 'Mar',
                                            (month =="A" & row > 15 & row < 25) ~ 'Apr',
                                            (month =="M" & row > 20 & row < 30) ~ 'May',
                                            (month =="J" & row > 25 & row <= 30) ~ 'Jun',
                                            (month =="J" & row > 30 & row < 40) ~ 'Jul',
                                            (month =="A" & row > 30 & row < 40) ~ 'Aug',
                                            (month =="S") ~ 'Sep',
                                            (month =="O") ~ 'Oct',
                                            (month =="N") ~ 'Nov',
                                            (month =="D") ~ 'Dec',
                                            TRUE ~ month)) 
                 
                 # Adding year and disease info from get_sheet_info function. 
                 %>% cbind(disease=focal_sheet_info$disease, year=focal_sheet_info$year)
                 
                 #  Fixing case where Jan 1, 1955 is included in 1954 sheet, and is mistakenly read as Jan 1 1954 instead of 1955. 
                 %>% mutate(year = ifelse(year == "1954" & week_ending == "Jan 1", '1955', year))
                 
                 %>% mutate(month=strtrim(.$month, 3))
                 %>% mutate(unite(.,'week_ending_date', c(day, month, year), sep=''))
                 
                 # %>% unite('week_ending_date', c(day, month, year), sep ='', remove=FALSE)
                 %>% mutate(week_ending_date=as.Date(week_ending_date, "%d%b%Y"))
                 
                 # Creating period_end_date for weekly and yearly periods.
                 %>% mutate(period_end_date=ifelse(stat_name == 'wk', as.character(week_ending_date), ''))
                 # Year end date
                 %>% mutate(period_end_date = ifelse(month == 'TOT', as.character(max(week_ending_date, na.rm=TRUE)), period_end_date))
                 
                 # Creating period_start_date incrementally like period_end_date.
                 %>% mutate(period_start_date=ifelse(stat_name=='wk', as.character(as.Date(period_end_date)-6), ''))
                 # Year start date
                 %>% mutate(period_start_date=ifelse(month=='TOT', as.character(min(as.Date(period_start_date), na.rm=TRUE)), period_start_date)) 
                 
                 # Manually fixing year start date for 1955, since Jan 1 1955 is included in 1954 sheet
                 %>% mutate(period_start_date = ifelse(period_start_date == '1954-12-26' & month == 'TOT', '1955-01-02', period_start_date))
  )
  
  # Week ending Jan 1 1955 is included in both 1954 and 1955 sheets
  # remove the 1955 one as  it has no case information
  if(as.numeric(focal_sheet_info$year) == 1955){
    clean_weeks = (clean_weeks
                   %>% filter(!((period_start_date == '1954-12-26' & period_end_date == '1955-01-01') | (period_start_date == '1954-12-05' & period_end_date == '1955-01-01')))
    )
  }
  
  # Month start dates for years less than 1952 are calculated differently than 1952-55. 
  if(as.numeric(focal_sheet_info$year) < 1952){
    clean_wkmt = 
      (clean_weeks
       %>% group_by(month)
       %>% mutate(month_end_date=ifelse(month!='TOT', as.character(max(week_ending_date, na.rm=TRUE)), ''))
       %>% ungroup()
       %>% mutate(period_end_date=ifelse(month!='TOT' & stat_name=='mo', month_end_date, period_end_date))# important!
       
       %>% group_by(month)
       %>% mutate(month_start_date=as.character(min(as.Date(period_start_date), na.rm=TRUE)))
       %>% ungroup()
       %>% mutate(period_start_date=ifelse(stat_name=='mo', month_start_date, period_start_date))
       
       %>% select(-month_start_date, -month_end_date)
      )
    
  }else{
    clean_wkmt = 
      (clean_weeks
       %>% mutate(index = ifelse(stat_name == 'mo', four_weekly_period$index(week_ending_date), ""))
       %>% mutate(period_start_date = ifelse(stat_name == 'mo' & month!= "TOT", as.character(four_weekly_period$start_date(index)), period_start_date))
       %>% mutate(period_end_date = ifelse(stat_name == 'mo'& month!= "TOT", as.character(four_weekly_period$end_date(index)), period_end_date))
       %>% select(-index)
      )
  }
  
  # Fixing issue of multiple yearly case totals 
  case1 = (clean_wkmt
           %>% filter(week_ending == 'TOTAL')
           %>% group_by(location)
           
           # if yearly case in both mt/wk column are the same, keep only one
           %>% filter(all(cases_this_period == first(cases_this_period)))
           %>% filter(!(stat_name == 'wk'))
           %>% ungroup()
  )
  
  case2 =  (clean_wkmt
            %>% filter(week_ending == 'TOTAL')
            %>% group_by(location)
            
            # if yearly case in wk/mt are different and one is empty, remove the empty one
            %>% filter(!all(cases_this_period == first(cases_this_period)))
            %>% filter(!(cases_this_period == '') & !(is.na(cases_this_period)))
            # if there are to unequal numbers in the wk and mt column , keep the larger number
            # the smaller number is likely due to weeks that are not available going into the total. 
            %>% filter(!(cases_this_period < suppressWarnings(max(cases_this_period, na.rm = TRUE))))
            %>% filter(!(n() > 1 & stat_name == 'wk'))
            %>% ungroup()
  )
  
  rbind(filter(clean_wkmt, week_ending != 'TOTAL'),
        case1,
        case2) %>% select(location, period_start_date, period_end_date, disease, cases_this_period, collection_year)
  
}

combine_sheets=function(cleaned_sheets){
  # Combining sheets.
  combined= (bind_rows(cleaned_sheets, .id='sheet')
             %>% select(-sheet)
             %>% mutate(period_start_date=as.Date(period_start_date), period_end_date=as.Date(period_end_date))
  )

  # Filtering out duplicated month values.
  monthly=(combined
           %>% filter(period_end_date - period_start_date > 7 & period_end_date - period_start_date < 35)
           %>% group_by(location, period_start_date, cases_this_period)
           %>% distinct()
           %>% ungroup()
           %>% empty_to_na()

           %>% group_by(location, period_start_date)
           # Sometimes monthly total is last value for the period, sometimes it is the first value; so need to na.nocb and na.locf.
           %>% mutate(cases_this_period = na.locf(cases_this_period, na.rm = FALSE, fromLast=TRUE))
           %>% mutate(cases_this_period = na.locf(cases_this_period, na.rm = FALSE))
           %>% distinct()
           %>% ungroup()
           %>% mutate(cases_this_period = ifelse(is.na(cases_this_period), '', cases_this_period))
  )   
  
  # Checking if there are multiple case totals for the same month
  check = select(monthly, location, period_start_date, collection_year)
  duplicatemonths = filter(monthly, duplicated(check)==TRUE)
  if(empty(duplicatemonths) == FALSE){ message("Warning: the following multiple case totals have been included for the same month")
    print(duplicatemonths)}
  
  # Filtering for only weekly and yearly (and quarterly) data; to be joined back with cleaned monthly data.   
  data_notmonthly = (combined
                     %>% filter(!period_end_date - period_start_date > 7 | !period_end_date - period_start_date < 35)
  )
  
  rbind(data_notmonthly, monthly) %>% rename(historical_disease = disease)
}

missing_values = function(data){
  # locations which have no data for an entire year are removed since there is so little data
  # causing it to be difficult to tell whether empty cells are 0 or not available. 
  filtered_data <- data %>%
    group_by(location, year = format(as.Date(period_end_date), "%Y")) %>%
    filter(!all(cases_this_period == '')) %>%
    ungroup() %>% select(-year)
  
  (filtered_data
    # In 1952, there are weekly cases but no monthly cases in all locations --> make monthly = not available
    %>% mutate(
      cases_this_period = ifelse(
        time_scale == 'mo' 
        & as.Date(period_end_date, format="%B %d %Y") >= as.Date("January 5 1952", format="%B %d %Y") &
          as.Date(period_end_date, format="%B %d %Y") <= as.Date("December 27 1952", format="%B %d %Y"),
        'Not available',
        cases_this_period
      ))
    
    # Convert '-' to 0
    %>% mutate(cases_this_period = ifelse(cases_this_period %in% c("-", '—'), 0, cases_this_period))
    
    # Otherwise assume empty = 0
    %>% mutate(cases_this_period = ifelse(cases_this_period == "", 0, cases_this_period))
  )
}

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

sheet_info = sapply(sheets, get_sheet_info, data=data, simplify=FALSE) # local

cleaned_sheets = mapply(clean_sheet, beheaded_sheets, sheet_info, SIMPLIFY=FALSE) # local

tidy_data = combine_sheets(cleaned_sheets) # local

data_with_scales = identify_scales(tidy_data) # iidda

complete_data = missing_values(data_with_scales) # local

complete_data = add_provenance(complete_data, tidy_dataset) # iidda

metadata = add_column_summaries(complete_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(complete_data, metadata) # iidda
file.path("pipelines", "cdi_ca_1924-55_wk_prov_dbs_statcan", "prep-scripts", "week-not-stated.R") |> source()
week_not_stated(beheaded_sheets)
