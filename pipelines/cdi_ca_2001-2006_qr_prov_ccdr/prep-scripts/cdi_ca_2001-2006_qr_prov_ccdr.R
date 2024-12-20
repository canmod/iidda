
# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "cdi_ca_2001-2006_qr_prov_ccdr"
digitization = "cdi_ca_2001-2006_qr_prov_ccdr"
metadata_path = "pipelines/cdi_ca_2001-2006_qr_prov_ccdr/tracking"
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

get_sheet_names = function(data) {
  grep("^Page", unique(data$sheet), value = TRUE)
}

behead_sheet = function(focal_sheet, data) {
  page_number = as.numeric(gsub("Page ", "", focal_sheet))
  data = filter(data, sheet == focal_sheet)
  (data
    |> filter(
      between(row,
              min(data$row[grepl("^Disease*", data$character) & data$col == 1]),
              min(data$row[grepl("^Yellow*", data$character) & data$col == 1])),
      between(col, 1, 25))
    |> select(row, col, data_type, numeric, character)
    |> behead('N', location)
    |> behead('N', french_location)
    |> behead('N', stat_name_1)
    |> behead('N', stat_name_2)

    |> behead('W', historical_disease)
    |> behead('W', icd_9)

  )
}

clean_sheets = function(beheaded_sheet) {
  legend = data.frame(character = c('.', '..', '-', '..**'),
                      key = c('Not reportable', 'Not available', 0, 'Not available'))
  (beheaded_sheet
    # different missing value types
    %>% mutate(character = trimws(character))
    %>% left_join(legend, by = "character")
    %>% mutate(numeric = as.character(numeric))
    %>% mutate(numeric = ifelse(character %in% '-' | character %in% '.' | character %in% '..'| !is.na(character),
                                key, numeric))

   # %>% mutate(location = na.locf(location, na.rm = FALSE))

    %>% mutate(icd_9 = sub('\\*', '', icd_9))

    %>% filter(!(is.na(location)))

    %>% rename(cases_this_period = numeric)
    %>% mutate(historical_disease = sub(' -$', '', historical_disease))
    %>% mutate(historical_disease = gsub(" - .*", "", historical_disease))

    %>% mutate(location = sub('~$', '', location))
  )
}

calculate_period_dates = function(focal_sheet, data, cleaned_sheets, last_start_date = NULL, last_end_date = NULL) {

  period_info = filter(data, sheet == focal_sheet, row %in% c(1,2,3))
  qrtr = cleaned_sheets[[focal_sheet]]$stat_name_1 |> unique()

  if(length(qrtr) > 1) {print(paste(qrtr, sheet))
    qrtr = qrtr[[1]]}

  two_digit_number = regmatches(qrtr, regexpr("\\d{2}", qrtr))

  legend = data.frame(
    character = c('J-S', 'J-M', 'O-D', 'A-J'),
    period_start_date = c('07-01', '01-01', '10-01', '04-01'),
    period_end_date = c('09-30', '03-31', '12-31', '06-30')
  )

  if (length(two_digit_number) > 0) {
    year = paste0("20", two_digit_number)
    qrtr = gsub("/\\d{2}", "", qrtr)
  }else {
    year = regmatches(period_info, regexpr("\\b2\\d{3}\\b", period_info)) |> unique()}

  if (length(year) == 0) {
    # If no year is found, use the previous period dates
    period_start_date = last_start_date
    period_end_date = last_end_date
  } else {
    matched_row = legend[legend$character == qrtr, ]

    # Combine the year with the start and end dates
    period_start_date = paste0(year, "-", matched_row$period_start_date)
    period_end_date = paste0(year, "-", matched_row$period_end_date)

  }

  return(list(period_start_date = period_start_date, period_end_date = period_end_date))
}

add_periods = function(sheets, data, cleaned_sheets) {
  last_start_date = NULL
  last_end_date = NULL

  for (focal_sheet in sheets) {
    # Calculate the period dates for the current sheet
    period_dates = calculate_period_dates(focal_sheet, data, cleaned_sheets, last_start_date, last_end_date)

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
               %>% select(location, icd_9, historical_disease,
                          period_start_date, period_end_date,
                          cases_this_period)

               %>% identify_scales() # iidda

               %>% add_provenance(tidy_dataset) # iidda
  )

  return(tidy_data)
}

# Processing Steps

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE) # iidda

data = read_digitized_data(metadata) # iidda

sheets = get_sheet_names(data) # local

beheaded_sheets = sapply(sheets, behead_sheet, data = data, simplify = FALSE) # local

cleaned_sheets = lapply(beheaded_sheets, clean_sheets) # local

tidy_data = add_periods(sheets, data, cleaned_sheets)

metadata = add_column_summaries(tidy_data, tidy_dataset, metadata) # iidda

files = write_tidy_data(tidy_data, metadata) # iidda
