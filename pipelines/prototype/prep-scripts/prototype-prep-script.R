# ----------------------------------------
# Information for Locating Metadata
tidy_dataset = "prototype-dataset"
digitization = "prototype-digitization"
metadata_path = "pipelines/prototype/tracking"
# ----------------------------------------

library(iidda)

metadata = get_tracking_metadata(tidy_dataset, digitization, metadata_path, original_format = FALSE)
dataset = read_digitized_data(metadata)
files = write_tidy_data(dataset, metadata)
