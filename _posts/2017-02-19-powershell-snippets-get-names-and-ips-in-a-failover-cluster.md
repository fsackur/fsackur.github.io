---
layout: post
title: Powershell snippets - Get names and IPs in a failover cluster
date: 2017-02-19 00:04
author: freddiesackur
comments: true
tags: [Uncategorized]
---
If you administer a lot of Windows clusters, you frequently need to get hostnames, IPs and SQL instance names on a regular basis but! the FailoverClusters powershell module declines to give that to you without a fight.

Hopefully this saves you a bit of effort. Usage:
```powershell
Get-ClusterName
Get-ClusterIpAddress
Get-ClusterSqlInstanceName
```

```powershell
#Get all the DNS names used on a cluster
function Get-ClusterName {
    Get-ClusterNode | select @{Name = "ClusterResource"; Expression={"Cluster Node"}}, OwnerGroup, Name, DnsSuffix
    Get-Cluster | Get-ClusterResource | ?{$_.ResourceType -like "Network Name"} | %{
        $_ | select `
            @{Name = "ClusterResource"; Expression={$_.Name}},
            OwnerGroup,
            @{Name="Name"; Expression={$_ | Get-ClusterParameter -Name Name | select -ExpandProperty Value}},
            @{Name="DnsSuffix"; Expression={$_ | Get-ClusterParameter -Name DnsSuffix | select -ExpandProperty Value}}
    }
}
```

```powershell
#Get all the IP addresses used by a cluster
function Get-ClusterIpAddress {
    Get-Cluster | Get-ClusterResource | ?{$_.ResourceType -like "IP Address"} | %{
    $_ | select `
        @{Name = "ClusterResource"; Expression={$_.Name}},
        OwnerGroup,
        @{Name="Address"; Expression={$_ | Get-ClusterParameter -Name Address | select -ExpandProperty Value}},
        @{Name="SubnetMask"; Expression={$_ | Get-ClusterParameter -Name SubnetMask | select -ExpandProperty Value}}
    }
}
```

```powershell
#Get all SQL cluster instance names
function Get-ClusterSqlInstanceName {
    if (-not (Get-Command Get-ClusterName -ErrorAction SilentlyContinue)) {throw "Please also import the Get-ClusterName function from https://github.com/fsackur"}

    $ClusterNames = Get-ClusterName;
    $ClusterGroups = Get-ClusterGroup
    $Namespace = (Get-WmiObject -Namespace "ROOT\Microsoft\SqlServer" -Class "__Namespace" -Filter "Name LIKE 'ComputerManagement%'" | sort Name -Descending | select -First 1 @{Name="Namespace"; Expression={$_.__NAMESPACE + "\" + $_.Name}}).Namespace
    $SqlInstanceWmi = Get-WmiObject -Namespace $Namespace -Class "SqlService" -Filter "SqlServiceType = 1"

    $SqlInstanceWmi | ForEach-Object {

        $InstanceId = $_.ServiceName
        [bool]$DefaultInstance = $InstanceId -like "MSSQLSERVER"
        $Instance = $InstanceId -replace '^MSSQL\$'

        $ClusteredWmi = Get-WmiObject -Namespace $Namespace -Class "SqlServiceAdvancedProperty" -Filter "PropertyName = 'CLUSTERED' AND ServiceName = `'$InstanceId`'"
        [bool]$Clustered = $ClusteredWmi.PropertyNumValue -ne 0
        # Virtual Server object, for clusters
        $VsNameWmi = Get-WmiObject -Namespace $Namespace -Class "SqlServiceAdvancedProperty" -Filter "PropertyName = 'VSNAME' AND ServiceName = `'$InstanceId`'"
        $VsName = $VsNameWmi.PropertyStrValue

        if ($VsName) {$NetworkName = $VsName} else {$NetworkName = $env:COMPUTERNAME}
        if ($DefaultInstance) {$InstanceName = $NetworkName} else {$InstanceName = $NetworkName + "\" + $Instance}

        $ClusterName = $ClusterNames | ?{$_.Name -like $NetworkName}

        return New-Object psobject -Property @{
            InstanceName = $InstanceName;
            OwnerGroup = $ClusterName.OwnerGroup
        }
    }
}
```
Code is [here](https://gist.github.com/fsackur/3ee637d76448602da8fa865bd215c859)
