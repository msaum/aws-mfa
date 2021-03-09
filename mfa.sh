###################################################
# AWS MFA with Credentials Caching
###################################################
AWS_CREDS_CACHE="$HOME/.aws/.credcache"

if [ -f "${AWS_CREDS_CACHE}" ]; then
     echo -n "Loading AWS credential cache...expiring: "
     . "${AWS_CREDS_CACHE}" > /dev/null
     echo ${AWS_CREDS_JSON} | jq -r .Credentials.Expiration
fi

function mfa {
  AWS_CLI=`which aws`
  if [ $? -ne 0 ]; then
    echo "AWS CLI is not installed.  Please install AWS CLI v2"
    echo "https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
    return 1
  fi
  # Creds persist for 36 hours (129600)
  DURATION_SECONDS=129600

  # Zero out existing credentials
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN

  # make sure two arguments are passed else die
  [ $# -eq 0 ] && { echo "Usage: $0 token-code [profile]" ; return 1 }
  [ $# -gt 3 ] && { echo "Usage: $0 token-code [profile]" ; return 1 }

  [ $# -eq 1 ] && { \
    ARN_OF_MFA=`${AWS_CLI} configure get aws_mfa_device --profile default` && \
    TOKEN_CODE=$1 && \
    echo "Running: ${AWS_CLI} sts get-session-token --duration-seconds ${DURATION_SECONDS} --serial-number ${ARN_OF_MFA} --token-code ${TOKEN_CODE}" && \
    CREDS=`${AWS_CLI} sts get-session-token --duration-seconds ${DURATION_SECONDS} --serial-number ${ARN_OF_MFA} --token-code ${TOKEN_CODE} | jq -c`  \
    || { return 1 }}

  [ $# -eq 2 ] && { \
    ARN_OF_MFA=`${AWS_CLI} configure get aws_mfa_device --profile $2` && \
    TOKEN_CODE=$1 && \
    echo "Running: ${AWS_CLI} sts get-session-token --duration-seconds ${DURATION_SECONDS} --serial-number $ARN_OF_MFA --token-code $TOKEN_CODE" && \
    CREDS=`${AWS_CLI} sts get-session-token --duration-seconds ${DURATION_SECONDS} --serial-number $ARN_OF_MFA --profile $2 --token-code $TOKEN_CODE | jq -c`  \
    || { return 1 }}

  # Write credentials into the cache file
  echo "New AWS credentials generated:"
  echo "export AWS_ACCESS_KEY_ID=`echo $CREDS | jq -r .Credentials.AccessKeyId`" | tee ${AWS_CREDS_CACHE}
  echo "export AWS_SECRET_ACCESS_KEY=`echo $CREDS | jq -r .Credentials.SecretAccessKey`"  | tee -a ${AWS_CREDS_CACHE}
  echo "export AWS_SESSION_TOKEN=`echo $CREDS | jq -r .Credentials.SessionToken`" | tee -a ${AWS_CREDS_CACHE}
  echo "export AWS_CREDS_JSON=`echo \'$CREDS\'`"  >> ${AWS_CREDS_CACHE}
  . "${AWS_CREDS_CACHE}" > /dev/null
  echo "Expiring: `echo ${AWS_CREDS_JSON} | jq -r .Credentials.Expiration`"
}
