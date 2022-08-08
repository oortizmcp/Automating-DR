param(
    [string] $VaultSubscriptionId = 'b41216a4-a3f7-4165-b575-c594944d46d1',
    [string] $VaultResourceGroupName ='rg-dr-eus2',
    [string] $VaultName = 'asr-eus2',
    [string] $PrimaryRegion = 'East US2',
    [string] $RecoveryRegion = 'Central US',
    [string] $RecoveryPlanName = 'FullRecovery',
    [string] $sourcevmsresourceGroup = 'rg-dr-eus2',
    [string] $drvmsresourceGroup = 'rg-dr-cus',
    [string] $PrimaryStagingStorageAccount = '/subscriptions/b41216a4-a3f7-4165-b575-c594944d46d1/resourceGroups/rg-dr-eus2/providers/Microsoft.Storage/storageAccounts/saomni52kfceg36bmx4eus2',
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

    $RecoveryPlan = (Get-AzRecoveryServicesAsrRecoveryPlan -Name $RecoveryPlanName)
    $vmNames = $RecoveryPlan.Groups.ReplicationProtectedItems.FriendlyName
    $vmNames[$items.count]
    $message = 'Performing Failback for ' + $vmNames + ' in vault ' + $VaultName
    Write-Output $message
    # Main (Original Source Region) VmId
    $sourcevmIds = New-Object System.Collections.ArrayList
    foreach ($vm in $vmNames)
    {
        $vmid = (Get-AzVm -ResourceGroupName $sourcevmsresourceGroup -name $vm).Id
        $sourcevmIds.Add($vmid.Trim())
    }
    $sourcevmIds

    # Destination (Secondary region) where the vms currently are
    $drvmIds = New-Object System.Collections.ArrayList
    foreach ($vm in $vmNames)
    {
        $vmid = (Get-AzVm -ResourceGroupName $drvmsresourceGroup -name $vm).Id
        $drvmIds.Add($vmid.Trim())
    }
    $drvmIds


# Look up the protection container mapping to be used for the enable replication.
$priFabric = Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $RecoveryRegion -or $_.FabricSpecificDetails.Location -like $RecoveryRegion.Replace(' ', '')}
$priContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $priFabric
$recFabric = Get-AzRecoveryServicesAsrFabric | Where-Object {$_.FabricSpecificDetails.Location -like $PrimaryRegion -or $_.FabricSpecificDetails.Location -like $PrimaryRegion.Replace(' ', '')}

$recContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $recFabric
$reverseContainerMapping = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $recContainer | Where-Object {$_.TargetProtectionContainerId -like $priContainer.Id}

$priContainerRPIS = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $priContainer
$rpisInContainer = $priContainerRPIS | Where-Object {$drvmIds -contains $_.ProviderSpecificDetails.FabricObjectId}
$rpisInContainer

# Setup the vault context.
$message = 'Replication protected Items in Container:'
Write-Output $message
$rpisInContainer

$message = 'Triggering failover for Recovery Plan - ' + $RecoveryPlanName
Write-Output $message
$job = Start-AzRecoveryServicesAsrUnPlannedFailoverJob -RecoveryPlan $RecoveryPlan -Direction RecoveryToPrimary
$failoverJob.Add($job)

    do {
        Start-Sleep -Seconds 30
        $job = Get-AzRecoveryServicesAsrJob -Job $job
        Write-Output $job.State
    } while ($job.State -ne 'Succeeded' -and $job.State -ne 'Failed' -and $job.State -ne 'CompletedWithInformation')

        if($job.State -eq 'Failed'){
            $message = 'Job{0} failed for {1}' -f $job.DisplayName, $job.TargetObjectName
            Write-Output $message
            foreach ($er in $job.Errors) {
                foreach ($pe in $er.ProviderErrorDetails) {
                    $pe
                }
        
                foreach ($se in $er.ServiceErrorDetails) {
                    $se
                }
               }
               throw $message
            }

$message = 'Failover completed for ' + $RecoveryPlan.Name + ' with state {0}. Starting commit Fail Over.' -f $job.State
Write-Output $message
$commitJob = Start-AzRecoveryServicesAsrCommitFailoverJob -RecoveryPlan $RecoveryPlan
$commitJob

    do{
        Start-Sleep -Seconds 30
        $job = Get-AzRecoveryServicesAsrJob -Job $commitJob
        Write-Output $job.State
    } while ($job.State -ne 'Succeeded' -and $job.State -ne 'Failed' -and $job.State -ne 'CompletedWithInformation')

    $message = 'Committed Failover for ' + $RecoveryPlan.Name



## Trigger Reverse Replication for Vms
$reverseReplicationJobs = New-Object System.Collections.ArrayList
    foreach ($rpi in $rpisInContainer) {
        $sourceVmResourceGroupId = $rpi.ProviderSpecificDetails.RecoveryAzureResourceGroupId
        $sourceVmResourceGroupName = $sourceVmResourceGroupId.Split('/')[4]
        $ProtectedItemName = $rpi.FriendlyName
        $sourceVM = Get-AzVM -ResourceGroupName $sourceVmResourceGroupName -Name $ProtectedItemName
    
        $message = 'Reverse replication to be triggered for {0}' -f $sourceVM.ID
        Write-Output $message
        $currentVmArmId = $rpi.ProviderSpecificDetails.FabricObjectId
        $currentVmResourceGroupId = $currentVmArmId.Substring(0, $currentVmArmId.ToLower().IndexOf('/providers'))
    
        $message = 'Storage account to be used {0}' -f $PrimaryStagingStorageAccount
        Write-Output $message
        
        # Prepare disk configuration.
        $diskList =  New-Object System.Collections.ArrayList
        $osDisk =    New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig -DiskId $sourceVM.StorageProfile.OsDisk.ManagedDisk.Id `
            -LogStorageAccountId $PrimaryStagingStorageAccount -ManagedDisk -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
            -RecoveryResourceGroupId  $currentVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType          
        $diskList.Add($osDisk)
        
        foreach($dataDisk in $sourceVM.StorageProfile.DataDisks)
        {
            $disk = New-AzRecoveryServicesAsrAzureToAzureDiskReplicationConfig -DiskId $dataDisk.ManagedDisk.Id `
                -LogStorageAccountId $PrimaryStagingStorageAccount -ManagedDisk -RecoveryReplicaDiskAccountType $RecoveryReplicaDiskAccountType `
                -RecoveryResourceGroupId  $currentVmResourceGroupId -RecoveryTargetDiskAccountType $RecoveryTargetDiskAccountType
            $diskList.Add($disk)
        }
        
        $message = 'Reverse replication being triggered'
        Write-Output $message
        $reverseReplciationJob = Update-AzRecoveryServicesAsrProtectionDirection -AzureToAzure -LogStorageAccountId $PrimaryStagingStorageAccount -ProtectionContainerMapping $reverseContainerMapping -RecoveryResourceGroupId $currentVmResourceGroupId -ReplicationProtectedItem $rpi
        
        $message = 'Reverse replication triggered with job# {0} for VM {1}' -f $reverseReplciationJob.Name, $reverseReplciationJob.TargetObjectName
        Write-Output $message
        $reverseReplicationJobs.Add($reverseReplciationJob)    
    }

    $message = 'Reverse replication has been triggered for all vms.'
    Write-Output $message

$DeploymentScriptOutputs['FailedBackVMIds'] = $sourcevmIds -Join ','
