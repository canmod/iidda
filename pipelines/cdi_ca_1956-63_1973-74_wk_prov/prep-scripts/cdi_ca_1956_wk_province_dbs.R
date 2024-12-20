## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_ca_1956_wk_prov_dbs"
digitization = "cdi_ca_1956_wk_prov_dbs"
metadata_path = "pipelines/cdi_ca_1956-63_1973-74_wk_prov/tracking"
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
#remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(iidda)
library(dplyr)
library(tidyxl)
library(unpivotr)
library(tidyr)
library(zoo)
library(lubridate)
library(stringr)


# Transformation-Specific Functions and objects

get_sheet_names = function(data) {
  grep("^w[0-9]+", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  (data
   %>% filter(sheet == focal_sheet, between(row, 5, 35), between(col, 2, 38))
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

  subclass_pattern = '\\([a-z]{1}\\)'
  legend = data.frame(
    character = c('.',              '..',            '-'  ),
    key =       c('Not available', 'Not reportable', '0'  )
  )

  (beheaded_sheet

    # ------------------------------------------------------------------------
    # different missing value types
    %>% mutate(character = trimws(character))
    %>% left_join(legend, by = "character")
    %>% mutate(numeric = as.character(numeric))
    %>% mutate(numeric = ifelse(
        (
            character %in% '-'
          | character %in% '.'
          | character %in% '..'
          | !is.na(character)
        ),
        key,
        numeric
      )
    )

    # ------------------------------------------------------------------------
    # pull out disease subclasses
    %>% mutate(is_subclass = grepl(subclass_pattern, disease))
    %>% mutate(disease_subclass = ifelse(is_subclass, disease, ''))
    %>% mutate(disease_subclass = sub(subclass_pattern, '', disease_subclass))
    %>% mutate(disease_subclass = na_if(disease_subclass, ''))
    %>% mutate(disease = ifelse(is_subclass, NA, disease))
    %>% mutate(disease = na.locf(disease, na.rm = FALSE))
    # ------------------------------------------------------------------------

    %>% mutate(location = na.locf(location, na.rm = FALSE))

    # ------------------------------------------------------------------------
    # clean cases
    # ------------------------------------------------------------------------
    # fixme: shouldn't need this first step if all cells are character
    %>% mutate(cases = ifelse(is.na(numeric), character, as.character(numeric)))
    %>% separate(cases, c('cases', 'legend'), sep = "\\(", extra = "drop", fill = "right")
    %>% mutate(cases = trimws(cases))
    # todo: decide if we want to pull out revised flags for each case stat
    #%>% mutate(cases = as.numeric(gsub('[^0-9]', '', cases)))
    %>% mutate(cases = gsub('r$', '', cases))
    %>% mutate(cases = gsub('\\-', '0', cases))

    # ------------------------------------------------------------------------
    # give each case statistic a separate column
    %>% mutate(stat_name_1 = na.locf(stat_name_1, na.rm = FALSE))
    %>% mutate(cases_statistic = case_when(
      startsWith(stat_name_1, 'Report'      ) ~ 'this_period',
      startsWith(stat_name_1, '(8 )Report'  ) ~ 'this_period',
      startsWith(stat_name_1, '(8) Report'  ) ~ 'this_period',
      startsWith(stat_name_1, ' (9) Report' ) ~ 'this_period',
      startsWith(stat_name_1, '(9) Report'  ) ~ 'this_period',
      startsWith(stat_name_1, 'Previous'    ) ~ 'prev_period',
      startsWith(stat_name_1, '(8) Previous') ~ 'prev_period',
      startsWith(stat_name_2, '1956'        ) ~ 'cum_report_year',
      startsWith(stat_name_2, '1955'        ) ~ 'cum_prev_year',
      startsWith(stat_name_1, 'Median'      ) ~ 'median_prev_5_years',
      startsWith(stat_name_2, 'Median'      ) ~ 'cum_median_prev_5_years'
    ))

    %>% mutate(cases_statistic = paste0('cases_', cases_statistic))
    %>% relocate(cases, .after = last_col())
    %>% filter(!is.na(cases))
    %>% pivot_wider(id_cols = c(location, disease, disease_subclass),
                    names_from = cases_statistic,
                    values_from = cases)

    # ------------------------------------------------------------------------
    # remove superscripts associated with legend
    # mutate(disease_footnote = str_extract(disease, "\\d"))
    # mutate(disease_subclass_footnote = str_extract(disease_subclass, "\\d"))
    %>% mutate(location = sub('[0-9].*', '', location))
    %>% mutate(disease = sub('[0-9].*', '', disease))
    %>% mutate(disease = gsub('\\:', '', disease))
    %>% mutate(disease_subclass = sub('[0-9].*', '', disease_subclass))
    %>% mutate(location = trimws(location))
    %>% mutate(disease = trimws(disease))
    %>% mutate(disease_subclass = trimws(disease_subclass))

    # ------------------------------------------------------------------------

    %>% mutate(disease_subclass = sub("'' secondary", "Syphilis, secondary", disease_subclass))
    %>% mutate(disease_subclass = sub("'' other", "Syphilis, other", disease_subclass))
    # ------------------------------------------------------------------------
  )
}

combine_weeks = function(cleaned_sheets, sheet_dates, metadata) {
  (cleaned_sheets
   %>% bind_rows(.id = "sheet")
   %>% left_join(sheet_dates, by = "sheet")
   %>% select(-sheet)
   %>% relocate(disease, .after = location)
   %>% relocate(disease_subclass, .after = disease)
   %>% relocate(cases_this_period, .after = disease_subclass)
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
   %>% rename(historical_disease = disease, historical_disease_subclass = disease_subclass)

# AUTO-COMMENT-OUT    %>% add_metadata(metadata$TidyDataset, metadata$Columns[[tidy_dataset]])
   %>% empty_to_na)
}

get_periods = function(sheets, data, metadata) {
  (data
   %>% filter(address == "A4", sheet %in% sheets)
   %>% select(sheet, character)
   %>% rename(end_date = character)
   %>% mutate(end_date = sub(
     "^for the week ended ",
     "", end_date))
   %>% mutate(end_date = gsub(
     "\\, in.*",
     "", end_date))
   %>% mutate(end_date = mdy(trimws(end_date)))
   %>% mutate(start_date =
                end_date - days(freq_to_days(metadata$Source$frequency) - 1))
   %>% rename(period_end_date = end_date, period_start_date = start_date)
   %>% relocate(period_start_date, .before = period_end_date)
  )
}

get_footnote_defs = function(data) {
  (data
   |> filter(address == "A36")
   |> select(sheet, character)
   |> rename(footnote = character)
   |> separate_wider_delim(footnote, regex(" \\([0-9]\\)"), names_sep = "_")
   |> mutate(footnote_1 = sub("^\\(1\\)", "", footnote_1))
   |> pivot_longer(starts_with("footnote_"))
   |> mutate(number = sub("^footnote_", "", name))
   |> mutate(footnote = trimws(value))
   |> select(-name, -value)
  )
}

# Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

footnote_defs = get_footnote_defs(data) # local -- not currently used. for info only.

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = lapply(beheaded_sheets, clean_sheets, metadata) # local

sheet_dates = get_periods(sheets, data, metadata) # local

tidy_data = combine_weeks(cleaned_sheets, sheet_dates, metadata) # local

tidy_data = add_provenance(tidy_data, tidy_dataset) # iidda

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
