## ======================================================
## This script has been automatically modified,
## so please do not manually modify it.
## ======================================================


library(readxl)
library(tidyxl)
library(tidyverse)
library(zoo)
library(naniar)
library(purrr)

data = xlsx_cells('data/canada/cdi_ca_1959_wk_province_dbs/cdi_ca_1958_annual_province_dbs.xlsx')


sum <- data %>% 
  filter(row !=1) %>% 
  select(row, col, data_type, numeric, character) %>% 
  behead('N', Province) %>% 
  behead('W', Disease) %>% 
  behead('W', Int.list.no.) %>% 
  filter(data_type != "blank") %>% 
  select(-character, -data_type, -row, -col) %>%
  distinct() %>% 
  rename(Cases = "numeric") %>% 
  relocate(Cases, .after = last_col())

