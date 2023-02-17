Qlik CLI is a command line interface for Qlik, written in Go.

It provides access to all public APIs for Qlik Cloud and also QRS API for Qlik Sense Client Managed.

You can manage operations, such as :
- Plateform operations (Tenant provisioning, Tenant configuration and adminsitration).
- Import, export, publish, and republish apps.
- Create, rename, remove, and update spaces and assign user access.
- Build, analyze, and edit apps.

Main use case is to automate actions to scale and improve time to delivery.

## First steps with Qlik CLI

Check Qlik.dev for more information on [Qlik CLI](https://qlik.dev/libraries-and-tools/qlik-cli)

Tutorials are available with different use cases : 
- [Get started with Qlik CLI](https://qlik.dev/tutorials/get-started-with-qlik-cli)
- [Migrate Apps from Qlik Sense on Windows to Qlik Sense SaaS](https://qlik.dev/tutorials/migrate-apps-from-qlik-sense-on-windows-to-qlik-sense-saas)
- [Migrating Community Sheets](https://qlik.dev/tutorials/migrate-community-sheets-from-qlik-sense-windows-to-saas)

**Authentication and first step**

Several options for authentication are available :
- JWT for Qlik Sense Client Managed
- API Key or OAuth Credentials for Qlik Cloud

Authentications are managed once through the *Qlik CLI context*. You can have many contexts giving you the ability to easily switch from an envrionment or tenant to another one. 

## Differences between Qlik CLI and Qlik CLI for Windows

Qlik CLI is a Qlik product supported by Qlik. It can be used through Powershell, Bash, ...

Qlik CLI give access to both : content management and Qlik Engine. It means that you can perform operations such as import an application, but also to connect to this application and perform a calculation. So, specific operations as the build and unbuild (serialization) of an application are available.

[Qlik CLI for Windows](https://github.com/ahaydon/Qlik-Cli-Windows) is an Open Source project of command line interface made in powershell. Qlik CLI for Windows is only compatible with Qlik Sense Client Managed.

# Qlik CLI for OEM Use Case

## What is a common OEM use case

As an OEM Partner, I need to : 
- To provision a tenant
- To setup an interactive user to login
- To setup a specific configuration (features, licences assignements, IDP, group provisioning,...)
- To export, import and publish an application from OEM master tenant to a customer tenant


![image](https://user-images.githubusercontent.com/24877503/202148698-f97b7ce6-13f7-458f-bc97-4e24b7180bfa.png)

## Code deep dive

### Global information

*Examples*

This example is based on the tutorial in [qlik.dev](https://qlik.dev/tutorials#platform-operations).
However, it is made with Qlik CLI and Powershell.

The goal is show easily the different steps and QLik CLI associated commands.
It is not to provide an out of the box solution for production used. 

*Context management*

We use Qlik CLI context to connect to the different tenant with Qlik CLI.
For Qlik Cloud contexts can be created with authentication based on API Key or with OAuth credentials.
For plateform operations, we used OAuth credentials. To be able to renew OAuth token, update existing context, etc. we are using here an additional function which creates or updates the contexts. ``setup_cli_context()`` is located in Util.ps.

*Variables management*

Variables for credentials, spaces name, user email,... are located in the ``constant-priv.ps1`` file.

[GitHub Repository](https://github.com/BaptisteDurand/Qlik-CLI-for-OEM_PlatformOperations/tree/main/QlikCLI-Examples)

### 1. Tenant Creation

Goal is to create a new target (customer) tenant.

In this step we need to : 
1. Initiate 2 contexts : 
    - The source tenant to get the licence
    - The registration tenant in the region we want to create the tenant
    
2. Get the licence
3. Create the tenant and test it

```powershell
############### Step 0 - Init. Import functions and constant ###############
. .\constant-priv.ps1
. .\util.ps1

############### Step 1 - Setup/Update if exist the context ############### 
# 1.1 Source tenant
setup_cli_context $SOURCE_TENANT_HOSTNAME
# 1.2 Registration tenant
setup_cli_context $TENANT_REGISTRATION_HOSTNAME

############### Step 2 - Get licence key ###############
# 3.1 Use context source tenant
qlik context use $SOURCE_TENANT_HOSTNAME
# 3.2 Get source tenant license key
$licenseKey = $(qlik license overview --json | ConvertFrom-Json).licenseKey

############### Step 3 - Create tenant ###############
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
```

### 2. Create an interactive user access

Goal is to create an interactive user with the tenant role admin to be able to connect to the new tenant.

In this step we need to : 
1. Get user information in the source tenant: 
2. Create the user in the target tenant


```powershell
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
```

### 3. Configure the Tenant

Goal is to configure the tenant regarding the specifications.

In this step we want to : 
1. Enable group synchronisation feature 
2. Enable analyzer licence auto assignement
3. Setup a JWT IDP
4. Connect with a user to provision functionals groups
5. Create managed and shared space and setup the rights. 

```powershell
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
# python ../sdk-python/jwt_auth.py `
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
```

### 4. Deploy a content

Goal is to deploy or (redeploy) and application from the source tenant to the target tenant.

In this step we want to : 
1. Extract the application from the source tenant 
2. Import the application in a shared space
3. Publish or Republish the application in a managed space

Note : use case is that the application is reloaded on the source tenant.

![image](https://user-images.githubusercontent.com/24877503/202151291-19b29383-2eac-4752-92c5-576e1b692c65.png)


```powershell
############### Step 0 - Init. Import functions and constant ###############
# Import functions and constant
. .\constant-priv.ps1
. .\util.ps1

# Target tenant
$targetTenantHostname = 'XXX.eu.qlikcloud.com'

############### Step 1 - Get App on source environment ###############
#Connect to source environment
setup_cli_context $SOURCE_TENANT_HOSTNAME
qlik context use $SOURCE_TENANT_HOSTNAME

#Get AppName of the app
$tempName=(qlik item ls --resourceType 'app' --resourceId $APPID |convertfrom-json).name

#add folder creation
qlik app export $APPID --output-file "$workLocation\$tempName.qvf" -v

############### Step 2 - Import the application in the shared space ###############
#Connect to target environment
setup_cli_context $targetTenantHostname
qlik context use $targetTenantHostname

#get shared spaceID
$SpaceTargetId=(qlik space ls --name $SPACE_SHARED_DEV |convertfrom-json).id
#import the application
$TargetAppId=(qlik app import --file "$workLocation\$tempName.qvf" --spaceId $SpaceTargetId --name $tempName --json | convertfrom-json).attributes.id

############### Step 3 - Publish or replace the application in the managed space ###############
#if managed space publish and replace
if ($SPACE_MANAGED_PROD -ne $null){
    $ManagedSpaceId=(qlik space ls --name $SPACE_MANAGED_PROD |convertfrom-json).id

    $existing = (qlik item ls --name $tempName --spaceId $ManagedSpaceId |convertfrom-json)
    if($existing){
        qlik app publish update $TargetAppId --targetId $existing.resourceId  --data 'source' --checkOriginAppId=false
    }
    else {
        qlik app publish create $TargetAppId --spaceId $ManagedSpaceId --data 'source'
    }
}
```

## Industrialization

These examples are made to present the different steps and Qlik CLI commands in powershell to automate the standard platform operations from the tenant provisioning to the app deployment.

For a production use with a more industrialize solution we recommand to start from [Qlik OSS repository](https://github.com/qlik-oss/qlik-platform-examples/tree/main/qlik.dev/tutorials/platform-operations).
These examples are available in a more robust code with error handling in : 
- Qlik CLI with Bash
- cURL
- Python
