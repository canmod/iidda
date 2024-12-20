import os
import re
import sys    
from iidda_admin.project import iidda_staging
from iidda_admin.utilities import get_config
from iidda_admin.project import iidda_test_assets
from iidda_admin.validation import GoodDataCite
import git
from github import Github

file_path = sys.argv[1]
folder_location = os.path.dirname(file_path)
base_path = os.path.basename(file_path)
dataset_id, file_ext = os.path.splitext(base_path)
metadata_path = folder_location + "/" + dataset_id + ".json"

validator = GoodDataCite()
status = validator._good(metadata_path)
if (status == "invalid"):
    print("Metadata does not comply with DataCite standards.")
    raise ValueError(status)
else:
    print("Metadata complies with DataCite standards.")

# TODO: stop if file_ext is not csv

config = get_config()
github = Github(config.get('github_info', 'access_token'))
release_project = iidda_test_assets
repo = github.get_repo(iidda_test_assets.repo_name)
local_repo = git.Repo(iidda_staging.path)

modified_files = [item.a_path for item in local_repo.index.diff(None)]
staged_changes = [item.a_path for item in local_repo.index.diff("HEAD")]
untracked_files = local_repo.untracked_files

# TODO: turn this check back on once we are in a better position
#if (modified_files or staged_changes or untracked_files):
#    message_parts = ["There are tracked changes in the repository:"]
#    if modified_files:
#        message_parts.append("Modified files:")
#        for file in modified_files:
#            message_parts.append(f"  - {file}")
#    if staged_changes:
#        message_parts.append("Staged changes:")
#        for file in staged_changes:
#            message_parts.append(f"  - {file}")
#    if untracked_files:
#        message_parts.append("Untracked files:")
#        for file in untracked_files:
#            message_parts.append(f"  - {file}")
#    message = "\n".join(message_parts)
#    raise RuntimeError(message)


pipeline_repo = github.get_repo(iidda_staging.repo_name)
pipeline_repo.get_commits()[0]
commit_hash = local_repo.head.commit.hexsha  ## TODO: add revision number to the metadata

release_name = os.path.basename(folder_location)
print(release_name + " is being deployed")

# filter through and sort all releases of this name ascending by version
release_list = list(
    filter(lambda release: release.title == release_name, repo.get_releases()))
r = re.compile('^v([0-9]+)-(.*)')
release_list = sorted(
    release_list, key=lambda release: int(r.search(release.tag_name).group(1)))

latest_version = int(r.search(release_list[-1].tag_name).group(1)) if release_list else 0

try:
    folder_dir = os.listdir(folder_location)
    folder_dir = [f for f in folder_dir if f.endswith(".csv") or f.endswith(".json")]
    if len(folder_dir) == 0:
        print("No files to upload")
    else:
        new_release = repo.create_git_release(
            "v{}-{}".format(latest_version + 1, release_name),
            release_name,
            "version " + str(latest_version + 1)
        )

        # upload all .csv and .json files from within the folder
        for file in os.listdir(folder_location):
            if file.endswith(".csv"):
                new_release.upload_asset(folder_location + "/" + file, file, "text/json")
            elif file.endswith(".json"):
                new_release.upload_asset(folder_location + "/" + file, file, "application/json")
        
        status = "uploaded"
except Exception as e:
    print("Error: {}".format(e))
    status = "not_uploaded"

with open(folder_location + "/" + dataset_id + ".deploy", "w") as file:
    # TODO: put something more useful in the .deploy file, like maybe
    # a link to the github assets. the commit_hash should go in the
    # metadata asset.
    file.write(commit_hash)
