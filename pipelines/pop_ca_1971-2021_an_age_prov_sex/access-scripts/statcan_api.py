if __name__ == '__main__' and not __package__:
    import sys
    sys.path.insert(0, '')
    __package__ = 'python.canada.pop_ca_1971-2021_an_prov_sex'

from ...functions.extract_zip_url import extract_zip_url

extract_zip_url("17100005", "pop_ca_1971-2021_an_prov_sex")
