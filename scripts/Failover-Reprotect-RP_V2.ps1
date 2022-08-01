param(
    [string] $VaultSubscriptionId = 'b41216a4-a3f7-4165-b575-c594944d46d1',
    [string] $VaultResourceGroupName ='rg-dr-eus2',
    [string] $VaultName = 'asr-eus2',
    [string] $PrimaryRegion = 'eastus2',
    [string] $RecoveryRegion = 'centralus',
    [string] $RecoveryPlanName = 'FullRecovery',
    [string] $vmsResourceGroup = 'rg-dr-eus2',
    [string] $drvmsresourceGroup = 'rg-dr-cus',
    [string] $RecoveryStagingStorageAccount = '/subscriptions/b41216a4-a3f7-4165-b575-c594944d46d1/resourceGroups/rg-dr-cus/providers/Microsoft.Storage/storageAccounts/saomni52kfceg36bmx4cus',
    [string] $RecoveryReplicaDiskAccountType = 'Standard_LRS',
    [string] $RecoveryTargetDiskAccountType = 'Standard_LRS'
    )

# Initialize the designated output of deployment script that can be accessed by various scripts in the template.
$DeploymentScriptOutputs = @{}

# Setup the vault context.
$message = 'Setting Vault context using vault {0} under resource group {1} in subscription {2}.' -f $VaultName, $VaultResourceGroupName, $VaultSubscriptionId
Write-Output $message
Select-AzSubscription -SubscriptionId $VaultSubscriptionId
$vault = Get-AzRecoveryServicesVault -ResourceGroupName $VaultResourceGroupName -Name $VaultName
Set-AzRecoveryServicesAsrVaultContext -vault $vault
    # Get Recovery Plan details
    $RecoveryPlan = (Get-AzRecoveryServicesAsrRecoveryPlan -Name $RecoveryPlanName)
    $vmNames = $RecoveryPlan.Groups.ReplicationProtectedItems.FriendlyName
    $message = 'Performing Failover for vms in Recovery Plan ' + $RecoveryPlan.FriendlyName + ' in vault {0}.' -f $VaultName
    Write-Output $message

    $sourceVmIds = New-Object System.Collections.ArrayList
    foreach ($vm in $vmNames)
    {
        $vmid = (Get-AzVm -ResourceGroupName $vmsResourceGroup -name $vm).Id
        $sourceVmIds.Add($vmid.Trim())
    }

    $sourceVmIds


# Look up the protection container mapping to be used for the enable replication.
function Get-ContainerDetails 
{
    try {
        # If created replication plan from portal. Azure creates a Fabric by default with name like line 47. 
        # Otherwise, if created using a script, you can use line 46 to check for Fabric created
        # $priFabric = (Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $PrimaryRegion -or $_.FabricSpecificDetails.Location -like $PrimaryRegion.Replace(' ', '')}).name
        $priFabric = Get-AzRecoveryServicesAsrFabric -Name "asr-a2a-default-$PrimaryRegion"
        $priContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $priFabric
        # Same as line 44 but with recovery Fabric. Use line 50 or 51 depending on your scenario.
        # $recFabric = (Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $RecoveryRegion -or $_.FabricSpecificDetails.Location -like $RecoveryRegion.Replace(' ', '')}).name
        $recFabric = Get-AzRecoveryServicesAsrFabric -Name "asr-a2a-default-$RecoveryRegion"
        $recContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $recFabric
        $reverseContainerMapping = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $recContainer | Where-Object {$_.TargetProtectionContainerId -like $priContainer.Id}
        $priContainerRPIS = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $priContainer
        $rpisInContainer = $priContainerRPIS | Where-Object {$sourceVmIds -contains $_.ProviderSpecificDetails.FabricObjectId}
        $rpisInContainer 
    }
    catch {
        Write-Host "An Error Occurred" -ForegroundColor Red
        Write-Host "Message: $_ Check the priContainer variable output. " -ForegroundColor Red
        break
    }
    if ( $null -eq $reverseContainerMapping ){
        Write-Host "An Error Occurred" -ForegroundColor Red
        $ErrorMessage = "Message: $_ Check Reverse Container Mapping variable. If multiple priContainer outputs, use indexing at the end of priContainer.Id[] to match correct Container in order to enable reprotection of VMs"
        throw $ErrorMessage
        break
    }
    else {
        $reverseContainerMapping
    }
}

Get-ContainerDetails


# Setup the vault context.
$message = 'Replication protected Items in Container:'
Write-Output $message
$rpisInContainer

