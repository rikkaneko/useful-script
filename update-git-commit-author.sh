#!/bin/bash

if [[ "$#" -ne 3 || "$@" =~ '--help' ]]; then
  echo "usage: $0 <old-email> <new-name> <new-email>"
  exit 1
fi

OLD_EMAIL="$1"
NEW_NAME="$2"
NEW_EMAIL="$3"

git filter-branch -f --env-filter '
if [[ "$GIT_COMMITTER_EMAIL" = "'"$OLD_EMAIL"'" ]]; then
    export GIT_COMMITTER_NAME="'"$NEW_NAME"'"
    export GIT_COMMITTER_EMAIL="'"$NEW_EMAIL"'"
fi
if [[ "$GIT_AUTHOR_EMAIL" = "'"$OLD_EMAIL"'" ]]; then
    export GIT_AUTHOR_NAME="'"$NEW_NAME"'"
    export GIT_AUTHOR_EMAIL="'"$NEW_EMAIL"'"
fi
' --msg-filter '
sed -e "s/^Signed-off-by: .*<'"$OLD_EMAIL"'>$/Signed-off-by: '"$NEW_NAME"' <'"$NEW_EMAIL"'>/g"
' --tag-name-filter cat -- --branches --tags