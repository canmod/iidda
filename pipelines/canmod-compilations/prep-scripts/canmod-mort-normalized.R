library(iidda)


input_file = "derived-data/canmod-mort-harmonized/canmod-mort-harmonized.csv"
input_id = (input_file
  |> basename()
  |> tools::file_path_sans_ext()
)

data = filter(read_data_frame(input_file)
  , time_scale == "wk"
  , !iidda::is_empty(iso_3166_2)
  , cause != "Total causes"
)

output_file = "derived-data/canmod-mort-normalized/canmod-mort-normalized.csv"
output_id = (output_file
  |> basename()
  |> tools::file_path_sans_ext()
)

metadata = add_column_summaries(data, output_id, get_dataset_metadata(output_id))
files = write_tidy_data(data, metadata)
#write_data_frame(data, output_file)
