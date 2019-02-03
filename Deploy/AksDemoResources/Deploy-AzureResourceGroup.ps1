#Requires -Version 3.0

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] $ResourceGroupName = 'AksDemoResourcesMsi',
    [string] $TemplateFile = 'azuredeploy.json',
	[string] $clusterName,
	[string] $clusterResourceGroupName
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

$OptionalParameters = New-Object -TypeName Hashtable

$context = Get-AzureRmContext
$subscriptionId = $context.Subscription.Id

$OptionalParameters.tenantId = $context.Tenant.Id

$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup `
  -Name $ResourceGroupName `
  -Location $ResourceGroupLocation `
  -Verbose `
  -Force

$deployment = New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                   -ResourceGroupName $ResourceGroupName `
                                   -TemplateFile $TemplateFile `
                                   @OptionalParameters `
                                   -Force -Verbose `
                                   -ErrorVariable ErrorMessages

if ($ErrorMessages) {
    Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
}

Write-Host $deployment.Outputs

$KeyVaultUrl = $deployment.Outputs.keyVaultUrl.Value
$managedIdentityResourceId = $deployment.Outputs.identityResourceId.Value
$managedIdentityClientId = $deployment.Outputs.identityClientId.Value

Write-Host "Deployment completed"

Write-Host "Retrieving AKS instance"

$aks = Get-AzureRmResource `
  -Name $clusterName `
  -ResourceGroupName $clusterResourceGroupName `
  -ResourceType Microsoft.ContainerService/managedClusters

$roleDefinitionName = "Managed Identity Operator"

Write-Host "AKS Instance retrieved"
$aksPrincipalId = $aks.Properties.servicePrincipalProfile.clientId

Write-Host "Checking if role assignment already exists"
# Note: this requires permissions over graph api

$assignment = Get-AzureRmRoleAssignment `
    -Scope $managedIdentityResourceId `
    -RoleDefinitionName $roleDefinitionName `
    -ServicePrincipalName $aksPrincipalId

if (!$assignment) {
    Write-Host "assigning role to $aksPrincipalId"
    New-AzureRmRoleAssignment `
    -ApplicationId $aks.Properties.servicePrincipalProfile.clientId `
    -Scope $managedIdentityResourceId `
    -RoleDefinitionName 
}

Write-Host "##vso[task.setvariable variable=KeyVaultUrl;]$KeyVaultUrl"
Write-Host "##vso[task.setvariable variable=managedIdentityResourceId;]$managedIdentityResourceId"
Write-Host "##vso[task.setvariable variable=managedIdentityClientId;]$managedIdentityClientId"
