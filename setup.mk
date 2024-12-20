dat_dir := derived-data
src_dir := pipelines
dep_dir := dataset-dependencies
r_pkg := r-package-recommendations
public_repo := ../iidda

dep_subdirs := $(wildcard $(dep_dir)/*)
dat_ids := $(filter-out $(dat_ids_to_ignore),$(foreach dir,$(dep_subdirs),$(notdir $(dir))))
dep_ids := $(filter-out $(dep_ids_to_ignore),$(foreach dir,$(dep_subdirs),$(notdir $(dir))))
dat_subdirs := $(foreach id,$(dat_ids),$(dat_dir)/$(id))

dep_files := $(foreach id,$(dat_ids),$(dat_dir)/$(id)/$(id).d)
dat_files := $(foreach id,$(dat_ids),$(dat_dir)/$(id)/$(id).csv)
deploy_files := $(foreach id,$(dep_ids),$(dat_dir)/$(id)/$(id).deploy)


# if a `make fresh` is asked for twice, do not undo it
# by trying to remake the stuff that was removed
# by the `make fresh`


$(dat_dir) :
	@mkdir -p $@


# Include dependency files, remaking if necessary,
# unless a `make fresh` was asked for.
ifeq ($(MAKECMDGOALS),fresh)
else
-include $(dep_files)
endif
