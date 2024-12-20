## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_ca_1970_wk_prov"
digitization = "cdi_ca_1970_wk_prov"
metadata_path = "pipelines/cdi_ca_1968-72_wk_prov/tracking"
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
  grep("^wk[0-9]+", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  (data
   %>% filter(sheet == focal_sheet, between(row, 3, 35), between(col, 2, 56))
   %>% select(row, col, data_type, numeric, character)
   %>% behead('N', location)
   %>% behead('N', stat_name_1)
   %>% behead('N', stat_name_2)
   %>% behead('W', disease)
   # TODO: %>% behead("E", french_disease) -- should fix issue #16
  )
}

clean_sheets = function(
  beheaded_sheet, metadata
) {

  icd_pattern = metadata$Columns[[1]]['icd_7', 'pattern']
  subclass_pattern = '^ {3}[A-Za-z]'
  family_row = filter(beheaded_sheet, row == c(6, 16, 21, 27, 32))
  family_name =  unique(family_row$disease)
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
    %>% mutate(disease_subclass = ifelse(is_subclass, disease, ''))
    %>% mutate(disease_subclass = na_if(disease_subclass, ''))
    %>% mutate(disease = ifelse(is_subclass, NA, disease))
    %>% mutate(disease = na.locf(disease, na.rm = FALSE))
    %>% mutate(disease_subclass = trimws(disease_subclass, which = c("left")))

    # ------------------------------------------------------------------------
    # pull out disease families
    %>% mutate(is_family_1 = grepl(family_name[1], disease))
    %>% mutate(is_family_2 = grepl(family_name[2], disease))
    %>% mutate(is_family_3 = grepl(family_name[3], disease))
    %>% mutate(is_family_4 = grepl(family_name[4], disease))
    %>% mutate(is_family_5 = grepl(family_name[5], disease))
    %>% mutate(disease_family_1 = ifelse(is_family_1, disease, ''))
    %>% mutate(disease_family_2 = ifelse(is_family_2, disease, ''))
    %>% mutate(disease_family_3 = ifelse(is_family_3, disease, ''))
    %>% mutate(disease_family_4 = ifelse(is_family_4, disease, ''))
    %>% mutate(disease_family_5 = ifelse(is_family_5, disease, ''))
    %>% unite(disease_family, c(disease_family_1, disease_family_2, disease_family_3, disease_family_4, disease_family_5), sep = "")
    %>% mutate(disease_family = na_if(disease_family, ''))
    %>% mutate(disease = ifelse(is_family_1, NA, disease))
    %>% mutate(disease = ifelse(is_family_2, NA, disease))
    %>% mutate(disease = ifelse(is_family_3, NA, disease))
    %>% mutate(disease = ifelse(is_family_4, NA, disease))
    %>% mutate(disease = ifelse(is_family_5, NA, disease))
    %>% mutate(disease = na.locf(disease, na.rm = FALSE))
    %>% mutate(disease_family = na.locf(disease_family, na.rm = FALSE))
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
    %>% mutate(cases = gsub('\\-', '0', cases))

    # ------------------------------------------------------------------------
    # give each case statistic a separate column
    %>% mutate(stat_name_1 = na.locf(stat_name_1, na.rm = FALSE))
    %>% mutate(cases_statistic = case_when(
      startsWith(stat_name_2, 'Current'    ) ~ 'this_period',
      startsWith(stat_name_2, 'Previous'   ) ~ 'prev_period',
      startsWith(stat_name_2, '1970'       ) ~ 'cum_report_year',
      startsWith(stat_name_2, '1969'       ) ~ 'cum_prev_year',
      (startsWith(stat_name_1, 'Week'      ) & startsWith(stat_name_2, 'Median'  )) ~ 'median_prev_5_years',
      (startsWith(stat_name_1, 'Cumulative') & startsWith(stat_name_2, 'Median'  )) ~ 'cum_median_prev_5_years'
    ))

    %>% mutate(cases_statistic = paste0('cases_', cases_statistic))
    %>% relocate(cases, .after = last_col())
    %>% filter(!is.na(cases))
    %>% pivot_wider(id_cols = c(location, disease, disease_subclass, disease_family),
                    names_from = cases_statistic,
                    values_from = cases)
    # ------------------------------------------------------------------------

    %>% mutate(location = sub("CANADA", "Canada", location))

    # ------------------------------------------------------------------------
    # extract icd codes
    %>% mutate(icd_7 =
                 extract_between_paren(disease, contents_pattern = icd_pattern))
    %>% mutate(disease =
                 remove_between_paren(disease, contents_pattern = icd_pattern))
    %>% mutate(icd_7_subclass =
                 extract_between_paren(disease_subclass, contents_pattern = icd_pattern))
    %>% mutate(disease_subclass =
                 remove_between_paren(disease_subclass, contents_pattern = icd_pattern))
    %>% mutate(disease = trimws(disease))
    %>% mutate(disease_subclass = trimws(disease_subclass))
    %>% mutate(disease = sub('\\:$', '', disease))
    %>% relocate(icd_7, .after = disease)
    %>% relocate(icd_7_subclass, .after = disease_subclass)
    %>% mutate(icd_7_subclass = as.character(icd_7_subclass))

    # ------------------------------------------------------------------------
    # remove superscripts associated with legend
    %>% mutate(disease = sub('[0-9].*', '', disease))
    %>% mutate(disease_subclass = sub('[0-9].*', '', disease_subclass))
    %>% mutate(icd_7 = ifelse(disease == "Other  (", "099.0, 099.1, 099.2", icd_7)) # 2 numbers in brackets, first is not icd code
    %>% mutate(disease = ifelse(disease == "Other  (", "Other", disease)) # 2 numbers in brackets, first is not icd code
    # ------------------------------------------------------------------------
  )
}

combine_weeks = function(cleaned_sheets, sheet_dates, metadata) {
  (cleaned_sheets
   %>% bind_rows(.id = "sheet")
   %>% left_join(sheet_dates, by = "sheet")
   %>% select(-sheet)
   %>% relocate(disease_family, .after = location)
   %>% relocate(cases_this_period, .after = icd_7_subclass)
   %>% relocate(cases_prev_period, .after = cases_this_period)
   %>% relocate(cases_cum_report_year, .after = cases_prev_period)
   %>% relocate(cases_cum_prev_year, .after = cases_cum_report_year)
   %>% relocate(cases_median_prev_5_years, .after = cases_cum_prev_year)
   %>% relocate(cases_cum_median_prev_5_years, .after = cases_median_prev_5_years)
   %>% relocate(period_end_date, .after = location)
   %>% relocate(period_start_date, .after = location)
   %>% as.data.frame
   %>% identify_scales()
   
   # changing column names to historical_disease 
   %>% rename(historical_disease = disease, historical_disease_subclass = disease_subclass, historical_disease_family = disease_family)
   
# AUTO-COMMENT-OUT    %>% add_metadata(metadata$TidyDataset, metadata$Columns[[tidy_dataset]])
   %>% empty_to_na)
}

get_periods = function(sheets, data, metadata) {
  (data
   %>% filter(address == "A2", sheet %in% sheets)
   %>% select(sheet, character)
   %>% rename(end_date = character)
   %>% mutate(end_date = sub(
     "^New Cases of Notifiable Diseases Reported, Week Ended ",
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
