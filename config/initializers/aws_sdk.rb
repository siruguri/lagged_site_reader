# This app authenticates to AWS with static credentials from Rails
# credentials (see config/storage.yml) -- never an ambient AWS CLI profile.
#
# If AWS_PROFILE is set in the shell (e.g. a work SSO profile), aws-sdk-core
# resolves a token_provider default from it during client construction,
# regardless of whether the service being used needs one. If that profile's
# cached SSO token is stale, client construction raises InvalidSSOToken
# before our static credentials are ever considered. Clearing it here keeps
# this app's AWS access independent of whatever's ambient on the machine.
ENV.delete("AWS_PROFILE")
