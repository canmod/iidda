## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "pop_ca_1921-71_an_age_prov_sex"
digitization = "pop_ca_1921-71_an_age_prov_sex"
metadata_path = "pipelines/pop_ca_1921-71_an_age_prov_sex/tracking"
# ----------------------------------------




options(conflicts.policy = list(warn.conflicts = FALSE))
#remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
#library(plyr)
library(tidyxl)
library(stringr)
library(dplyr)
library(iidda)
library(unpivotr)
library(zoo)
library(lubridate)

locations_iso = read_data_frame("lookup-tables/canmod-location-lookup.csv")

get_sheet_names = function(data) {
  grep("^19[0-9]{2}", unique(data$sheet), value = TRUE)
}

# 1971 sheet starts on row 11, all others start on row 6, so we need to run
# this function separately for 1971 since rowstart and empty_rows are different
make_tidy_data_part = function(focal_sheet, data, rowstart, rowend, empty_rows) {
  data2 = (data
     %>% filter(sheet == focal_sheet, between(row, rowstart, rowend), between(col, 1, 14))
     %>% select(row, col, data_type, numeric, character)
     %>% behead('N', location1)
     %>% behead('N', location2)
     %>% behead('N', location3)
     %>% behead('W', age_sex)

     %>% mutate(location2 = ifelse(location2 == '-', '', location2))
     %>% mutate(location1 = ifelse(is.na(location1), '', location1))
     %>% mutate(location2 = ifelse(is.na(location2), '', location2))
     %>% mutate(location3 = ifelse(is.na(location3), '', location3))

     %>% unite(., 'location', c(location1, location2), sep = '')
     %>% mutate(location = ifelse(is_empty(location), location3, location))
     %>% select(-location3)

     %>% iso_3166_codes(locations_iso)

     %>% filter(row!= empty_rows[[1]])
     %>% filter(row!= empty_rows[[2]])

    %>% mutate(age_sex = gsub("[.].*", "", age_sex))
    %>% mutate(sex = str_extract(age_sex, "[A-z]+"))
    %>% mutate(age_sex = trimws(age_sex))
    %>% mutate(lower_age = str_extract(age_sex, '^[0-9]{1,2}'))
    %>% mutate(upper_age = str_extract(age_sex, '[0-9]{1,2}$'))
    %>% mutate(upper_age = ifelse(is.na(upper_age), '', upper_age))
    %>% mutate(lower_age = ifelse(is.na(lower_age), '', lower_age))

    %>% mutate(sex = na.locf(sex))
    %>% filter(row!= empty_rows[[3]])
    %>% filter(row!= empty_rows[[4]])

    %>% mutate(population = ifelse(is_empty(numeric), character, numeric))
    %>% mutate(population = gsub(',', '', population))
    %>% mutate(population = ifelse(population == '-' | population == '--', 0, population))
    # Assuming that '-' means '0'

    %>% mutate(population = as.numeric(population))
    %>% mutate(population = population*1000)

    %>% mutate(sex = ifelse(sex == 'TOTAL', 'Both sexes', sex))
    %>% mutate(sex = ifelse(sex == 'Male', 'Males', sex))
    %>% mutate(sex = ifelse(sex == 'Female', 'Females', sex))

    %>% mutate(year = focal_sheet)
    %>% mutate(date = ymd(paste(year, '01','01', sep = '')))
  )
  (data2
    %>% mutate(age_group = ifelse(
      age_sex %in% c("TOTAL", "Male - Masculin", "Female - Féminin"),
      "All ages",
      age_sex
    ))
    %>% mutate(age_grouping_scheme = ifelse(
      age_group != "All ages",
      "5-year bins from 0-90+",
      ""
    ))
    %>% mutate(age_grouping_total = ifelse(
      age_group != "All ages",
      "All ages",
      ""
    ))
    %>% select(date
      , iso_3166, iso_3166_2, location
      , sex
      , age_group, age_grouping_scheme, age_grouping_total, lower_age, upper_age
      , population
    )
  )
  # (data2
  #   %>% mutate(age_group = if_else(
  #     (trimws(lower_age) == "") & (trimws(upper_age) == ""),
  #     "", age_sex
  #   ))
  # )
}

make_tidy_data = function(data, sheets) {
  n = length(sheets)
  tidy_data_1921_68 = sapply(sheets[1:n-1], make_tidy_data_part, data, rowstart = 6, rowend = 72, empty_rows = c(9,10,31,52), simplify = FALSE) # local
  tidy_data_1971 = sapply(sheets[n], make_tidy_data_part, data, rowstart = 11, rowend = 77, empty_rows = c(14,15, 36, 57), simplify = FALSE) # local
  tidy_sheet_data = c(tidy_data_1921_68, tidy_data_1971)
  select(bind_rows(tidy_sheet_data, .id = 'sheet'), -sheet) |> identify_scales(time_scale_identifier = force)
}


## Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

tidy_data = make_tidy_data(data, sheets) # local

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
