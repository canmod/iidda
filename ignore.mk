## Declare what datasets should not be made or deployed to the API
##
## dep_ids_to_ignore : list of dataset IDs that should not be deployed
## dat_ids_to_ignore : list of dataset IDs that should not be made


## never push these. they are just created as intermediate
## datasets for other datasets that should be pushed
dep_ids_to_ignore += canmod-location-lookup
dep_ids_to_ignore += canmod-disease-lookup
dep_ids_to_ignore += phac-to-canmod-disease-lookup


## skipping lbom -- sometimes useful given how long it can take
dat_ids_to_ignore := bth_uk_1661-1845
dat_ids_to_ignore += bth_uk_1842-1930
dat_ids_to_ignore += pop_uk_1842-1910_an
dat_ids_to_ignore += acm_uk_1661-1845
dat_ids_to_ignore += acm_uk_1842-1930_age
dat_ids_to_ignore += mort_uk_1642-1845_wk_davenport
dat_ids_to_ignore += mort_uk_1661-1845
dat_ids_to_ignore += mort_uk_1842-1950
dat_ids_to_ignore += plag_uk_1661-1688_wk_par
dat_ids_to_ignore += london-mort-harmonized
#dat_ids_to_ignore += phac-to-canmod-disease-lookup
#dat_ids_to_ignore += canmod-location-lookup
#dat_ids_to_ignore += canmod-disease-lookup
#dat_ids_to_ignore += canmod-cdi-unharmonized
#dat_ids_to_ignore += canmod-cdi-normalized
#dat_ids_to_ignore += canmod-disease-cross-check
#dat_ids_to_ignore += canmod-time-scale-cross-check
