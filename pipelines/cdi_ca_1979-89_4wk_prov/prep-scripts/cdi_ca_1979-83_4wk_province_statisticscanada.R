## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_ca_1979-83_4wk_prov_statcan"
digitization = "cdi_ca_1979-83_4wk_prov_statcan"
metadata_path = "pipelines/cdi_ca_1979-89_4wk_prov/tracking"
# ----------------------------------------


options(conflicts.policy = list(warn.conflicts = FALSE))
# remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(iidda)
library(dplyr)
library(tidyxl)
library(unpivotr)
library(tidyr)
library(zoo)
library(lubridate)


# Transformation-Specific Functions and objects

get_sheet_names = function(data) {
  grep("[0-9]+", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  (data
   %>% filter(sheet == focal_sheet, between(row, 4, 47), between(col, 2, 42))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', location   )
   %>% behead('N', stat_name_1)
   %>% behead('N', stat_name_2)
   %>% behead('W', disease)
   %>% behead('W', icd)
   # TODO: %>% behead("E", french_disease) -- should fix issue #16
  )
}

clean_sheets = function(
  beheaded_sheet, metadata
) {

  subclass_pattern = '.* - '
  legend = data.frame(character = c('.', '..', '-'), key = c('Not reportable', 'Not available', 0))

  (beheaded_sheet

    # ------------------------------------------------------------------------
    # different missing value types
    %>% mutate(character = trimws(character))
    %>% left_join(legend, by = "character")
    %>% mutate(numeric = as.character(numeric))
    %>% mutate(numeric = ifelse(character %in% '-' | character %in% '.' | character %in% '..'| !is.na(character),
                                key, numeric))

    # ------------------------------------------------------------------------
    # pull out disease subclasses
    %>% mutate(is_subclass = grepl(subclass_pattern, disease))
    %>% separate(disease, c('disease', 'disease_subclass'), sep = " - ", extra = "drop", fill = "right")
    %>% mutate(disease_subclass = na_if(disease_subclass, ''))
    %>% mutate(disease = na.locf(disease, na.rm = FALSE))
    # ------------------------------------------------------------------------

    %>% mutate(location = na.locf(location, na.rm = FALSE))

    # ------------------------------------------------------------------------
    # clean cases
    # ------------------------------------------------------------------------
    # fixme: shouldn't need this first step if all cells are character
    %>% mutate(cases = ifelse(is.na(numeric), character, as.character(numeric)))
    %>% mutate(cases = trimws(cases))
    # todo: decide if we want to pull out revised flags for each case stat
    #%>% mutate(revised = grepl('r$', cases))
    #%>% mutate(cases = as.numeric(gsub('[^0-9]', '', cases)))
    %>% mutate(cases = gsub('r$', '', cases))
    %>% mutate(cases = gsub('\\*+', '', cases))
    %>% mutate(cases = gsub('\\?+', '', cases))

    # ------------------------------------------------------------------------
    # icd codes
    %>% rename(icd_9 = icd)
    %>% mutate(icd_9_subclass = ifelse(is_subclass==FALSE, NA, icd_9))
    %>% mutate(icd_9 = ifelse(is_subclass, NA, icd_9))
    %>% mutate(icd_9_subclass = as.character(icd_9_subclass))

    # ------------------------------------------------------------------------
    # give each case statistic a separate column
    %>% mutate(stat_name_2 = as.character(stat_name_2))
    %>% mutate(cases_statistic = case_when(
      startsWith(stat_name_1, 'Current'  ) ~ 'this_period',
      (startsWith(stat_name_1, 'Total'   ) & startsWith(stat_name_2, '1979')) ~ 'cum_report_year',
      (startsWith(stat_name_1, 'Total'   ) & startsWith(stat_name_2, '1980')) ~ 'cum_report_year',
      (startsWith(stat_name_1, 'Total'   ) & startsWith(stat_name_2, '1981')) ~ 'cum_report_year',
      (startsWith(stat_name_1, 'Total'   ) & startsWith(stat_name_2, '1982')) ~ 'cum_report_year',
      (startsWith(stat_name_1, 'Total'   ) & startsWith(stat_name_2, '1983')) ~ 'cum_report_year',
      (is.na(stat_name_1) & startsWith(stat_name_2, '1978')) ~ 'cum_prev_year',
      (is.na(stat_name_1) & startsWith(stat_name_2, '1979')) ~ 'cum_prev_year',
      (is.na(stat_name_1) & startsWith(stat_name_2, '1980')) ~ 'cum_prev_year',
      (is.na(stat_name_1) & startsWith(stat_name_2, '1981')) ~ 'cum_prev_year',
      (is.na(stat_name_1) & startsWith(stat_name_2, '1982')) ~ 'cum_prev_year'
    ))

    %>% mutate(cases_statistic = paste0('cases_', cases_statistic))
    %>% relocate(cases, .after = last_col())
    %>% filter(!is.na(cases))
    %>% pivot_wider(id_cols = c(location, disease, disease_subclass, icd_9, icd_9_subclass),
                    names_from = cases_statistic,
                    values_from = cases)

    # ------------------------------------------------------------------------
    # remove numbers in brackets associated with legend
    %>% mutate(disease = sub('\\([0-9].*)', '', disease))
    %>% mutate(disease_subclass = sub('\\([0-9].*)', '', disease_subclass))
    # ------------------------------------------------------------------------
  )
}

combine_weeks = function(cleaned_sheets, sheet_dates, metadata) {
  (cleaned_sheets
   %>% bind_rows(.id = "sheet")
   %>% left_join(sheet_dates, by = "sheet")
   %>% select(-sheet)
   %>% relocate(icd_9, .after = disease)
   %>% relocate(icd_9_subclass, .after = disease_subclass)
   %>% relocate(cases_this_period, .after = icd_9_subclass)
   %>% relocate(cases_cum_report_year, .after = cases_this_period)
   %>% relocate(cases_cum_prev_year, .after = cases_cum_report_year)
   %>% relocate(period_end_date, .after = location)
   %>% relocate(period_start_date, .after = location)
   %>% as.data.frame
   %>% identify_scales()
   
   # changing column names to historical_disease 
   %>% rename(historical_disease = disease, historical_disease_subclass = disease_subclass)
   
# AUTO-COMMENT-OUT    %>% add_metadata(metadata$TidyDataset, metadata$Columns[[tidy_dataset]])
   %>% empty_to_na)
}

get_periods = function(sheets, data, metadata) {
  (data
   %>% filter(address == "A3", sheet %in% sheets)
   %>% select(sheet, character)
   %>% rename(end_date = character)
   %>% mutate(end_date = sub(
     "^New cases reported for the 4-week period ending ",
     "", end_date))
   %>% mutate(end_date = sub(
     "^NEW CASES REPORTED FOR THE FOUR WEEK PERIOD ENDING ",
     "", end_date))
   %>% mutate(end_date = mdy(trimws(end_date)))
   %>% mutate(start_date =
                end_date - days(freq_to_days(metadata$Source$frequency) - 1))
   %>% rename(period_end_date = end_date, period_start_date = start_date)
   %>% relocate(period_start_date, .before = period_end_date)
  )
}


# Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = lapply(beheaded_sheets, clean_sheets, metadata) # local

sheet_dates = get_periods(sheets, data, metadata) # local

tidy_data = combine_weeks(cleaned_sheets, sheet_dates, metadata) # local

tidy_data = add_provenance(tidy_data, tidy_dataset) # iidda

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda

