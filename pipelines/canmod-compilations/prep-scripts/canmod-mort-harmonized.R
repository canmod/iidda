library(iidda)


input_files = c(
  "derived-data/mort_ca_1950-1959_wk_prov_causes/mort_ca_1950-1959_wk_prov_causes.csv",
  "derived-data/mort_ca_1960-1969_wk_prov_causes/mort_ca_1960-1969_wk_prov_causes.csv",
  "derived-data/mort_ca_1970-1979_wk_prov_causes/mort_ca_1970-1979_wk_prov_causes.csv",
  "derived-data/mort_ca_1980-1989_wk_prov_causes/mort_ca_1980-1989_wk_prov_causes.csv",
  "derived-data/mort_ca_1990-1999_wk_prov_causes/mort_ca_1990-1999_wk_prov_causes.csv",
  "derived-data/mort_ca_2000-2020_wk_prov_causes/mort_ca_2000-2020_wk_prov_causes.csv"
)
input_ids = (input_files
  |> basename()
  |> tools::file_path_sans_ext()
)
lookup = read_data_frame("lookup-tables/canmod-location-lookup.csv")

data = (input_files
  |> lapply(read_data_frame)
  |> setNames(input_ids)
  |> bind_rows(.id = "original_dataset_id")
  |> left_join(lookup, join_by(location, location_type))
)


output_file = "derived-data/canmod-mort-harmonized/canmod-mort-harmonized.csv"
output_id = (output_file
  |> basename()
  |> tools::file_path_sans_ext()
)

metadata = add_column_summaries(data, output_id, get_dataset_metadata(output_id))
files = write_tidy_data(data, metadata)
#write_data_frame(data, output_file)
