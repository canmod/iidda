from iidda_admin.delete_versions import VersionDeleter
delete = VersionDeleter()
ids = [
    "london-mort-harmonized",
    "mort_ca_1950-1959_wk_prov_causes",
    "mort_ca_1960-1969_wk_prov_causes",
    "mort_ca_1970-1979_wk_prov_causes",
    "mort_ca_1980-1989_wk_prov_causes",
    "mort_ca_1990-1999_wk_prov_causes",
    "mort_ca_2000-2020_wk_prov_causes",
    "mort_plag_uk_1661-1688_wk_par",
    "mort_uk_1642-1845_wk_davenport",
    "mort_uk_1661-1845",
    "mort_uk_1842-1950",
    "acm_uk_1661-1845",
    "acm_uk_1842-1930_age",
    "bth_uk_1661-1845",
    "bth_uk_1842-1930"
]
[delete.all_versions(id) for id in ids]
