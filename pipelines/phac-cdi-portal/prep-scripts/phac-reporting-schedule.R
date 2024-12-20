library(dplyr)
library(tidyr)
library(iidda)

## Helper functions
### Create new columns based on cell patterns
multiSeparate <- function(df, vars, pattern, remove = FALSE, drop_ns = FALSE){
	for (var in vars){
		nselected <- paste0(var, "_nselected")
		df <- (df
			%>% rename("temp_multi" = var)
			%>% mutate(temp_nselected = sapply(
					regmatches(temp_multi, gregexpr(pattern, temp_multi))
					, length
				) + 1
			)
		)
		# Max number of new variables to create
		maxselected <- max(pull(df, temp_nselected))

		# Create the new variable
		df <- (df
			%>% separate("temp_multi"
				, c(paste0(rep(var, maxselected), "_", 1:maxselected))
				, sep = pattern
				, remove = remove
				, convert = TRUE
			)
		)
		if(drop_ns){
			df <- select(df, -all_of(grep("_nselected$", colnames(df), value = TRUE)))
		}
	}
	return(df)
}

### Create a sequence of years give x-y year
extract_year = function(x) {
	x = strsplit(x, "-")[[1]]
	if (length(x)>1) {
		x = paste0(as.numeric(x[[1]]):as.numeric(x[[2]]), collapse = ",")
	} else {
		x = as.numeric(x[[1]])
	}

	return(x)
}

## Extract data
### Read notes data
notes = readLines("pipelines/phac-cdi-portal/digitizations/phac-reporting-schedule.txt")

### First position with disease name
first_position = 3
last_year = 2021
all_provinces = "AB, BC, MB, NB, NL, NS, ON, PE, QC, SK, YT, NT"
limitations = grep("Limitations", notes) + first_position

### Disease descriptions; stored for later
descriptions = grep("Disease descriptions", notes) - first_position

### For now, we concentrate on the limitations
limitations_text = notes[limitations:descriptions]
diseases_index = grep("^---", limitations_text) - 1
diseases = limitations_text[diseases_index]

## Store blocks with disease information
data_list = list()

## Loop over all disease blocks
for (i in (seq_along(diseases_index) + 1)) {
  if (i > length(diseases_index)) {
    block = limitations_text[diseases_index[(i-1)]:length(limitations_text)]
  } else {
	  block = limitations_text[diseases_index[(i-1)]:(diseases_index[i]-1)]
  }
	disease = block[1]
	comment = block[4:length(block)]
	df = data.frame(web_portal_disease=disease, comment=comment)
	df = (df
		|> filter(!comment %in% c("  ", " ", ""))
		|> mutate(
				description = ifelse(grepl("^.*\\   |A[a]ll provinces|Creutzfeldt-|Influenza, laboratory", comment), gsub("^.*\\   ", "", comment), NA_character_)
			)
	)
	df1 = (df
		|> filter(is.na(description) | grepl("Creutzfeldt-Jakob|Influenza, laboratory", description))
	)
	df = (df
		|> mutate(description=ifelse(grepl("Creutzfeldt-Jakob.*current|current.*Creutzfeldt-Jakob", description), NA_character_, description))
		|> mutate(
				description=ifelse(grepl("QC provided first-time diagnosed cases", description)
					, paste0("All provinces and territories except QC:", readr::parse_number(description))
					, ifelse(grepl("first-time diagnosed HIV cases", description)
						, paste0("All provinces and territories:", readr::parse_number(description))
						, ifelse(grepl("In years prior to 2020", description)
							, paste0("CA:", "1995-", readr::parse_number(description)-1)
							, description
						)
					)
				)
		)
		|> filter(!is.na(description))
		|> mutate(comment = paste0(df1$comment, collapse = " "))
		|> filter(!description %in% c("  ", " ", ""))
		|> mutate(year = gsub(".*\\:", "", description)
			, description = gsub("\\:.*", "", description)
			, year = ifelse(grepl("Creutzfeldt-Jakob|Influenza, laboratory", year), paste0(readr::parse_number(gsub("Creutzfeldt-Jakob", "", year)), "-", last_year), year)
			, description = ifelse(grepl("Creutzfeldt-Jakob|Influenza, laboratory", description), "CA", description)
			, description = ifelse(grepl("territories except QC", description), gsub("QC,", "", all_provinces), description)
			, description = ifelse(grepl("A[a]ll provinces and territories", description), all_provinces, description)
		)
		|> multiSeparate("description", pattern = ",", remove = TRUE, drop_ns = TRUE)
		|> pivot_longer(cols = starts_with("description"), values_to="iso_3166_2", values_drop_na=TRUE)
		|> select(-name)
		|> mutate(iso_3166_2 = trimws(iso_3166_2)
												, year = gsub(" onwards", paste0("-", last_year), year)
		)
		|> multiSeparate("year", pattern = ",", remove = TRUE, drop_ns = TRUE)
		|> mutate(across(starts_with("year_"), as.character))
		|> pivot_longer(cols = starts_with("year"), values_to="year", values_drop_na=TRUE)
		|> mutate(year = trimws(year))
		|> select(-name)
		|> relocate(comment, .after = "year")
		|> rowwise()
		|> mutate(year = as.character(extract_year(year)))
		|> ungroup()
		|> multiSeparate("year", pattern = ",", remove = TRUE, drop_ns = TRUE)
		|> mutate(across(starts_with("year_"), as.character))
		|> pivot_longer(cols = starts_with("year"), values_to="year", values_drop_na=TRUE)
		|> select(-name)
		|> relocate(comment, .after = "year")
	)
	data_list[[i-1]] = df
}

df = (bind_rows(data_list)
	|> mutate(iso_3166_2 = ifelse(iso_3166_2!="CA", paste0("CA-", iso_3166_2), iso_3166_2))
)

month = paste0(month.name, collapse = "|")
provinces = gsub(", ", "|", all_provinces)
comment_df = (df
	|> select(-year)
	|> distinct()
	|> filter(grepl("began in", comment))
	|> filter(grepl(month, comment))
	|> mutate(
		region_comment = stringr::str_extract_all(comment, provinces)
		, joining_month = stringr::str_extract(comment, month)
		, joining_month = as.character(joining_month)
	)
	|> filter(gsub("CA-", "", iso_3166_2) %in% region_comment)
	|> mutate(year = readr::parse_number(stringr::str_extract(comment, "joined confederation in \\d+"))
		, year = as.character(year)
	)
	|> select(-region_comment, -comment)
)
df = (df
	|> left_join(comment_df, by = c("web_portal_disease", "iso_3166_2", "year"))
	|> relocate(joining_month, .after = "year")
	|> mutate(web_portal_disease = trimws(web_portal_disease))
	|> mutate(joining_month = ifelse(is.na(joining_month), "01", "07"))
) |> rename(
    historical_disease = web_portal_disease
  , month = joining_month
)

df$comment = gsub("'", "", df$comment)
df$comment = gsub('"', "", df$comment)
df$comment = gsub(":", "", df$comment)
df$iso_3166_2 = gsub("-All provinces and territories", "", df$iso_3166_2)

metadata = get_dataset_metadata("phac-reporting-schedule")

metadata = add_column_summaries(df, "phac-reporting-schedule", metadata)


files = write_tidy_data(df, metadata)
