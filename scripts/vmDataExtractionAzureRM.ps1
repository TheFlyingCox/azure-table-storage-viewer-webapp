#Provide the subscription Id of the subscription where VMs exists
#Currently set to U360-Sandbox-Gov
$sourceSubscriptionId='f4b64c47-a43e-46e4-abc3-0097a2b9532e'

#Set the context to the subscription Id where VMs exists
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId

#Set the desired location
$location = 'useast2'

#Set the name of the target storage account
$storageAccountName = 'sainventoryappva'

#Set the name of the target storage table
$tableName = 'inventoryTable'

#Set the resource group name containing the storage account
$resourceGroupName = 'rg_inventory'

#Check for existing Resource Group. Create if non-existing
<#try {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction Stop
} catch {
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
}

#Check for existing Storage Account. Create if non-existing
try {
    $storageAccount = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName -ErrorAction Stop
} catch {
    $storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName `
      -Name $storageAccountName `
      -Location $location `
      -SkuName Standard_LRS `
      -Kind Storage
}
#>

#Set the storage context
$ctx = New-AzureRmStorageContext -ConnectionString "DefaultEndpointsProtocol=https;AccountName=sainventoryappva;AccountKey=JQVMC9ZzC0pfVWUgwz/XQLpqJ8sj5eqxfkDw2z+tp1KiOyqzp+YcHrlwdWxqFVuhU1yHYoGZrTXFUT40CUO8JA==;EndpointSuffix=core.usgovcloudapi.net"
#$ctx = $storageAccount.Context

$table = Get-AzureRmStorageTable -Context $ctx -Name $tableName

#Check for existing Table in target Storage Account. Create if non-existing
#try {
#    $table = Get-AzTableTable -resourceGroup $resourceGroupName -TableName $tableName -storageAccountName $storageAccountName -ErrorAction Stop
#} catch {
#    $table = New-AzStorageTable -Name $tableName -Context $ctx
#}

#Get all the VMs for the target subscription
$VMS = Get-AzureRmVM

#######################################################
##Iterate through VM objects and populate table entries
#######################################################
foreach($VM in $VMS) {

$vmrg = $VM.ResourceGroupName
$VMName = $VM.Name
$vmRowkey = "$($vmrg)-$($VMName)"

#Need VMName, Wave, Function(?), Subnet, IP, Size, Disks
#
#Wave = Will need to automatically tag existing resources with associated Wave
#Function = Will need to discuss where this information will be pulled from
#Can't get the disk size unless the VM is running *
#Need to add functionality to handle multiple datadisks. Formatting can occur on the webapp side of things
$dataDisks = $VM.StorageProfile.DataDisks
$dataDisk = ""
if($dataDisks){
    if($dataDisks.Count -gt 1) {
        foreach($_disk in $dataDisks) {
            $disk = Get-AzureRmDisk -DiskName $_disk.Name
            $dataDisk += "$($disk.Name)($($disk.DiskSizeGB)GB),"
        }
        $dataDisk = $dataDisk.TrimEnd(',')
    } else {
        $disk = Get-AzureRmDisk -DiskName $dataDisks.Name
        $dataDisk = "$($disk.Name)($($disk.DiskSizeGB)GB)"
    }
} else {
    $dataDisks="NA"
}

$vmSize = $VM.HardwareProfile.VmSize
#Need to add functionality to handle multiple Nics. Formatting can occur on the webapp side of things
$NICs = $VM.NetworkProfile.NetworkInterfaces
$NIC = ""
if($NICs){
    if($NICs.Count -gt 1) {
        foreach($_NIC in $NICS) {
            $NICid = $_NIC.Id
            $NICobj = Get-AzureRmNetworkInterface -ResourceId $NICid
            $IPs = $NICobj.IpConfigurations.PrivateIpAddress
            if($IPs.Count -gt 1) {
                $NIC = "$($NICobj.Name)("
                foreach($IP in $IPs) {
                    $NIC += "$($IP),"
                }
                $NIC = $NIC.TrimEnd(',')
                $NIC += ")"
            } else {
                $NIC = "$($NICobj.Name)($($NICobj.IpConfigurations.PrivateIpAddress))"
            }
            $NIC += ","
        }
        $NIC = $NIC.TrimEnd(",")
    } else {
        $NICid = $NICs.Id
        $NICobj = Get-AzureRmNetworkInterface -ResourceId $NICid
        $IPs = $NICobj.IpConfigurations.PrivateIpAddress
        if($IPs.Count -gt 1) {
            $NIC += "$($NICobj.Name)("
            foreach($IP in $IPs) {
                $NIC += "$($IP),"
            }
            $NIC = $NIC.TrimEnd(',')
            $NIC += ")"
        } else {
            $NIC = "$($NICobj.Name)($($NICobj.IpConfigurations.PrivateIpAddress))"
        }
    }
} else {
    $NICs="NA"
}

$SubnetId = $NICobj.IpConfigurations.Subnet.Id
$subnetInfo = $SubnetId.Split('/')
$subnetName = $subnetInfo[$subnetInfo.Count-1]

Add-AzureRmTableRow `
    -table $table `
    -partitionKey 'VM' `
    -rowKey ($vmRowkey) -property @{"Name"=$($VMName);"Wave"="TBD";"Function"="TBD";"Subnet"=$($subnetName);"IP"=$($NIC);"Size"=$($vmSize);"Disks"=$($dataDisk)}
    #@{"Name"=$($VMName);"Wave"="TBD"} }
    #
}

#########################################
##Iterate through Load Balancer Resources
#########################################

$LBS = Get-AzureRmLoadBalancer

foreach($lb in $LBS) {

$lbrg = $lb.ResourceGroupName
$lbName = $lb.Name
$lbRowkey = "$($lbrg)-$($lbName)"
$IP = $lb.FrontendIpConfigurations.PrivateIpAddress

Add-AzureRmTableRow `
    -table $table `
    -partitionKey 'LB' `
    -rowKey ($lbRowkey) -property @{"Name"=$($lbName);"Wave"="TBD";"Function"="Load Balancer";"Subnet"="NA";"IP"=$($IP);"Size"="NA";"Disks"="NA"}
}