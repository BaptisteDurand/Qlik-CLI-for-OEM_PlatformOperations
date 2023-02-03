############### Step 0 - Init. Import functions and constant ###############
# Import functions and constant
. .\constant-priv.ps1
. .\util.ps1
# Target tenant
$targetTenantHostname = 'XXX.eu.qlikcloud.com'

############### Step 1 - Tenant configuration : Setup the tenant regarding requirements ###############
# 1.1 Connect to target tenant
setup_cli_context $targetTenantHostname
qlik context use $targetTenantHostname

# 1.2 Get TenantId
$targetTenantId=$(qlik user me | ConvertFrom-Json).tenantId

# 1.3 Enable group synchronisation
$body = ConvertTo-Json ('[{"op":"replace","path":"/autoCreateGroups","value":true},{"op": "replace", "path": "/syncIdpGroups","value": true }]')
qlik group settings patch --body $body

# 1.4 License assignements : Auto assignement for analyzer and disable professional (example)
qlik license settings update --autoAssignAnalyzer=true --autoAssignProfessional=false

# 1.5 Setup a JWT IDP
$staticKeys = "{`\`"pem`\`": `\`"$JWT_PUBLIC_KEY`\`",`\`"kid`\`":`\`"$JWT_KEY_ID`\`"}"
qlik identity-provider create jwtauth --tenantIds="$targetTenantId"  --provider=external  --protocol=jwtAuth --options-issuer="$JWT_ISSUER"  --options-staticKeys="[$staticKeys]" --verbose

############### Step 2 - Connect in JWT to provision group ###############
# Connect by JWT to sync group for settings security
# Standard approach is to use your own JWT IDP to generate the token.
# For another help and examples, you can refer to : 
# - https://qlik.dev/tutorials/implement-jwt-authorization#configuring-the-tokenjs-file
# - https://github.com/qlik-oss/qlik-cloud-examples/blob/main/qlik.dev/tutorials/platform-operations/sdk-python/jwt_auth.py
#
# Example of python call used in Qlik Open Source examples : 
#python ../sdk-python/jwt_auth.py `
#         --issuer "$JWT_ISSUER" `
#         --key-id "$JWT_KEY_ID" `
#         --private-key "$JWT_PRIVATE_KEY" `
#         --public-key "$JWT_PUBLIC_KEY" `
#         --groups "$GROUP_ANALYTICS_CONSUMER" `
#         --tenant-url "http://$TARGET_TENANT_HOSTNAME" `
#         --log-level ERROR;

############### Step 3 - Setup Framework ###############

# 1. Create Space
$new_managed_space_id=$(qlik space create --name="$SPACE_MANAGED_PROD" --type=managed |convertfrom-json).id
$new_shared_space_id=$(qlik space create --name="$SPACE_SHARED_DEV" --type=shared |convertfrom-json).id

# 2. Assign security groups
qlik space assignment create --type="group" --assigneeId="$analytics_consumer_group_id" --roles="consumer" --spaceId="$new_managed_space_id"
