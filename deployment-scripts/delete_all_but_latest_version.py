from iidda_admin.delete_versions import VersionDeleter
delete = VersionDeleter()
[delete.all_except_latest(id) for id in delete.review_existing_releases.dataset_ids]
