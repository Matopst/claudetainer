#!/bin/bash
# Clone the platform agent repo and sync sub-repos, then keep the pod alive.
# Needs GH_TOKEN (read access to intility repos); without it, setup is skipped.
REPO=developer-platform-agent
cd ~
if [ -z "${GH_TOKEN:-}" ]; then
  echo "GH_TOKEN not set, skipping $REPO setup"
else
  gh auth setup-git
  if [ -d "$REPO/.git" ]; then
    git -C "$REPO" pull --ff-only || echo "pull of $REPO failed"
  else
    gh repo clone "intility/$REPO" || echo "clone of $REPO failed"
  fi
  if [ -d "$REPO" ]; then
    (cd "$REPO" && just setup && just pull) || echo "just setup/pull failed"
  fi
fi
exec sleep infinity
