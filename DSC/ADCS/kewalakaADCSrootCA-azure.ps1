# This file is licensed under an Apache license, copyright Stu Mace

$resourceGroupName = 'kewalakasqlvms'
$automationAccountName = 'kewalakasqlvms'
$DSCconfigurationName = 'kewalakaADCSrootCA'

$DSCFolder = '.'
. $DSCFolder\kewalakaADCSrootCA.ps1

# get credentials from Azure Automation
$Params = @{"RootCAAdminCredential"="RootCAAdminCredential"}

$ConfigData = @{
    AllNodes = @(

        @{
            Nodename = "*"
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true  # DSC resources are encrypted on Azure, so this is OK
            RebootIfNeeded = $true
        },

        @{
            Nodename = "root-CA"
            Role = "Root CA for Windows ADCS (PKI)"
            SiteName = "SouthEastAsia"
            InstallRSATTools = $true
            CACommonName = "kewalaka.nz Root CA"
            CADistinguishedNameSuffix = "DC=kewalaka,DC=nz"
            CRLPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n10:\n2:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10http://pki.kewalaka.nz/CertEnroll/%3%8%9.crl"
            CACertPublicationURLs = "1:C:\Windows\system32\CertSrv\CertEnroll\%1_%3%4.crt\n2:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n2:http://pki.kewalaka.nz/CertEnroll/%1_%3%4.crt"
            CRLPeriodUnits = 52
            CRLPeriod = 'Weeks'
            CRLOverlapUnits = 12
            CRLOverlapPeriod = 'Hours'
            ValidityPeriodUnits = 10
            ValidityPeriod = 'Years'
            AuditFilter = 127
            SubCAs = @('subca0')            
        }
    )
}


function New-AutomationModule
{
    param (
    [string]$moduleName,
    [string]$moduleURI,
    [string]$resourceGroupName,
    [string]$automationAccountName
)

    $modules = get-azurermautomationmodule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName

    if ($modules.Name -notcontains $modulename)
    {

        New-AzureRmAutomationModule -ContentLink $moduleURI `
                            -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $moduleName

    }

}

<#
# use this approach for organisational accounts
if ( $AzureCred -eq $null )
{
    $AzureCred = Get-Credential -Message "Please enter your Azure Credentials" -UserName "azure1@kewalaka.me.uk"
}

$azureAccount = Login-AzureRmAccount -Credential $AzureCred #-SubscriptionName 'Visual Studio Enterprise'
#>

# use this hack for live accounts
try {
    Get-AzureRmSubscription | Out-Null
    # Add-AzureRmAccount will pop up a window and ask you to authenticate. Save-AzureRmContext will write it out in json format
}
catch {
    Save-AzureRmContext -Profile (Add-AzureRmAccount) -Path $env:TEMP\creds.json -Force
    Import-AzureRmContext -Path $env:TEMP\creds.json   
}

New-AutomationModule -moduleName 'xAdcsDeployment' -moduleURI 'https://devopsgallerystorage.blob.core.windows.net/packages/xadcsdeployment.1.4.0.nupkg' `
                     -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName
New-AutomationModule -moduleName 'xPSDesiredStateConfiguration' -moduleURI 'https://devopsgallerystorage.blob.core.windows.net/packages/xpsdesiredstateconfiguration.8.0.0.nupkg' `
                     -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName

function New-AutomationCredentials
{
param (
    [string]$name,
    [string]$username
)

    if ((Get-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName `
                                         -AutomationAccountName $automationAccountName `
                                         -Name $name -ErrorAction SilentlyContinue) -eq $null)
    { 
        $password = read-host "Please enter password for $username" -AsSecureString
        $creds = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$password

        New-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName `
                                        -AutomationAccountName $automationAccountName `
                                        -Name $name -Value $creds
    }
    else
    {
        Write-Output "Credentials already exist for $name with username $username"
    }

}

New-AutomationCredentials -name "RootCAAdminCredential" -username "azureuser"

#if ((Get-AzureRmAutomationDscConfiguration -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name $DSCconfigurationName) -eq $null)
#{
    Import-AzureRmAutomationDscConfiguration -AutomationAccountName $automationAccountName -ResourceGroupName $resourceGroupName `
                                            -Published -SourcePath "$PSScriptRoot\$DSCconfigurationName.ps1" -Force
#}

Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName `
                                         -ConfigurationName $DSCconfigurationName -ConfigurationData $ConfigData `
                                         -Parameters $Params
#>
#Get-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -ConfigurationName $DSCconfigurationName
