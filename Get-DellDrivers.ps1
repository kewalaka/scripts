<#
    Messing around with http://en.community.dell.com/techcenter/enterprise-client/w/wiki/6683.driver-pack-catalog

    Not working yet.
#>

#region: Get the drive pack catalog from Dell's website
$source = 'http://downloads.dell.com/catalog/DriverPackCatalog.cab'

$destinationDir = "$env:TEMP"
$catalogCABFile = Join-Path $destinationDir 'DriverPackCatalog.cab'

if (-not (Test-Path $catalogCABFile))
{
    $wc = New-Object System.Net.WebClient

    $wc.DownloadFile($source, $catalogCABFile)

    $catalogXMLFile = $destinationDir + '\DriverPackCatalog.xml'
    EXPAND $catalogCABFile $catalogXMLFile
}
#endregion

#notepad $catalogXMLFile

#region: parse the catalog to find the correct drivers
[xml]$catalogXMLDoc = Get-Content $catalogXMLFile

$catalogXMLDoc.DriverPackManifest.DriverPackage | Select-Object `
    @{Expression={$_.SupportedSystems.Brand.key};Label='LOBKey';}, `
    @{Expression={$_.SupportedSystems.Brand.prefix};Label='LOBPrefix';}, `
    @{Expression={$_.SupportedSystems.Brand.Model.systemID};Label='SystemID';}, `
    @{Expression={$_.SupportedSystems.Brand.Model.name};Label='SystemName';} -Unique


$computerInfo = get-ciminstance win32_computersystem | select Manufacturer,Model,SystemFamily,SystemSKUNumber
$osInfo = get-ciminstance win32_operatingsystem -Property version

$cabSelected = $catalogXMLDoc.DriverPackManifest.DriverPackage| Where-Object {
    ($_.type -eq 'win') -and 
    ($_.SupportedOperatingSystems.OperatingSystem.majorVersion -eq '10' ) 
}

$cabDownloadLink = 'http://' + $catalogXMLDoc.DriverPackManifest.baseLocation + $cabSelected.path

$cabDownloadLink = 'http://' + $catalogXMLDoc.DriverPackManifest.baseLocation + '/' + $cabSelected.path

$Filename = [System.IO.Path]::GetFileName($cabDownloadLink)

$downloadDestination = JoinPath $destinationDir $Filename

$wc = New-Object System.Net.WebClient

$wc.DownloadFile($cabDownloadLink, $downloadDestination)

#endregion