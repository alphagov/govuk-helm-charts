#!/usr/bin/env bash
set -euo pipefail

echo "directories"

mkdir base head

mv base-r/rendered-charts/* base/
mv head-r/rendered-charts/* head/

echo "diff"

diff -r base/ head/

DIFF=$(diff -r base/ head/)

echo "before if"

if [ -z "$DIFF" ]; then
  cat <<'EOF' > pr.md
No changes detected in rendered charts.
EOF
else
  echo "there are changes"
  echo "${DIFF}"
cat <<'EOF' > pr.md
<details>
<summary>Rendered charts diff</summary>
This PR results in the following changes to rendered charts:

```diff
EOF
  {
    echo "$DIFF"
    echo '```'
    echo '</details>'
  } >> pr.md
fi

gh pr comment "${PR_URL}" --create-if-none --edit-last --body-file pr.md
