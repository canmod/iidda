SHELL := /bin/sh
.DEFAULT_GOAL := all
.SUFFIXES:


-include ignore.mk
-include setup.mk


## step 1: dependency files
## e.g.:
## make derived-data/prototype-dataset/prototype-dataset.d
$(dep_files) : $(dat_dir)/%.d : $(dep_dir)/%.d | $(dat_dir)
	@echo
	@echo '-------------------------------------------------------------'
	@echo 'Attempting to make the following dependency file:'
	@echo '$@'
	@echo '-------------------------------------------------------------'
	@echo
	@mkdir -p $(dir $@)
	sh/cp_dep_file.sh $< $@

## step 2: derived data
## e.g.:
## make derived-data/prototype-dataset/prototype-dataset.csv
$(dat_files) : $(dat_dir)/%.csv : $(dat_dir)/%.d
	@echo
	@echo '-------------------------------------------------------------'
	@echo 'Attempting to make the following dataset:'
	@echo '$@'
	@echo 'With the following script:'
	@echo '$(word 2,$^)'
	@echo '-------------------------------------------------------------'
	@echo
	@Rscript $(word 2,$^)

## step 3: send data to api
## (maintainers only. requires additional setup.)
## e.g.:
## make derived-data/prototype-dataset/prototype-dataset.deploy
$(deploy_files) : $(dat_dir)/%.deploy : $(dat_dir)/%.csv
	@echo
	@echo '-------------------------------------------------------------'
	@echo 'Attempting to deploy the following dataset to the IIDDA API:'
	@echo '$<'
	@echo '-------------------------------------------------------------'
	@echo
	@python deployment-scripts/deploy-dataset.py $<



## printing / info

print-dat-ids :
	@echo $(dat_ids) | tr ' ' '\n'

print-dep-files :
	@echo $(dep_files) | tr ' ' '\n'

print-dat-files :
	@echo $(dat_files) | tr ' ' '\n'

print-dat-subdirs :
	@echo $(dat_subdirs) | tr ' ' '\n'

print-deploy-files :
	@echo $(deploy_files) | tr ' ' '\n'


## bulk operations

.PHONY : all
all : all-data

.PHONY : install
install : $(dep_files)
	@Rscript R/$(r_pkg)-check.R

.PHONY : all-data
all-data : $(dat_files)

.PHONY : deploy
deploy : $(deploy_files)


## cleaning up

.PHONY : clean
clean :
	## makefile debugging artifacts
	@rm -f build.*.json callgrind.out.*

	## macos: remove all .DS_Store files anywhere
	@find . -type f -name .DS_Store -exec rm -f {} \;

.PHONY : fresh
fresh : clean
	## carefull: remove all derived data
	@rm -rf $(dat_dir)


## repo maintenance

global-metadata/data-dictionary.json : R/update-data-dictionary.R metadata/columns/*.json metadata/columns
	@if [ ! -e $(public_repo) ]; then \
		echo "Error: Please make sure that the public_repo variable is set properly in setup.mk"; \
		exit 1; \
	fi
	@Rscript -e "source('R/update-data-dictionary.R')"
	@cp global-metadata/data-dictionary.json $(public_repo)/global-metadata

global-metadata/$(r_pkg).R : R/update-$(r_pkg).R pipelines/*/prep-scripts/*.R
	@Rscript $<

.PHONY : update-lookup-tables
update-lookup-tables:
	@python deployment-scripts/update_lookup_tables.py
	@echo "Do not forget to push new commits associated with lookup tables to iidda"

.PHONY : delete-all-but-latest-versions
delete-all-but-latest-versions:
	@python deployment-scripts/delete_all_but_latest_version.py
