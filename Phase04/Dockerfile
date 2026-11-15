# CloudGuard 360 — Phase 04. We REPACKAGE the pre-built Voting App from Phase 03.
# This does not rebuild the upstream Flask source. The base must be reachable and reviewed.
ARG VOTING_BASE_IMAGE=mcr.microsoft.com/azuredocs/azure-vote-front:v1
FROM ${VOTING_BASE_IMAGE}
ARG SOURCE_REPO="unknown"
LABEL org.opencontainers.image.title="CloudGuard 360 Voting Frontend" \
      org.opencontainers.image.description="Training wrapper around Microsoft Azure Voting App" \
      org.opencontainers.image.source="${SOURCE_REPO}"
# Preserve upstream CMD/ENTRYPOINT and port. No new dependencies or credentials.
