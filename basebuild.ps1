<# This script will create an azure machine in a resource group that you define , it can be run individually
or it can be called from a master script #>
#defines the location that all of our resources are in
$location = "UK South"

# Defines the default user name and password
$securePassword = ConvertTo-SecureString 'xxxxxxxxxxxxxxxxx' -AsPlainText -Force
$cred1 = New-Object System.Management.Automation.PSCredential ("username", $securePassword)

#define variables below, for Resource Group, sub group and the vm name
# groups are defined for the over all RG (management) and then the sub RG (EnviromentOne)
$resourceGroup1= "Management"
$resourceGroup = "EnvironmentOne"
$vmname1="vm1"
$nicname="vmnic001"

#Display Vnet & Subnets
#this machine sits in the following subnet - only change this if the design changes
$subnetname="ASubnet"

$VNET = Get-AzureRmVirtualNetwork -Name "EnvironmentOne"  -ResourceGroupName $resourceGroup1

$subnetID =(Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet).Id

 # Create a public IP address and specify a DNS name [not required for this machine]
#$pip1 = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location -Name "vmnic001" -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create a virtual network card and associate with public IP address and NSG
$nic1 = New-AzureRmNetworkInterface -Name $nicname  -ResourceGroupName $resourceGroup -Location $location -SubnetId $SubnetID

# define which Storage Account to use
$storageaccountname="test1storage"
$storageaccount = Get-azureRMStorageAccount -Name $storageaccountname -ResourceGroupName $resourceGroup

# Set up a pretty name for the VM's disks in the storage account - datadisk2 not required at this time

$OsDisk1Name = $vmname1 + "-OsDisk"
$OSDisk1Uri = $($storageaccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $OsDisk1Name + ".vhd").ToLower()

$DataDiskName1 = $vmname1 + "-DataDisk1"
#$DataDiskName2 = $vmname1 + "-DataDisk2"
$DataDisk1Uri= $($storageaccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName1 + "-DataDisk1.vhd").ToLower()
#$DataDisk2Uri= $($storageaccount.PrimaryEndpoints.Blob.ToString() + "vhds/" + $vmName1 + "-DataDisk2.vhd").ToLower()

# Create a virtual machine configuration

$vmconfig1 = New-AzureRMVmConfig -VMName $vmname1 -VMSize Standard_F2s_v2 |`
Set-AzureRMVMOperatingSystem -Windows -ComputerName $vmname1 -Credential $cred1 -TimeZone "GMT Standard Time" |`
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version Latest | `
Add-AzureRMVMNetworkInterface -Id $nic1.Id |`
Set-AzureRmVMOSDisk -Name "$vmname1.vhd" -VhdUri $OSDisk1Uri -CreateOption FromImage |`
Add-AzureRmVMDataDisk -CreateOption empty -DiskSizeInGB 500 -Name $DataDiskName1 -VhdUri $DataDisk1Uri -Caching ReadOnly -lun 0
#Add-AzureRmVMDataDisk -CreateOption empty -DiskSizeInGB 500 -Name $DataDiskName2 -VhdUri $DataDisk2Uri -Caching ReadOnly -lun 1

# Create a virtual machine

$VM1 = New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig1

#ad join the machine
#set the credentials needed
$string1 = '{
    "Name": "domain.co.uk",
    "User": "domain.co.uk\\useraccouthere",
    "Restart": "true",
    "Options": "3"
    }'

$string2 = '{ "Password": "passwordhere" }'

#do the joining using the azure JsonADDomainExtension method - this is native to azure
Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -ExtensionType "JsonADDomainExtension" `
-Name "joindomain" -Publisher "Microsoft.Compute" -TypeHandlerVersion "1.0" `
-VMName $vmname1 -Location 'UK South' -SettingString $string1 -ProtectedSettingString $string2

#attach any data disks this uses a custom extension that calls a script stored in our storage blob
#define the parameters
$fileUri = @("https://tstdeploymentstorage.blob.core.windows.net/scripts/disks-test.ps1")

$Settings = @{"fileUris" = $fileUri};

$vmname = $vmname1

$storageaccname = "tstdeploymentstorage"
$storagekey = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
$ProtectedSettings = @{"storageAccountName" = $storageaccname; "storagekey"= $storagekey; "commandToExecute" = "powershell -ExecutionPolicy Unrestricted -File C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.9.1\Downloads\0\disks-test.ps1"};

#actually do the work
Set-AzureRmVMExtension -ResourceGroupName $resourceGroup -Location 'UK South' -VMName $vmname -Name "scripts" -Publisher "Microsoft.Compute" -ExtensionType "CustomScriptExtension" -TypeHandlerVersion "1.9" -Settings $Settings -ProtectedSettings $ProtectedSettings
