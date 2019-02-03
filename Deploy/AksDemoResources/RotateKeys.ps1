$resourceGroupName = "AksDemoResourcesMsi"
$cosmosDbAccountName = "composedemodbieqyyakrzjc7e"
$vaultName = "aksKeyVaultieqyyakrzjc7e"

Write-Host "Rotating primary key in $cosmosDbAccountName CosmosDb account..."

Invoke-AzureRmResourceAction -Action regenerateKey `
    -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
    -ApiVersion "2015-04-08" `
    -ResourceGroupName $resourceGroupName `
    -Name $cosmosDbAccountName `
    -Parameters @{"keyKind"="Primary"} `
    -Force

Write-Host "Primary Key successfully rotated"
Write-Host "Retrieving key for $cosmosDbAccountName..."

$keys = Invoke-AzureRmResourceAction -Action listKeys `
    -ResourceType "Microsoft.DocumentDb/databaseAccounts" `
    -ApiVersion "2015-04-08" `
    -ResourceGroupName $resourceGroupName `
    -Name $cosmosDbAccountName -Force
$primaryKey = $keys.primaryMasterKey

Write-Host "Primary key successfully retrieved"

$newConnectionString = ConvertTo-SecureString ("mongodb://$cosmosDbAccountName" + ":$primaryKey@$cosmosDbAccountName.documents.azure.com:10250/?ssl=true") `
    -AsPlainText -Force

Write-Host "Storing the new connectionString in keyVault $vaultName"

Set-AzureKeyVaultSecret -VaultName $vaultName `
    -Name "cosmosdb" -SecretValue $newConnectionString