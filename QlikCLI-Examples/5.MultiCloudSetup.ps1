# Import functions and constant
. .\constant-priv.ps1
. .\util.ps1

#####################################################################################
# Goal : 
#     Setup a deployment on QSE-Client Managed
#     Get the Bearer Token (64bitEncoded)
#     Create the Multi Cloud IDP on the tenant
# Author : B.Durand
#####################################################################################

# Config parameters
$QSEEnvironmentURL      = 'https://qmi-qs-8114'
$QSEJWTPrefix           = '/jwt'
$QSEJWTToken            = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyaWQiOiJidXIiLCJ1c2VyZGlyZWN0b3J5Ijoiand0IiwiQ3VzdG9tZXJHcm91cCI6IkN1c3RvbWVyMSJ9.TNaJ6-DIHfkQm_fIF7_Oy8w_kyoUKg-4qGQJYwGMXZ6GoNH9zNZ4ztb82Af7c8i8h3kGr_6wxOWC_SViJH3Y4VEX2JhXpkO5me-W2h0bt1mz36R-oLb6atfrlwfz7raym9g5SRKOCRQlN62FuJ-HBZtzPARwqCDp4YaiGi0YqQjQTQR08OLetdK0ygyiS-IGnd_VsziGZTQz8DZNhp2wEBHOYA03t0_bsaNm08PX8yidh461V-T35MoBrLTfAcMqQq756-TfBb1bRMc75Ybpxz34dC-4XIwC4ZKTjbip8z1TSZdM8PN0K9ME2xwKqz2dMzsDSnO_YWg4wmhLSpApEg'
$boolDisableSSLCheck    = $true #Set to True To invoke REst call without SSL validation

#$CustomerContext         = 'MasterTenantContext'
$CustomerTenantURL       = 'https://fr-consulting.eu.qlikcloud.com'
$CustomerDeploymentName  = 'CustomerA'
#$tenantId                = '' #let empty to retrieve it automatically

# Step 1. Create QSE Multi Cloud Deployment

#Define the header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $QSEJWTToken")
$headers.Add("Content-Type", "application/json")


if ($boolDisableSSLCheck)
{
#Disable SSL Check (if not trusted only...)
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

#Define the body
$body = "{
    `n  `"name`": `"$CustomerDeploymentName`",
    `n  `"audience`": `"qlik.api`",
    `n  `"serviceUrl`": `"$CustomerTenantURL`",
    `n  `"localBearerToken`": true
    `n}"

#Invoke API Call
$response = Invoke-RestMethod "$QSEEnvironmentURL$QSEJWTPrefix/api/hds/v1/Deployments" -Method 'POST' -Headers $headers -Body $body
#$response | ConvertTo-Json
$deploymentId = $response.id
#$deploymentId

# Step 2. Get the bearer token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $QSEJWTToken")
$headers.Add("Content-Type", "application/json")

$accessToken = Invoke-RestMethod "$QSEEnvironmentURL$QSEJWTPrefix/api/hds/v1/Deployments/$deploymentId/elastictokenconfig?qcsFormat=True" -Method 'GET' -Headers $headers
$accessToken

# Step 3. Qlik Cloud : Create IDP Connection
#Connect to target tenant
setup_cli_context $targetTenantHostname
qlik context use $targetTenantHostname

$tenantId  = (qlik user me | convertfrom-JSON).tenantId

$body = "{`"provider`": `"qlik`",`"description`": `"Automatic`",`"base64Encoded`": `"$accessToken`",`"interactive`": false,`"protocol`": `"qsefw-local-bearer-token`",`"tenantIds`": [`"$tenantId`"]}"

$b = ConvertTo-Json $body
qlik raw post v1/identity-providers --body $b.ToString()
