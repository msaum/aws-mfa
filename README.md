# aws-mfa

## Overview
This script will fetch an MFA token so that you can use temporary AWS credentials. This is modeled on several 
other similar scripts on the Internet with a few add-ons.  It will remember the last credential generated, 
so that if you open a new shell window or tab, you can use the last 
credential generated when your shell startup script is run. 
This script is intended to be added to a `.profile`, `.bashrc`, `.zshrc` or similar file.

## Configuration

- Copy the code from `mfa.sh` into your shell startup file.
- Create entries in your `~/.aws/config` and `~/.aws/credentials` files for each profile you want to use similar to 
  the following.  Your MFA ARN will be pulled from the `.aws/credentials` file automatically without any need for 
  another configuration file.
  
### `~/.aws/config`
```[default]
cli_pager = less
region = us-east-1
output = json
```

### `~/.aws/credentials`
```
[default]
aws_access_key_id = XXXXXXXXXXXXXXXXXXXXXXXX
aws_secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXX
aws_mfa_device = arn:aws:iam::XXXXXXXXXXXXXXXXXXXXXXXX:mfa/USERID
```
**Note:** Ensure you are using the mfa ARN not the IAM user ARN.

### Usage
The function takes one or two arguments.  By default, you can just send the token-code (2FA code), 
and it will use the default profile.  Optionally you can use an aws profile to pick a different profile from the
`~/.aws/config` / `~/.aws/credentials` files.

To test this you can also source the `mfa.sh` script to load the function:

`# . ./mfa.sh`

At a command prompt run the following command to generate a credential:

`# mfa <mfacode> <optional-aws-profile>`

At a command prompt run the following command to load a cached credential for a profile.  
If a profile isn't specified, the last generated credential is loaded.

`# mfa_cache <aws-profile>`

To see a list of cached credentials:

`# mfa_cache_list`

# Implementation Note

- In using this function/script the last temporary credentials generated will persist across shells that execute the
  shell profile through the use of the cache file. The last generated credential cache file is stored
  in `~/.aws/.credcache`.
- The last generated credential is cached in `~/.aws/.credcache` and can be recalled with the `mfa_cache` command.
- Cached credentials are not validated to determine if they are still valid.

