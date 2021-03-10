###################################################
# AWS MFA with Credentials Caching
###################################################
AWS_CREDS_CACHE="${HOME}/.aws/.credcache"

JQ_CLI=$(which jq) || { echo "ERROR: jq not installed.  Please install jq the CLI JSON Processor" ;  return 1 ; }

[ -f "${AWS_CREDS_CACHE}" ] && { \
  echo -n "Loading ${AWS_CREDS_CACHE}, expiring: " ; \
  # shellcheck disable=SC1090
  source "${AWS_CREDS_CACHE}" > /dev/null ; \
  echo "${AWS_CREDS_JSON}" | ${JQ_CLI} -r .Credentials.Expiration ; }
  # date --iso-8601=seconds

unset AWS_CREDS_CACHE
unset JQ_CLI

function mfa {
  AWS_CLI=$(which aws) || { \
    echo "AWS CLI is not installed.  Please install AWS CLI v2" ;
    echo "https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html" ;
    return 1 ; }

  JQ_CLI=$(which jq) || { \
    echo "jq not installed.  Please install jq the CLI JSON Processor" ;
    return 1 ; }

  TEE_CLI=$(which tee) || { \
    echo "tee not installed.  Please install tee (coreutils in Ubuntu)" ;
    return 1 ; }

  # Creds persist for 36 hours (129600)
  AWS_CREDENTIAL_DURATION_SECONDS=129600

  # Zero out existing credentials
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  unset AWS_PROFILE

  # Validate argument count else die
  [ $# -eq 0 ] && { echo "Usage: $0 token-code [profile]" ; return 1 ; }
  [ $# -gt 3 ] && { echo "Usage: $0 token-code [profile]" ; return 1 ; }

  [ $# -eq 1 ] && { AWS_PROFILE="default" && TOKEN_CODE=$1 ; }
  [ $# -eq 2 ] && { TOKEN_CODE=$1 && AWS_PROFILE=$2 ; }

  ARN_OF_MFA=$(${AWS_CLI} configure get aws_mfa_device --profile "${AWS_PROFILE}") || \
    { "Error: AWS CLI failed to retrieve the MFA ARN for profile ${AWS_PROFILE}" ; return 1 ; }

  echo "Running: ${AWS_CLI} sts get-session-token --output json --duration-seconds ${AWS_CREDENTIAL_DURATION_SECONDS} --serial-number ${ARN_OF_MFA} --profile ${AWS_PROFILE} --token-code ${TOKEN_CODE}"

  CREDS=$(${AWS_CLI} sts get-session-token --output json --duration-seconds "${AWS_CREDENTIAL_DURATION_SECONDS}" --serial-number "${ARN_OF_MFA}" --profile "${AWS_PROFILE}" --token-code "${TOKEN_CODE}") \
    || { "Error: AWS CLI failed to get a credential" ; return 1 ; }
  CREDS=$(echo "${CREDS}" | ${JQ_CLI} -c)

  # Write credentials into the cache file
  AWS_CREDS_CACHE="${HOME}/.aws/.credcache"
  echo "Writing credential file:  ${AWS_CREDS_CACHE}"
  echo "export AWS_ACCESS_KEY_ID=$(echo ${CREDS} | ${JQ_CLI} -r .Credentials.AccessKeyId)" | ${TEE_CLI} "${AWS_CREDS_CACHE}"
  echo "export AWS_SECRET_ACCESS_KEY=$(echo ${CREDS} | ${JQ_CLI} -r .Credentials.SecretAccessKey)"  | ${TEE_CLI} -a "${AWS_CREDS_CACHE}"
  echo "export AWS_SESSION_TOKEN=$(echo ${CREDS} | ${JQ_CLI} -r .Credentials.SessionToken)" | ${TEE_CLI} -a "${AWS_CREDS_CACHE}"
  echo "export AWS_CREDS_JSON=$(echo \'$CREDS\')"  >> "${AWS_CREDS_CACHE}"
  # shellcheck disable=SC1090
  source "${AWS_CREDS_CACHE}" > /dev/null
  echo "Expiring: $(echo ${AWS_CREDS_JSON} | ${JQ_CLI} -r .Credentials.Expiration)"
  echo AWS_PROFILE=${AWS_PROFILE}

  # Write creds into specific profile cache
  echo "Writing credential file: ${AWS_CREDS_CACHE}.${AWS_PROFILE}"
  echo "export AWS_ACCESS_KEY_ID=$(echo $CREDS | ${JQ_CLI} -r .Credentials.AccessKeyId)" > "${AWS_CREDS_CACHE}.${AWS_PROFILE}"
  echo "export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | ${JQ_CLI} -r .Credentials.SecretAccessKey)"  >> "${AWS_CREDS_CACHE}.${AWS_PROFILE}"
  echo "export AWS_SESSION_TOKEN=$(echo $CREDS | ${JQ_CLI} -r .Credentials.SessionToken)" >> "${AWS_CREDS_CACHE}.${AWS_PROFILE}"
  echo "export AWS_CREDS_JSON=$(echo \'$CREDS\')"  >> "${AWS_CREDS_CACHE}.${AWS_PROFILE}"
  unset AWS_CREDS_CACHE
  unset AWS_CLI
  unset JQ_CLI
  unset TEE_CLI
  unset AWS_CREDENTIAL_DURATION_SECONDS
}

function mfa_cache {
  AWS_CLI=$(which aws) || { \
    echo "AWS CLI is not installed.  Please install AWS CLI v2" ;
    echo "https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html" ;
    return 1 ; }

  JQ_CLI=$(which jq) || { \
    echo "jq not installed.  Please install jq the CLI JSON Processor" ;
    return 1 ; }

  # Validate argument count else die
  [ $# -eq 0 ] && { AWS_CREDS_CACHE="${HOME}/.aws/.credcache" ; AWS_PROFILE="default" ; }
  [ $# -eq 1 ] && { AWS_CREDS_CACHE="${HOME}/.aws/.credcache.${1}" ; AWS_PROFILE="${1}" ; }
  [ $# -gt 1 ] && { echo "Usage: $0 [profile]" ; return 1 ; }

  if [ -f "${AWS_CREDS_CACHE}" ]; then
    echo -n "Loading AWS credential cache for profile ${AWS_PROFILE}, expiring: "
    # shellcheck disable=SC1090
    source "${AWS_CREDS_CACHE}" > /dev/null
    echo "${AWS_CREDS_JSON}" | ${JQ_CLI} -r .Credentials.Expiration
  else
    echo "Unable to find cache file ${AWS_CREDS_CACHE}"
    return 1
  fi
  unset AWS_CLI
  unset JQ_CLI
}

function mfa_cache_list {
  SED_CLI=$(which sed) || { \
    echo "sed not installed.  Please install sed to use this function" ;
    return 1 ; }


  pushd . > /dev/null
  cd  ${HOME}/.aws/ || { echo "ERROR: Unable to cd to ${HOME}/.aws/" ; return ; }
  for filename in .credcache.*
  do
    echo $filename | ${SED_CLI} 's/\.credcache\.//g'
  done
  popd > /dev/null ||  { echo "ERROR: Unable to return to your current working directory" ; return ; }
  unset SED_CLI
}