param(
    [string] $VaultSubscriptionId = 'b41216a4-a3f7-4165-b575-c594944d46d1',
    [string] $VaultResourceGroupName ='rg-dr-eus2',
    [string] $VaultName = 'asr-eus2',
    [string] $PrimaryRegion = 'East US2',
    [string] $RecoveryRegion = 'Central US',
    [string] $RecoveryPlanName = 'FullRecovery',
    [string] $sourcevmsresourceGroup = 'rg-dr-eus2',
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
$priFabric = Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $PrimaryRegion -or $_.FabricSpecificDetails.Location -like $PrimaryRegion.Replace(' ', '')}
$priContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $priFabric

$recFab = Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $RecoveryRegion -or $_.FabricSpecificDetails.Location -like $RecoveryRegion.Replace(' ', '')}
$recContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $recFab

$reverseContainerMapping = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $recContainer | Where-Object {$_.TargetProtectionContainerId -like $priContainer.Id}

$priContainerRPIS = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $priContainer
$rpisInContainer = $priContainerRPIS | Where-Object {$sourceVmIds -contains $_.ProviderSpecificDetails.FabricObjectId}
$rpisInContainer

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
        -LogStorageAccountId $RecoveryStagingStorageAccount -ManagedDisk  -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
        -RecoveryResourceGroupId  $sourceVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType          
    $diskList.Add($osDisk)
    
    foreach($dataDisk in $drVM.StorageProfile.DataDisks)
    {
        $disk = New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig -DiskId $dataDisk.ManagedDisk.Id `
            -LogStorageAccountId $RecoveryStagingStorageAccount -ManagedDisk  -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
            -RecoveryResourceGroupId  $sourceVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType
        $diskList.Add($disk)
    }
    
    $message = 'Reverse replication being triggered'
    Write-Output $message
    $reverseReplicationJob = Update-AzRecoveryServicesAsrProtectionDirection -AzureToAzure -LogStorageAccountId $RecoveryStagingStorageAccount  -ProtectionContainerMapping             $reverseContainerMapping  -RecoveryResourceGroupId $sourceVmResourceGroupId -ReplicationProtectedItem $rpi
    $reverseReplicationJobs.Add($reverseReplicationJob)
    }

    $message = 'Reverse replication has been triggered for all vms in Recovery Plan - ' + $RecoveryPlanName
    Write-Output $message

$DeploymentScriptOutputs['ReprotectedItemIds'] = $sourceVmIds -Join ','

$message = 'Reprotected Items Ids {0}' -f $DeploymentScriptOutputs['ReprotectedItemIds']
Write-Output $message