# -----------------------------
dataset_id = "canmod-cdi-harmonized"
# -----------------------------

library(iidda)
library(dplyr)

metadata = get_dataset_metadata(dataset_id)

data = read_prerequisite_data(dataset_id)

metadata = add_column_summaries(data, dataset_id, metadata)

files = write_tidy_data(data, metadata)
