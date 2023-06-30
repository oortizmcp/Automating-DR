# Automating-DR
[Omaha Azure User Group- August 2022 presentation](https://www.youtube.com/watch?v=hhZ4AhQQrQY&t=1313s) - Automating DR with Powershell and Automation Accounts.

## Overview

This project is a proof of concept on how to implement a Disaster Recovery solution using Azure Site Recovery Services. For more information about Azure Site Recovery Services, please visit [Azure Site Recovery Documentation](https://docs.microsoft.com/en-us/azure/site-recovery/).

## Video Tutorial
For a step by step, please check the following videos:
1. [Infra deployment Part 1](https://youtu.be/YVXBpVVF05k)
2. [Failover/Failback Scripts Part 2](https://youtu.be/Fj9NnKGuZLQ)

***
## Infrastructure
Inside the Infra folder, you will can see the infrastructure that is used in this project. Bicep file calls all modules needed to create the resources in Azure which will be described below.

![image](https://user-images.githubusercontent.com/53305878/182245064-65468d0f-6589-4e2e-8903-e603b1764820.png)


1. <u>**Cache Storage Accounts (2)**</u> - One storage account in each region to be used for cache and replication when performing the Failover.

2. <u>**Recovery Vault (1)**</u> - The recovery vault that will be used for backup and replication of items. If you intent to use the same recovery vault for both backups and recovery. You can use the same recovery vault for both (backup and recovery), but Vms will need to be in the same region as the recovery vault.

3. <u>**VMs (2)**</u> - Two VMs for proof of concept purposes.

4. <u>**Availability Zone**</u> - The availability zone that will be used for the VMs. Each vm is using zone 1 and zone 2

5. <u>**Network Interfaces (2)**</u> - Two network interfaces for the VMs.

6. <u>**Internal Load Balancer (1)**</u> - Load balancer to be used for the VMs.

7. <u>**NAT Gateway**</u> - Azure Site Recovery needs to install agent in order to do backups and manage replication. Since Vms are behind a Standard Internal load Balancer, by default, it wouldnt have access to the Microsoft 365 IPs such as login.microsoftonline.com. For outbound access Microsoft recommends to create an Azure Nat Gateway. For more information check the following article on [Issue 2: Site Recovery configuration failed](https://docs.microsoft.com/en-us/azure/site-recovery/azure-to-azure-troubleshoot-network-connectivity#issue-2-site-recovery-configuration-failed-151196).

8. <u>**Virtual Networks (2)**</u> - Two virtual networks (1 per region).

9. <u>**Subnets (at least 1 required)**</u> - In this proof of concept we are creating 2 Two subnets, but only 1 is required. Adjust the template according to your needs.

10. <u>**Public Ips**</u> - Public IPs that will be used by the NAT Gateway to access the VMs.

11. <u>**User Managed Identity**</u> - This managed identity has contibutor access to both resource groups. This will also be used to manage Automation Account to trigger post actions scripts. If you are planning to use Recovery Plans, you can configure post actions scripts to be run after the Vms fail over. For example, you can create a script that when the vms fail over, check if there is a Load Balancer created in the target region and if it doesnt exists, create it and add the vms to it.

***
## Deployment
Login to Azure using CLI and run `az deployment group create` command to deploy the infrastructure. As a Reference, use the parameters.json file provided and change the values to match your environment.

***
## Scripts
Inside the Scripts folder, you will can see the scripts that are used in this project to trigger Failover from Command Line. Besides login with the `az login` command, also make sure you login with `Connect-AzAccount` before running the Failover/Failback Scripts.

1. Enable-Replication-AvZone.ps1 - This is deployed through bicep file in the module asrreplication (see main-avzone.bicep). This will create a site and a Fabric for both regions East US 2 and Central US.

2. If you are not using Recovery Plans to trigger the failovers, you can use the scripts [**Test-Failover.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Test-Failover.ps1) to test the failover. The [**Failover-Reprotect.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Failover-Reprotect.ps1) script will trigger the failover and reprotect the VMs and the [**Failback-Reprotect.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Failback-Reprotect.ps1) script will trigger the failback and reprotect the VMs.

3. If you are using Recovery Plans to trigger the failovers, you can use the scripts [**Test-Failover-RP.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Test-Failover-RP.ps1) to test the failover. The [**Failover-Reprotect-RP_V2.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Failover-Reprotect-RP_V2.ps1) script will trigger the failover and reprotect the VMs and the [**Failback-Reprotect-RP_V2.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Failback-Reprotect-RP_V2.ps1) script will trigger the failback and reprotect the VMs based on Recovery Plans.

4. When using Recovery Plans, you can configure a post action script to be run after the Vms fail over. For example, you can create a script that when the vms fail over, check if there is a Load Balancer created in the target region and if it doesnt exists, create it and add the vms to it. For this, you can configure an Automation Account Runbook in the Target Region and use the [**Create-InternalLoadBalancer.ps1**](https://github.com/oortizmcp/DisasterRecovery/blob/master/scripts/Create-InternalLB-TargetRegion.ps1) script to create the Load Balancer and add the Vms in the Recovery Plan. You can use a storage account to call a template. Check the ARM template under infra folder for an example of creating a load balancer listening to port 80.

## Application Gateway & Traffic Manager

![image](https://github.com/oortizmcp/Automating-DR/assets/53305878/771fc672-5d7c-4e6a-9a3a-5d34eac6a024)

If you are concern on how to Handle DNS after failing over to your Secondary Region in an automated fashion with Azure Site Recovery, you can use Azure Traffic Manager which is a DNS based Load Balancer to check the health of your resources and route the traffic from the non-healthy resource to the healthy resource. In order to attach the endpoint in traffic manager with a load balancer, this needs to be a public load balancer(not internal). However you can add an application gateway in front of your internal load balancer and then put traffic manager in front of your application gateway. Keep in mind you will need always a public facing endpoint so you can associate it with your traffic manager. Also keep in mind that After failing over to your secondary region, if you are using a public load balancer, it will give you an error because public load balancer is not supported for site recovery.

Traffic manager endpoint can be any internet facing service hosted inside or outside Azure. Hence, Traffic manager can route traffic that originates from public internet to a set of endpoints that are also internet facing. So, if you have endpoints that are inside a private network, like an internal Load balancer, or have users making DNS requests from such internal networks, then you can't use traffic manager to route this traffic.

To deploy this type of architecture, you can use the [**main-avzone-tfmngr.bicep**] with the parameters file [**dev-avzone-tmp.parameters.json**]
