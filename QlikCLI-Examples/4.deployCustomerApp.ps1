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