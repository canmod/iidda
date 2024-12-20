# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_man_2006_mn"
digitization = "cdi_man_2006_mn"
metadata_path = 'project_tracking'
# ----------------------------------------

options(conflicts.policy = list(warn.conflicts = FALSE))
#remotes::install_github('canmod-eidm/iidda-tools', subdir = 'R/iidda')
library(iidda)
library(dplyr)
library(unpivotr)
library(lubridate)

all_disease_names = function(data) {
  (data
    |> filter(col == 2)
    |> pull(character)
    |> unique()
    |> grep(pattern = "^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)", value = TRUE, invert = TRUE)
    |> grep(pattern = "^Mean", value = TRUE, invert = TRUE)
    |> grep(pattern = "^Data", value = TRUE, invert = TRUE)
    |> grep(pattern = "^(DISEASE/INFECTION)", value = TRUE, invert = TRUE)
    |> grep(pattern = "^(Disease Name)", value = TRUE, invert = TRUE)
    |> sort()
  )
}

get_sheet_names = function(data) {
  grep("^Page", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  # Extract the page number from the focal_sheet
  page_number = as.numeric(gsub("Page ", "", focal_sheet))
  data = filter(data, sheet == focal_sheet)
  missing_cells = anti_join(
      as_cells(cell_block(data))
    , data
    , by = c("row", "col")
  )
  data = (data
    |> bind_rows(missing_cells)
    |> arrange(row, col)
  )
  disease_rows = (data
    |> filter(col == 2, character %in% all_diseases)
    |> summarise(
          last_row = max(row)
        , last_disease = character[which.max(row)]
        , first_row = min(row)
        , first_disease = character[which.min(row)]
    )
  )
  contains_total = (data
    |> filter(row == disease_rows$last_row + 1, col == 2)
    |> pull(character)
    |> iidda::is_empty()
  )

  (data
    |> filter(
        between(row, disease_rows$first_row - 1L, disease_rows$last_row + as.integer(contains_total))
      , between(col, 1, 8))
    |> select(row, col, data_type, numeric, character)
    |> behead('N', stat_name)
    |> behead('W', icd_9)
    |> behead('W', historical_disease)
  )
}

clean_sheets = function(beheaded_sheet){
  (beheaded_sheet
   |> mutate(cases = case_when(
     !is_empty(numeric) ~ as.character(numeric),
     !is_empty(character) ~ character,
     TRUE ~ '0'
   ))

   |> mutate(cases_statistic = case_when(
     stat_name == 2005 & col < 5 ~ 'cases_this_period',
     stat_name == 2005 & col >= 5 ~ 'cases_cum_prev_year',
     stat_name == 2006 & col >= 5 ~ 'cases_cum_report_year',
     grepl('^Exp', stat_name) ~ 'mean_15_mo',
     grepl('^Ex.', stat_name) ~ 'mean_range',
     TRUE ~ NA_character_))

   |> filter(!is.na(cases_statistic))

   |> pivot_wider(id_cols = c(historical_disease, icd_9),
                  names_from = cases_statistic,
                  values_from = cases)

   |> mutate(icd_9 = as.character(icd_9))

  )
}


calculate_period_dates = function(focal_sheet, data, last_start_date = NULL, last_end_date = NULL) {

  period = filter(data, sheet == focal_sheet, row == 1)
  date_string = grep('2006$', period$character, value = TRUE)

  if (length(date_string) == 0) {
    # If no date string is found, use the previous period dates
    period_start_date = last_start_date
    period_end_date = last_end_date
  } else {
    # Parse the date string and calculate the period dates
    date_parsed = dmy(paste0("01-", date_string))
    period_start_date = format(date_parsed, "%Y-%m-01")
    period_end_date = format(seq(date_parsed, by = "month", length = 2)[2] - days(1), "%Y-%m-%d")
  }

  return(list(period_start_date = period_start_date, period_end_date = period_end_date))
}

add_periods = function(sheets, data, cleaned_sheets) {
  last_start_date = NULL
  last_end_date = NULL

  for (focal_sheet in sheets) {
    # Calculate the period dates for the current sheet
    period_dates = calculate_period_dates(focal_sheet, data, last_start_date, last_end_date)

    # Update the cleaned_sheets for the current focal_sheet
    cleaned_sheets[[focal_sheet]] = (
      cleaned_sheets[[focal_sheet]]
      %>% mutate(period_start_date = period_dates$period_start_date,
                 period_end_date = period_dates$period_end_date)
    )

    # Update the last known dates for the next iteration
    last_start_date = period_dates$period_start_date
    last_end_date = period_dates$period_end_date
  }

  tidy_data = (cleaned_sheets
               %>% bind_rows()
               %>% mutate(location = 'Manitoba')
               %>% select(location, icd_9, historical_disease, period_start_date, period_end_date,
                          cases_this_period, cases_cum_report_year, cases_cum_prev_year)

               %>% mutate(across(starts_with("cases"), ~ ifelse(is.na(.) | . == "", 0, .)))

               %>% mutate(historical_disease = ifelse(
                 is.na(historical_disease),
                 'all_diseases',
                 historical_disease))

               %>% identify_scales() # iidda

               %>% add_provenance(tidy_dataset) # iidda
  )

  return(tidy_data)
}


# Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda # FIXME: include_blank_cells = TRUE in xlsx_cells?

all_diseases = all_disease_names(data)

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = lapply(beheaded_sheets, clean_sheets) # local

tidy_data = add_periods(sheets, data, cleaned_sheets) # local

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda

