param (
    [string]
    $sourceConnectionString = $(throw "-sourceConnectionString is required."),
    [string]
    $sourceTableName = $(throw "-sourceConnectionString is required."),
    [string]
    $targetConnectionString = $(throw "-targetConnectionString is required."),
    [string]
    $targetTableName = $(throw "-targetTableName is required.")
 )

function Insert-Records
{
    param ($table, $entities)

    $batches = @{}

    foreach ($entity in $entities)
    {
       if ($batches.ContainsKey($entity.PartitionKey) -eq $false)
       {
           $batches.Add($entity.PartitionKey, (New-Object Microsoft.WindowsAzure.Storage.Table.TableBatchOperation))
       }

       $batch = $batches[$entity.PartitionKey]
       $batch.Add([Microsoft.WindowsAzure.Storage.Table.TableOperation]::InsertOrReplace($entity));

       if ($batch.Count -eq 100)
       {
           $table.ExecuteBatch($batch);
           $batches[$entity.PartitionKey] = (New-Object Microsoft.WindowsAzure.Storage.Table.TableBatchOperation)
       }
    }

    foreach ($batch in $batches.Values)
    {
        if ($batch.Count -gt 0)
        {
            $table.ExecuteBatch($batch);
        }
    }
}

function Copy-Records
{
    param($sourceTable, $targetTable)

    $tableQuery = New-Object 'Microsoft.WindowsAzure.Storage.Table.TableQuery'

    [Microsoft.WindowsAzure.Storage.Table.TableContinuationToken]$token = $null

    do
    {
        $segment = $sourceTable.ExecuteQuerySegmented($tableQuery, $token);
        $token = $segment.ContinuationToken

        Insert-Records $targetTable $segment.Results

        $count = $segment.Results.Count
        Write-Host "Copied $count records"
    } while ($token -ne $null)
}

function Get-Table
{
    param($storageContext, $tableName, $createIfNotExists)

    $table = Get-AzureStorageTable $tableName -Context $storageContext -ErrorAction Ignore
    if ($table -eq $null)
    {
        if($createIfNotExists -eq $false)
	{
	    return $null
	}

        $table = New-AzureStorageTable $tablename -Context $storageContext
    }

    return $table.CloudTable
}

$sourceContext = New-AzureStorageContext -ConnectionString $sourceConnectionString
$targetContext = New-AzureStorageContext -ConnectionString $targetConnectionString

$sourceTable = Get-Table $sourceContext $sourceTableName $false
if ($sourceTable -eq $null)
{
    Write-Host "Source table $sourceTableName was not found"
    return
}

$targetTable = Get-Table $targetContext $targetTableName $true

Copy-Records $sourceTable $targetTable