$message = 'Triggering failover for Recovery Plan - ' + $RecoveryPlanName
Write-Output $message
$job = Start-AzRecoveryServicesAsrUnPlannedFailoverJob -RecoveryPlan $RecoveryPlan -Direction PrimaryToRecovery
$job

    do {
        Start-Sleep -Seconds 30
        $job = Get-AzRecoveryServicesAsrJob -Job $job
        Write-Output $job.State
    } while ($job.State -ne 'Succeeded' -and $job.State -ne 'Failed' -and $job.State -ne 'CompletedWithInformation')

        if($job.State -eq 'Failed'){
            $message = 'Job{0} failed for {1}' -f $job.DisplayName, $job.TargetObjectName
            Write-Output $message
            foreach ($er in $job.Errors){
                foreach ($pe in $er.ProviderErrorDetails){
                    $pe
                }
                foreach ($se in $er.ServiceErrorDetails){
                    $se 
                }
            }
            throw $message
        }

    
$message = 'Failover completed for Recovery Plan - ' + $RecoveryPlanName  + ' with state {0}. Starting commit Fail Over.' -f $job.State
Write-Output $message
$commitJob = Start-AzRecoveryServicesAsrCommitFailoverJob -RecoveryPlan $RecoveryPlan
$commitJob

    do{
        Start-Sleep -Seconds 30
        $job = Get-AzRecoveryServicesAsrJob -Job $commitJob
        Write-Output $job.State
    } while ($job.State -ne 'Succeeded' -and $job.State -ne 'Failed' -and $job.State -ne 'CompletedWithInformation')

    $message = 'Committed Failover for Recovery Plan - ' + $RecoveryPlanName


## Trigger Reverse Replication for Vms
$reverseReplicationJobs = New-Object System.Collections.ArrayList
$drVmArmIds = New-Object System.Collections.ArrayList
    foreach ($rpi in $rpisInContainer){
        $DrResourceGroupId = $rpi.ProviderSpecificDetails.RecoveryAzureResourceGroupId
        $drResourceGroupName = $DrResourceGroupId.Split('/')[4]
        $ProtectedItemName = $rpi.FriendlyName
        $drVM = Get-AzVM -ResourceGroupName $drResourceGroupName -Name $ProtectedItemName

        $message = 'Reverse replication to be triggered for {0}' -f $drVM.ID 
        Write-Output $message
        $SourceVmArmId = $rpi.ProviderSpecificDetails.FabricObjectId
        $sourceVmResourceGroupId = $SourceVmArmId.Substring(0, $SourceVmArmId.ToLower().IndexOf('/providers'))

        $message = 'Storage account to be used {0}' -f $RecoveryStagingStorageAccount
        Write-Output $message

        # Prepare disk configuration.
    $diskList = New-Object System.Collections.ArrayList
    $osDisk = New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig -DiskId $drVM.StorageProfile.OsDisk.ManagedDisk.Id `
        -LogStorageAccountId $RecoveryStagingStorageAccount -ManagedDisk -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
        -RecoveryResourceGroupId $sourceVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType
    $diskList.Add($osDisk)
    
    foreach($dataDisk in $drVM.StorageProfile.DataDisks)
    {
        $disk = New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig -DiskId $dataDisk.ManagedDisk.Id `
            -LogStorageAccountId $RecoveryStagingStorageAccount -ManagedDisk  -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
            -RecoveryResourceGroupId $sourceVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType
        $diskList.Add($disk)
    }
    
    $message = 'Reverse replication being triggered'
    Write-Output $message
    $reverseReplicationJob = Update-AzRecoveryServicesAsrProtectionDirection -AzureToAzure -LogStorageAccountId $RecoveryStagingStorageAccount -ProtectionContainerMapping $reverseContainerMapping -RecoveryResourceGroupId $sourceVmResourceGroupId -ReplicationProtectedItem $rpi
    $reverseReplicationJobs.Add($reverseReplicationJob)
    }

    $message = 'Reverse replication has been triggered for all vms in Recovery Plan - ' + $RecoveryPlanName
    Write-Output $message

    $DeploymentScriptOutputs['ReprotectedItemIds'] = $sourceVmIds -Join ','
    $DeploymentScriptOutputs['DrVmArmIds'] = $drVmArmIds -Join ','

    $message = 'Reprotected Items Ids {0}' -f $DeploymentScriptOutputs['ReprotectedItemIds']
    Write-Output $message