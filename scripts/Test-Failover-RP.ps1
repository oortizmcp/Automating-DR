param(
    [string] $VaultSubscriptionId="<your_vault_subscription_id>",
    [string] $VaultResourceGroupName="<your_vault_resource_group_name>",
    [string] $VaultName="<your_vault_name>",
    [string] $PrimaryRegion="<your_primary_region>",
    [string] $RecoveryRegion="<your_recovery_region>",
    [string] $RecoveryPlanName='<your_recovery_plan_name>',
    [string] $RecoveryVnetId="<your_recovery_vnet_id in Target Region>",
    [string] $vmsResourceGroup = '<your_vms_resource_group_name>',
    [string] $RecoveryStagingStorageAccount="<your_recovery_staging_storage_account_resource_Id_in_Target_Region>",
    [string] $RecoveryReplicaDiskAccountType = 'Standard_LRS',
    [string] $RecoveryTargetDiskAccountType = 'Standard_LRS'
    )

$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Proceeding with Cleanup"
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Cancel Cleanup"
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)




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
    $message = 'Performing Test Failover for vms in Recovery Plan - ' + $RecoveryPlan.FriendlyName + ' in vault {0}' -f $VaultName
    Write-Output $message 

    $sourceVmIds = New-Object System.Collections.ArrayList
    foreach ($vm in $vmNames)
    {
        $vmid = (Get-AzVm -ResourceGroupName $vmsResourceGroup -name $vm).Id
        $sourceVmIds.Add($vmid.Trim())
    }
    
    $sourceVmIds

# Look up the protection container mapping to be used for the enable replication.
$priFabric = Get-AzRecoveryServicesAsrFabric | where {$_.FabricSpecificDetails.Location -like $PrimaryRegion -or $_.FabricSpecificDetails.Location -like $PrimaryRegion.Replace(' ', '')}
$priContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $priFabric
$recFab = Get-AzRecoveryServicesAsrFabric | where {$_.FabricSpecificDetails.Location -like $RecoveryRegion -or $_.FabricSpecificDetails.Location -like $RecoveryRegion.Replace(' ', '')}
$recContainer = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $recFab
$reverseContainerMapping = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $recContainer | where {$_.TargetProtectionContainerId -like $priContainer.Id}

$priContainerRPIS = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $priContainer
$rpisInContainer = $priContainerRPIS | where {$sourceVmIds -contains $_.ProviderSpecificDetails.FabricObjectId}
$rpisInContainer

# Setup the vault context.
$message = 'Replication protected Items in Container:'
Write-Output $message
$rpisInContainer

$testfailoverJobs = New-Object System.Collections.ArrayList
$rpiLookUpByJobId = @{}
foreach ($rpi in $rpisInContainer) {
    # Trigger Test Failover.
    $message = 'Triggering test failover for {0}.' -f $rpi.FriendlyName
    Write-Output $message
    $job = Start-AzRecoveryServicesAsrTestFailoverJob -ReplicationProtectedItem $rpi -Direction PrimaryToRecovery -AzureVMNetworkId $RecoveryVnetId
    $testfailoverJobs.Add($job)
    $rpiLookUpByJobId[$job.Id] = $rpi
}


# Initiate Test Failover
foreach ($job in $testfailoverJobs) {
    do {
        Start-Sleep -Seconds 50
        $job = Get-AzRecoveryServicesAsrJob -Job $job
        Write-Output $job.State
    } while ($job.State -ne 'Succeeded' -and $job.State -ne 'Failed' -and $job.State -ne 'CompletedWithInformation')

    if ($job.State -eq 'Failed') {
       $message = 'Job {0} failed for {1}' -f $job.DisplayName, $job.TargetObjectName
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
    
    $message = 'TestFailover completed for {0} with state {1}. ' -f $job.TargetObjectName, $job.State
    Write-Output $message
    $rpi = $rpiLookUpByJobId[$job.ID]    
}

# Cleanup task
$title = "CleanUp Task" 
$question = "Do you want to proceed with Cleanup?"
$result = $host.ui.PromptForChoice($title, $question, $options, 0)
switch ($result) {
  0{
    Write-Host "Yes"
  }1{
    Write-Host "No - Remember to Cleanup your resources manually" { break }
  }
}

$testcleanupfailoverJobs = New-Object System.Collections.ArrayList
$rpiLookUpByJobId =@{}
# Cleaning up test failover tasks
foreach ($rpi in $rpisInContainer) {
    # Test Failover cleanup.
    $message = 'Triggering test failover cleanup for {0}.' -f $rpi.FriendlyName
    Write-Output $message
    $cleanupjob = Start-AzRecoveryServicesAsrTestFailoverCleanupJob -ReplicationProtectedItem $rpi -Comment "Test failover Completed successfully"
    $testcleanupfailoverJobs.Add($cleanupjob)
    $rpiLookUpByJobId[$cleanupjob.Id] = $rpi
}

foreach ($cleanupjob in $testfailovercleanupJobs) {
    do {
        Start-Sleep -Seconds 50
        $cleanupjob = Get-AzRecoveryServicesAsrJob -Job $cleanupjob
        Write-Output $cleanupjob.State
    } while ($cleanupjob.State -ne 'Protected' -and $cleanupjob.State -ne 'Failed' -and $cleanupjob.State -ne 'CompletedWithInformation')

    if ($cleanupjob.State -eq 'Failed') {
       $message = 'Job {0} failed for {1}' -f $cleanupjob.DisplayName, $cleanupjob.TargetObjectName
       Write-Output $message
       foreach ($er in $cleanupjob.Errors) {
        foreach ($pe in $er.ProviderErrorDetails) {
            $pe
        }

        foreach ($se in $er.ServiceErrorDetails) {
            $se
        }
       }

       throw $message
    }    
    
    $message = 'TestFailover Cleanup tasks completed for {0} with state {1}. ' -f $cleanupjob.TargetObjectName, $cleanupjob.State
    Write-Output $message
    $rpi = $rpiLookUpByJobId[$cleanupjob.ID]    
}