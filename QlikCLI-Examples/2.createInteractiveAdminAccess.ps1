############### Step 0 - Init. Import functions and constant ###############
. .\constant-priv.ps1
. .\util.ps1

# Target tenant (if run separatly)
$targetTenantHostname = 'XXXX.eu.qlikcloud.com'

############### Step 1 - Get specific user by email ############### 
# 1.1 Connect to source tenant
setup_cli_context $SOURCE_TENANT_HOSTNAME
qlik context use $SOURCE_TENANT_HOSTNAME

# 1.2 Get all user info
# DEPRECATED - To update
$adminUser = qlik user ls --email $SOURCE_TENANT_ADMIN_EMAIL --json
#$adminUser = qlik user ls --filter "(email eq $SOURCE_TENANT_ADMIN_EMAIL)"

# 1.3 what we need for user creation
$adminUserName = $($adminUser | convertfrom-json).name
$adminUserEmail = $($adminUser | convertfrom-json).email
$adminUserSubject = $($adminUser | convertfrom-json).subject

############### Step 2 - Create user ############### 
# 2.1 Target tenant
setup_cli_context $targetTenantHostname
qlik context use $targetTenantHostname

# 2.2 Get Tenant Admin Role Id and format
$tenantAdminRoleId = $(qlik role ls --filter 'name eq ""TenantAdmin""' --json | ConvertFrom-Json).id
$tenantAdminRole = ConvertTo-Json ('{"id":"'+$tenantAdminRoleId+'"}')
$assignedRoles = "["+ $tenantAdminRole + "]"

# 2.3 Get TenantId
$targetTenantId=$(qlik user me | ConvertFrom-Json).tenantId

# 2.4 Create interactive users
qlik user create --name "$adminUserName" --email "$adminUserEmail" --subject "$adminUserSubject" --tenantId "$targetTenantId" --assignedRoles "$assignedRoles"