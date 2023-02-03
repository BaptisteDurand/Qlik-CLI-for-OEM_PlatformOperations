############### Step 0 - Init. Import functions and constant ###############
. .\constant-priv.ps1
. .\util.ps1

############### Step 1 - Setup/Update if exist the context ############### 
# 1.1 Source tenant
setup_cli_context $SOURCE_TENANT_HOSTNAME
# 1.2 Registration tenant
setup_cli_context $TENANT_REGISTRATION_HOSTNAME

############### Step 3 - Get licence key ###############
# 3.1 Use context source tenant
qlik context use $SOURCE_TENANT_HOSTNAME
# 3.2 Get source tenant license key
$licenseKey = $(qlik license overview --json | ConvertFrom-Json).licenseKey

############### Step 4 - Create tenant ###############
# 4.1 use context registration tenant
qlik context use $TENANT_REGISTRATION_HOSTNAME

# 4.2 Create Target tenant
$targetTenant=$(qlik tenant create --licenseKey $licenseKey --json | ConvertFrom-Json)
$targetTenantId = $($targetTenant | ConvertFrom-Json).id
$targetTenantHostname = $($targetTenant | ConvertFrom-Json).hostnames[0]

# 4.3 Create new context for target Tenant
setup_cli_context $targetTenantHostname
qlik context use $targetTenantHostname

# 4.4 Check creation (get current)
$userTenantId=$(qlik user me | ConvertFrom-Json).tenantId
if($userTenantId -eq $targetTenantId){
    'INFO: Successfully accessed tenant $targetTenantHostname.'
}else{
    'ERROR: The tenant $targetTenantHostname does not have the expected ID'
}