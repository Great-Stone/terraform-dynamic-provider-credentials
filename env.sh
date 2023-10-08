#!/bin/sh

# env.sh
cat <<EOF
{
  "client_id": "$HCP_CLIENT_ID",
  "client_secret": "$HCP_CLIENT_SECRET"
}
EOF