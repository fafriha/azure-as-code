Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

Import-Module $PSScriptRoot/DscOperations.psm1 -Force

function Update-PolicyParameter {
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $false)]
        [Hashtable[]] $Parameter
    )
    $updatedParameterInfo = @()

    foreach ($parmInfo in $Parameter) {
        $param = @{ }
        $param['Type'] = 'string'

        if ($parmInfo.Contains('Name')) {
            $param['ReferenceName'] = $parmInfo.Name
        }
        else {
            Throw "Policy parameter is missing a mandatory property 'Name'. Please make sure that parameter name is specified in Policy parameter."
        }

        if ($parmInfo.Contains('DisplayName')) {
            $param['DisplayName'] = $parmInfo.DisplayName
        }
        else {
            Throw "Policy parameter is missing a mandatory property 'DisplayName'. Please make sure that parameter display name is specified in Policy parameter."
        }
        
        if ($parmInfo.Contains('Description')) {
            $param['Description'] = $parmInfo.Description
        }

        if (-not $parmInfo.Contains('ResourceType')) {
            Throw "Policy parameter is missing a mandatory property 'ResourceType'. Please make sure that configuration resource type is specified in Policy parameter."
        }
        elseif (-not $parmInfo.Contains('ResourceId')) {
            Throw "Policy parameter is missing a mandatory property 'ResourceId'. Please make sure that configuration resource Id is specified in Policy parameter."
        }
        else {
            $param['MofResourceReference'] = "[$($parmInfo.ResourceType)]$($parmInfo.ResourceId)"
        }

        if ($parmInfo.Contains('ResourcePropertyName')) {
            $param['MofParameterName'] = $parmInfo.ResourcePropertyName
        }
        else {
            Throw "Policy parameter is missing a mandatory property 'ResourcePropertyName'. Please make sure that configuration resource property name is specified in Policy parameter."
        }
        
        if ($parmInfo.Contains('DefaultValue')) {
            $param['DefaultValue'] = $parmInfo.DefaultValue
        }

        if ($parmInfo.Contains('AllowedValues')) {
            $param['AllowedValues'] = $parmInfo.AllowedValues
        }

        $updatedParameterInfo += $param;
    }

    return $updatedParameterInfo
}

function Test-GuestConfigurationMofResourceDependencies {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )
    $resourcesInMofDocument = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($Path, 4)

    $externalResources = @()
    for ($i = 0; $i -lt $resourcesInMofDocument.Count; $i++) {
        if ($resourcesInMofDocument[$i].CimInstanceProperties.Name -contains 'ModuleName' -and $resourcesInMofDocument[$i].ModuleName -ne 'GuestConfiguration') {
            if ($resourcesInMofDocument[$i].ModuleName -ieq 'PsDesiredStateConfiguration') {
                Throw "'PsDesiredStateConfiguration' module is not supported by GuestConfiguration. Please use 'PSDscResources' module instead of 'PsDesiredStateConfiguration' module in DSC configuration."
            }

            $configurationName = $resourcesInMofDocument[$i].ConfigurationName
            Write-Warning -Message "The configuration '$configurationName' is using one or more resources outside of the GuestConfiguration module. Please make sure these resources work with PowerShell Core"
            break
        }
    }
}

function Copy-DscResources {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $MofDocumentPath,

        [Parameter(Mandatory = $true)]
        [String]
        $Destination
    )
    $resourcesInMofDocument = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($MofDocumentPath, 4)

    Write-Verbose "Copy DSC resources ..."
    $modulePath = New-Item -ItemType Directory -Force -Path (Join-Path $Destination 'Modules')
    $guestConfigModulePath = New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'GuestConfiguration')
    try {
        $latestModule = @()
        $latestModule += Get-Module GuestConfiguration
        $latestModule += Get-Module GuestConfiguration -ListAvailable
        $latestModule = ($latestModule | Sort-Object Version)[0]
    }
    catch {
        write-error 'unable to find the GuestConfiguration module either as an imported module or in $env:PSModulePath'
    }
    Copy-Item "$($latestModule.ModuleBase)/*" $guestConfigModulePath -Recurse -Force

    $modulesToCopy = @{ }
    $resourcesInMofDocument | ForEach-Object {
        # if resource is not a GuestConfiguration module resource.
        if ($_.CimInstanceProperties.Name -contains 'ModuleName' -and $_.CimInstanceProperties.Name -contains 'ModuleVersion') {
            $modulesToCopy[$_.CimClass.CimClassName] = @{ModuleName = $_.ModuleName; ModuleVersion = $_.ModuleVersion }
        }
    }
    $modulesToCopy.Values | ForEach-Object {
        $moduleToCopy = Get-Module -FullyQualifiedName @{ModuleName = $_.ModuleName; RequiredVersion = $_.ModuleVersion } -ListAvailable
        if ($null -ne $moduleToCopy) {
            $moduleToCopyPath = New-Item -ItemType Directory -Force -Path (Join-Path $modulePath $_.ModuleName)
            Copy-Item "$($moduleToCopy.ModuleBase)/*" $moduleToCopyPath -Recurse -Force
        }
        else {
            Write-Error "Module $($_.ModuleName) version $($_.ModuleVersion) could not be found in `$env:PSModulePath"
        }
    }

    # Copy binary resources.
    $nativeResourcePath = New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'DscNativeResources')
    $resources = Get-DscResource -Module GuestConfiguration
    $resources | ForEach-Object {
        if ($_.ImplementedAs -eq 'Binary') {
            $binaryResourcePath = Join-Path (Join-Path $latestModule.ModuleBase 'DscResources') $_.ResourceType
            Get-ChildItem $binaryResourcePath/* -Include *.sh | ForEach-Object { Convert-FileToUnixLineEndings -FilePath $_ }
            Copy-Item $binaryResourcePath $nativeResourcePath -Recurse -Force
        }
    }

    # Remove DSC binaries from package.
    $binaryPath = Join-Path $guestConfigModulePath 'bin'
    Remove-Item -Path $binaryPath -Force -Recurse -ErrorAction 'SilentlyContinue' | Out-Null
}

function Copy-ChefInspecDependencies {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $PackagePath,

        [Parameter(Mandatory = $true)]
        [String]
        $Configuration,

        [string]
        $ChefInspecProfilePath
    )

    # Copy Chef resource and profiles.
    $modulePath = Join-Path $PackagePath 'Modules'
    $nativeResourcePath = New-Item -ItemType Directory -Force -Path (Join-Path $modulePath 'DscNativeResources')
    $missingDependencies = @()
    $chefInspecProfiles = @()
    $resourcesInMofDocument = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($Configuration, 4)
    $usingChefResource = $false
    $resourcesInMofDocument | ForEach-Object {
        if ($_.CimClass.CimClassName -eq 'MSFT_ChefInSpecResource') {
            $usingChefResource = $true
            if ([string]::IsNullOrEmpty($ChefInspecProfilePath)) {
                Throw "Failed to find Chef Inspec profile(s) '$($_.CimInstanceProperties['Name'].Value)'. Please use ChefInspecProfilePath parameter to specify profile path."
            }

            $inspecProfilePath = Join-Path $ChefInspecProfilePath $_.CimInstanceProperties['Name'].Value
            if (-not (Test-Path $inspecProfilePath)) {
                $missingDependencies += $_.CimInstanceProperties['Name'].Value
            }
            else {
                $chefInspecProfiles += $inspecProfilePath
            }

            $chefResourcePath = Join-Path $nativeResourcePath 'MSFT_ChefInSpecResource'
            Copy-Item $chefResourcePath/install_inspec.sh  $modulePath -Force -ErrorAction SilentlyContinue
        }
    }
    if ($usingChefResource) {
        if ($missingDependencies.Length) {
            Throw "Failed to find Chef Inspec profile for '$($missingDependencies -join ',')'. Please make sure profile is present on $ChefInspecProfilePath path."
        }
        else {
            $chefInspecProfiles | ForEach-Object { Copy-Item $_ $modulePath -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
    else {
        if (-not [string]::IsNullOrEmpty($ChefInspecProfilePath)) {
            Throw "ChefInspecProfilePath parameter is supported only for Linux packages."
        }
    }
}

function Convert-FileToUnixLineEndings {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FilePath
    )

    $fileContent = Get-Content -Path $FilePath -Raw
    $fileContentWithLinuxLineEndings = $fileContent.Replace("`r`n", "`n")
    $null = Set-Content -Path $FilePath -Value $fileContentWithLinuxLineEndings -Force
    Write-Verbose -Message "Converted the file at the path '$FilePath' to Unix line endings."
}

function Update-MofDocumentParameters {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [parameter(Mandatory = $false)]
        [Hashtable[]] $Parameter
    )

    if ($Parameter.Count -eq 0) {
        return
    }

    $resourcesInMofDocument = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($Path, 4)

    foreach ($parmInfo in $Parameter) {
        if (-not $parmInfo.Contains('ResourceType')) {
            Throw "Policy parameter is missing a mandatory property 'ResourceType'. Please make sure that configuration resource type is specified in configuration parameter."
        }
        if (-not $parmInfo.Contains('ResourceId')) {
            Throw "Policy parameter is missing a mandatory property 'ResourceId'. Please make sure that configuration resource Id is specified in configuration parameter."
        }
        if (-not $parmInfo.Contains('ResourcePropertyName')) {
            Throw "Policy parameter is missing a mandatory property 'ResourcePropertyName'. Please make sure that configuration resource property name is specified in configuration parameter."
        }
        if (-not $parmInfo.Contains('ResourcePropertyValue')) {
            Throw "Policy parameter is missing a mandatory property 'ResourcePropertyValue'. Please make sure that configuration resource property value is specified in configuration parameter."
        }

        $resourceId = "[$($parmInfo.ResourceType)]$($parmInfo.ResourceId)"
        if (($resourcesInMofDocument | Where-Object { `
                    ($_.CimInstanceProperties.Name -contains 'ResourceID') `
                        -and ($_.CimInstanceProperties['ResourceID'].Value -eq $resourceId) `
                        -and ($_.CimInstanceProperties.Name -contains $parmInfo.ResourcePropertyName) `
                }) -eq $null) {

            Throw "Failed to find parameter reference in the configuration '$Path'. Please make sure parameter with ResourceType:'$($parmInfo.ResourceType)', ResourceId:'$($parmInfo.ResourceId)' and ResourcePropertyName:'$($parmInfo.ResourcePropertyName)' exist in the configuration."
        }

        Write-Verbose "Updating configuration parameter for $resourceId ..."
        $resourcesInMofDocument | ForEach-Object {
            if (($_.CimInstanceProperties.Name -contains 'ResourceID') -and ($_.CimInstanceProperties['ResourceID'].Value -eq $resourceId)) {
                $item = $_.CimInstanceProperties.Item($parmInfo.ResourcePropertyName)
                $item.Value = $parmInfo.ResourcePropertyValue
            }
        }
    }

    Write-Verbose "Saving configuration file '$Path' with updated parameters ..."
    $content = ""
    for ($i = 0; $i -lt $resourcesInMofDocument.Count; $i++) {
        $resourceClassName = $resourcesInMofDocument[$i].CimSystemProperties.ClassName
        $content += "instance of $resourceClassName"

        if ($resourceClassName -ne 'OMI_ConfigurationDocument') {
            $content += ' as $' + "$resourceClassName$i"
        }
        $content += "`n{`n"
        $resourcesInMofDocument[$i].CimInstanceProperties | ForEach-Object {
            $content += " $($_.Name)"
            if ($_.CimType -eq 'StringArray') {
                $content += " = {""$($_.Value -replace '[""\\]','\$&')""}; `n"
            }
            else {
                $content += " = ""$($_.Value -replace '[""\\]','\$&')""; `n"
            }
        }
        $content += "};`n" ;
    }

    $content | Out-File $Path
}

function Get-GuestConfigurationMofContent {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    Write-Verbose "Parsing Configuration document '$Path'"
    $resourcesInMofDocument = [Microsoft.PowerShell.DesiredStateConfiguration.Internal.DscClassCache]::ImportInstances($Path, 4)

    # Set the profile path for Chef resource
    $resourcesInMofDocument | ForEach-Object {
        if ($_.CimClass.CimClassName -eq 'MSFT_ChefInSpecResource') {
            $profilePath = "$Name/Modules/$($_.Name)"
            $item = $_.CimInstanceProperties.Item('GithubPath')
            if ($item -eq $null) {
                $item = [Microsoft.Management.Infrastructure.CimProperty]::Create('GithubPath', $profilePath, [Microsoft.Management.Infrastructure.CimFlags]::Property)                      
                $_.CimInstanceProperties.Add($item) 
            }
            else {
                $item.Value = $profilePath
            }
        }
    }

    return $resourcesInMofDocument
}

function Save-GuestConfigurationMofDocument {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [String]
        $SourcePath,

        [Parameter(Mandatory = $true)]
        [String]
        $DestinationPath
    )

    $resourcesInMofDocument = Get-GuestConfigurationMofContent -Name $Name -Path $SourcePath

    # if mof contains Chef resource
    if ($resourcesInMofDocument.CimSystemProperties.ClassName -contains 'MSFT_ChefInSpecResource') {
        Write-Verbose "Serialize DSC document to $DestinationPath path ..."
        $content = ""
        for ($i = 0; $i -lt $resourcesInMofDocument.Count; $i++) {
            $resourceClassName = $resourcesInMofDocument[$i].CimSystemProperties.ClassName
            $content += "instance of $resourceClassName"

            if ($resourceClassName -ne 'OMI_ConfigurationDocument') {
                $content += ' as $' + "$resourceClassName$i"
            }
            $content += "`n{`n"
            $resourcesInMofDocument[$i].CimInstanceProperties | ForEach-Object {
                $content += " $($_.Name)"
                if ($_.CimType -eq 'StringArray') {
                    $content += " = {""$($_.Value -replace '[""\\]','\$&')""}; `n"
                }
                else {
                    $content += " = ""$($_.Value -replace '[""\\]','\$&')""; `n"
                }
            }
            $content += "};`n" ;
        }

        $content | Out-File $DestinationPath
    }
    else {
        Write-Verbose "Copy DSC document to $DestinationPath path ..."
        Copy-Item $SourcePath $DestinationPath
    }
}

function Format-Json {
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $Json
    )

    $indent = 0
    $jsonLines = $Json -Split '\n'
    $formattedLines = @()
    $previousLine = ''

    foreach ($line in $jsonLines) {
        $skipAddingLine = $false
        if ($line -match '^\s*\}\s*' -or $line -match '^\s*\]\s*') {
            # This line contains  ] or }, decrement the indentation level
            $indent--
        }

        $formattedLine = (' ' * $indent * 4) + $line.TrimStart().Replace(':  ', ': ')

        if ($line -match '\s*".*"\s*:\s*\[' -or $line -match '\s*".*"\s*:\s*\{' -or $line -match '^\s*\{\s*' -or $line -match '^\s*\[\s*') {
            # This line contains [ or {, increment the indentation level
            $indent++
        }

        if ($previousLine.Trim().EndsWith("{")) {
            if ($formattedLine.Trim() -in @("}", "},")) {
                $newLine = "$($previousLine.TrimEnd())$($formattedLine.Trim())"
                #Write-Verbose -Message "FOUND SHORTENED LINE: $newLine"
                $formattedLines[($formattedLines.Count - 1)] = $newLine
                $previousLine = $newLine
                $skipAddingLine = $true
            }
        }

        if ($previousLine.Trim().EndsWith("[")) {
            if ($formattedLine.Trim() -in @("]", "],")) {
                $newLine = "$($previousLine.TrimEnd())$($formattedLine.Trim())"
                #Write-Verbose -Message "FOUND SHORTENED LINE: $newLine"
                $formattedLines[($formattedLines.Count - 1)] = $newLine
                $previousLine = $newLine
                $skipAddingLine = $true
            }
        }

        if (-not $skipAddingLine -and -not [String]::IsNullOrWhiteSpace($formattedLine)) {
            $previousLine = $formattedLine
            $formattedLines += $formattedLine
        }
    }

    $formattedJson = $formattedLines -join "`n"
    return $formattedJson
}

function New-GuestConfigurationDeployPolicyDefinition {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FileName,

        [Parameter(Mandatory = $true)]
        [String]
        $FolderPath,

        [Parameter(Mandatory = $true)]
        [String]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [String]
        $Description,

        [Parameter(Mandatory = $true)]
        [String]
        $ConfigurationName,

        [Parameter(Mandatory = $true)]
        [version]
        $ConfigurationVersion,

        [Parameter(Mandatory = $true)]
        [String]
        $ContentUri,

        [Parameter(Mandatory = $true)]
        [String]
        $ContentHash,

        [Parameter(Mandatory = $true)]
        [String]
        $ReferenceId,

        [Parameter()]
        [Hashtable[]]
        $ParameterInfo,

        [Parameter()]
        [String]
        $Guid,

        [Parameter()]
        [ValidateSet('Windows', 'Linux')]
        [String]
        $Platform = 'Windows',

        [Parameter()]
        [ValidateSet('Microsoft.Compute', 'Microsoft.HybridCompute')]
        [String]
        $RPName = 'Microsoft.Compute',

        [Parameter()]
        [ValidateSet('virtualMachines', 'machines')]
        [String]
        $ResourceName = 'virtualMachines',

        [Parameter()]
        [bool]
        $UseCertificateValidation = $false,

        [Parameter()]
        [String]
        $Category = 'Guest Configuration'
    )

    if (-not [String]::IsNullOrEmpty($Guid)) {
        $deployPolicyGuid = $Guid
    }
    else {
        $deployPolicyGuid = [Guid]::NewGuid()
    }

    $filePath = Join-Path -Path $FolderPath -ChildPath $FileName

    $deployPolicyContentHashtable = [Ordered]@{
        properties = [Ordered]@{
            displayName = $DisplayName
            policyType  = 'Custom'
            mode        = 'Indexed'
            description = $Description
            metadata    = [Ordered]@{
                category          = $Category
                requiredProviders = @(
                    'Microsoft.GuestConfiguration'
                )
            }
        }
    }

    $policyRuleHashtable = [Ordered]@{
        if   = [Ordered]@{
            allOf = @(
                [Ordered]@{
                    field  = 'type'
                    equals = $RPName + '/' + $ResourceName
                }
            )
        }
        then = [Ordered]@{
            effect  = 'deployIfNotExists'
            details = [Ordered]@{
                type              = 'Microsoft.GuestConfiguration/guestConfigurationAssignments'
                name              = $ConfigurationName
                roleDefinitionIds = @('/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c')
            }
        }
    }

    $deploymentHashtable = [Ordered]@{
        properties = [Ordered]@{
            mode       = 'incremental'
            parameters = [Ordered]@{
                vmName            = [Ordered]@{
                    value = "[field('name')]"
                }
                location          = [Ordered]@{
                    value = "[field('location')]"
                }
                configurationName = [Ordered]@{
                    value = $ConfigurationName
                }
                contentUri        = [Ordered]@{
                    value = $ContentUri
                }
                contentHash       = [Ordered]@{
                    value = $ContentHash
                }
            }
            template   = [Ordered]@{
                '$schema'      = 'https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#'
                contentVersion = '1.0.0.0'
                parameters     = [Ordered]@{
                    vmName            = [Ordered]@{
                        type = 'string'
                    }
                    location          = [Ordered]@{
                        type = 'string'
                    }
                    configurationName = [Ordered]@{
                        type = 'string'
                    }
                    contentUri        = [Ordered]@{
                        type = 'string'
                    }
                    contentHash       = [Ordered]@{
                        type = 'string'
                    }
                }
                resources      = @()
            }
        }
    }

    $guestConfigurationAssignmentHashtable = [Ordered]@{
        apiVersion = '2018-11-20'
        type       = $RPName + '/' + $ResourceName + '/providers/guestConfigurationAssignments'
        name       = "[concat(parameters('vmName'), '/Microsoft.GuestConfiguration/', parameters('configurationName'))]"
        location   = "[parameters('location')]"
        properties = [Ordered]@{
            guestConfiguration = [Ordered]@{
                name        = "[parameters('configurationName')]"
                contentUri  = "[parameters('contentUri')]"
                contentHash = "[parameters('contentHash')]"
                version     = $ConfigurationVersion.ToString()
            }
        }
    }

    if ($Platform -ieq 'Windows') {
        $policyRuleHashtable['if']['allOf'] += @(
            [Ordered]@{
                anyOf = @(
                    [Ordered]@{
                        field = $RPName + '/imagePublisher'
                        in    = @(
                            'esri',
                            'incredibuild',
                            'MicrosoftDynamicsAX',
                            'MicrosoftSharepoint',
                            'MicrosoftVisualStudio',
                            'MicrosoftWindowsDesktop',
                            'MicrosoftWindowsServerHPCPack'
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'MicrosoftWindowsServer'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '2008*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'MicrosoftSQLServer'
                            },
                            [Ordered]@{
                                field     = $RPName + '/imageSKU'
                                notEquals = 'SQL2008R2SP3-WS2008R2SP1'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-dsvm'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'dsvm-windows'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-ads'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                in    = @(
                                    'standard-data-science-vm',
                                    'windows-data-science-vm'
                                )
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'batch'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'rendering-windows2016'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'center-for-internet-security-inc'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'cis-windows-server-201*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'pivotal'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'bosh-windows-server*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloud-infrastructure-services'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'ad*'
                            }
                        )
                    }
                )
            }
        )
        $guestConfigurationExtensionHashtable = [Ordered]@{
            apiVersion = '2015-05-01-preview'
            name       = "[concat(parameters('vmName'), '/AzurePolicyforWindows')]"
            type       = 'Microsoft.Compute/virtualMachines/extensions'
            location   = "[parameters('location')]"
            properties = [Ordered]@{
                publisher               = 'Microsoft.GuestConfiguration'
                type                    = 'ConfigurationforWindows'
                typeHandlerVersion      = '1.1'
                autoUpgradeMinorVersion = $true
                settings                = @{ }
                protectedSettings       = @{ }
            }
            dependsOn  = @(
                "[concat('Microsoft.Compute/virtualMachines/',parameters('vmName'),'/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/',parameters('configurationName'))]"
            )
        }
    }
    elseif ($Platform -ieq 'Linux') {
        $policyRuleHashtable['if']['allOf'] += @(
            [Ordered]@{
                anyOf = @(
                    [Ordered]@{
                        field = $RPName + '/imagePublisher'
                        in    = @(
                            'microsoft-aks',
                            'AzureDatabricks',
                            'qubole-inc',
                            'datastax',
                            'couchbase',
                            'scalegrid',
                            'checkpoint',
                            'paloaltonetworks'
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'OpenLogic'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'CentOS*'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'RedHat'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'RHEL'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'RedHat'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'osa'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'credativ'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'Debian'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '7*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'Suse'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'SLES*'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '11*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'Canonical'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'UbuntuServer'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '12*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-dsvm'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                in    = @(
                                    'linux-data-science-vm-ubuntu',
                                    'azureml'
                                )
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloudera'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'cloudera-centos-os'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloudera'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'cloudera-altus-centos-os'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-ads'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'linux*'
                            }
                        )
                    }
                )
            }
        )

        $guestConfigurationExtensionHashtable = [Ordered]@{
            apiVersion = '2015-05-01-preview'
            name       = "[concat(parameters('vmName'), '/AzurePolicyforLinux')]"
            type       = 'Microsoft.Compute/virtualMachines/extensions'
            location   = "[parameters('location')]"
            properties = [Ordered]@{
                publisher               = 'Microsoft.GuestConfiguration'
                type                    = 'ConfigurationforLinux'
                typeHandlerVersion      = '1.0'
                autoUpgradeMinorVersion = $true
            }
            dependsOn  = @(
                "[concat('Microsoft.Compute/virtualMachines/',parameters('vmName'),'/providers/Microsoft.GuestConfiguration/guestConfigurationAssignments/',parameters('configurationName'))]"
            )
        }
    }
    else {
        throw "The specified platform '$Platform' is not currently supported by this script."
    }

    $existenceConditionList = @()
    # Handle adding parameters if needed
    if ($null -ne $ParameterInfo -and $ParameterInfo.Count -gt 0) {
        $parameterValueConceatenatedStringList = @()

        if (-not $deployPolicyContentHashtable['properties'].Contains('parameters')) {
            $deployPolicyContentHashtable['properties']['parameters'] = [Ordered]@{ }
        }

        if (-not $guestConfigurationAssignmentHashtable['properties']['guestConfiguration'].Contains('configurationParameter')) {
            $guestConfigurationAssignmentHashtable['properties']['guestConfiguration']['configurationParameter'] = @()
        }

        foreach ($currentParameterInfo in $ParameterInfo) {
            $deployPolicyContentHashtable['properties']['parameters'] += [Ordered]@{
                $currentParameterInfo.ReferenceName = [Ordered]@{
                    type     = $currentParameterInfo.Type
                    metadata = [Ordered]@{
                        displayName = $currentParameterInfo.DisplayName
                    }
                }
            }

            if ($currentParameterInfo.ContainsKey('Description')) {
                $deployPolicyContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName]['metadata']['description'] = $currentParameterInfo['Description']
            }

            if ($currentParameterInfo.ContainsKey('DefaultValue')) {
                $deployPolicyContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName] += [Ordered]@{
                    defaultValue = $currentParameterInfo.DefaultValue
                }
            }

            if ($currentParameterInfo.ContainsKey('AllowedValues')) {
                $deployPolicyContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName] += [Ordered]@{
                    allowedValues = $currentParameterInfo.AllowedValues
                }
            }

            if ($currentParameterInfo.ContainsKey('DeploymentValue')) {
                $deploymentHashtable['properties']['parameters'] += [Ordered]@{
                    $currentParameterInfo.ReferenceName = [Ordered]@{
                        value = $currentParameterInfo.DeploymentValue
                    }
                }
            }
            else {
                $deploymentHashtable['properties']['parameters'] += [Ordered]@{
                    $currentParameterInfo.ReferenceName = [Ordered]@{
                        value = "[parameters('$($currentParameterInfo.ReferenceName)')]"
                    }
                }
            }

            $deploymentHashtable['properties']['template']['parameters'] += [Ordered]@{
                $currentParameterInfo.ReferenceName = [Ordered]@{
                    type = $currentParameterInfo.Type
                }
            }

            $configurationParameterName = "$($currentParameterInfo.MofResourceReference);$($currentParameterInfo.MofParameterName)"

            if ($currentParameterInfo.ContainsKey('ConfigurationValue')) {
                $configurationParameterValue = $currentParameterInfo.ConfigurationValue

                if ($currentParameterInfo.ConfigurationValue.StartsWith('[') -and $currentParameterInfo.ConfigurationValue.EndsWith(']')) {
                    $configurationParameterStringValue = $currentParameterInfo.ConfigurationValue.Substring(1, $currentParameterInfo.ConfigurationValue.Length - 2)
                }
                else {
                    $configurationParameterStringValue = "'$($currentParameterInfo.ConfigurationValue)'"
                }
            }
            else {
                $configurationParameterValue = "[parameters('$($currentParameterInfo.ReferenceName)')]"
                $configurationParameterStringValue = "parameters('$($currentParameterInfo.ReferenceName)')"
            }

            $guestConfigurationAssignmentHashtable['properties']['guestConfiguration']['configurationParameter'] += [Ordered]@{
                name  = $configurationParameterName
                value = $configurationParameterValue
            }

            $currentParameterValueConcatenatedString = "'$configurationParameterName', '=', $configurationParameterStringValue"
            $parameterValueConceatenatedStringList += $currentParameterValueConcatenatedString
        }

        $allParameterValueConcantenatedString = $parameterValueConceatenatedStringList -join ", ',', "
        $parameterExistenceConditionEqualsValue = "[base64(concat($allParameterValueConcantenatedString))]"

        $existenceConditionList += [Ordered]@{
            field  = 'Microsoft.GuestConfiguration/guestConfigurationAssignments/parameterHash'
            equals = $parameterExistenceConditionEqualsValue
        }
    }

    $existenceConditionList += [Ordered]@{
        field  = 'Microsoft.GuestConfiguration/guestConfigurationAssignments/contentHash'
        equals = "$ContentHash"
    }

    $policyRuleHashtable['then']['details']['existenceCondition'] = [Ordered]@{
        allOf = $existenceConditionList
    }
    $policyRuleHashtable['then']['details']['deployment'] = $deploymentHashtable

    $policyRuleHashtable['then']['details']['deployment']['properties']['template']['resources'] += $guestConfigurationAssignmentHashtable
    if ($RPName -eq 'Microsoft.Compute') {
        $systemAssignedHashtable = [Ordered]@{
            apiVersion = '2019-07-01'
            type       = 'Microsoft.Compute/virtualMachines'
            identity   = [Ordered]@{
                type = 'SystemAssigned'
            }
            name       = "[parameters('vmName')]"
            location   = "[parameters('location')]"
        }    
        $policyRuleHashtable['then']['details']['deployment']['properties']['template']['resources'] += $systemAssignedHashtable
        $policyRuleHashtable['then']['details']['deployment']['properties']['template']['resources'] += $guestConfigurationExtensionHashtable
    }

    $deployPolicyContentHashtable['properties']['policyRule'] = $policyRuleHashtable

    $deployPolicyContentHashtable += [Ordered]@{
        id   = "/providers/Microsoft.Authorization/policyDefinitions/$deployPolicyGuid"
        name = $deployPolicyGuid
    }

    $deployPolicyContent = ConvertTo-Json -InputObject $deployPolicyContentHashtable -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $formattedDeployPolicyContent = Format-Json -Json $deployPolicyContent

    if (Test-Path -Path $filePath) {
        Write-Error -Message "A file at the policy destination path '$filePath' already exists. Please remove this file or specify a different destination path."
    }
    else {
        $null = New-Item -Path $filePath -ItemType 'File' -Value $formattedDeployPolicyContent
    }

    return $deployPolicyGuid
}

<#
    .SYNOPSIS
        Creates a new audit policy definition for a guest configuration policy definition set.
#>
function New-GuestConfigurationAuditPolicyDefinition {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FileName,

        [Parameter(Mandatory = $true)]
        [String]
        $FolderPath,

        [Parameter(Mandatory = $true)]
        [String]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [String]
        $Description,

        [Parameter(Mandatory = $true)]
        [String]
        $ConfigurationName,

        [Parameter(Mandatory = $true)]
        [String]
        $ReferenceId,

        [Parameter()]
        [String]
        $Guid,

        [Parameter()]
        [ValidateSet('Windows', 'Linux')]
        [String]
        $Platform = 'Windows',

        [Parameter()]
        [ValidateSet('Microsoft.Compute', 'Microsoft.HybridCompute')]
        [String]
        $RPName = 'Microsoft.Compute',

        [Parameter()]
        [ValidateSet('virtualMachines', 'machines')]
        [String]
        $ResourceName = 'virtualMachines',

        [Parameter()]
        [String]
        $Category = 'Guest Configuration'
    )

    if (-not [String]::IsNullOrEmpty($Guid)) {
        $auditPolicyGuid = $Guid
    }
    else {
        $auditPolicyGuid = [Guid]::NewGuid()
    }

    $filePath = Join-Path -Path $FolderPath -ChildPath $FileName

    $auditPolicyContentHashtable = [Ordered]@{
        properties = [Ordered]@{
            displayName = $DisplayName
            policyType  = 'Custom'
            mode        = 'All'
            description = $Description
            metadata    = [Ordered]@{
                category = $Category
            }
            
        }
        id         = "/providers/Microsoft.Authorization/policyDefinitions/$auditPolicyGuid"
        name       = $auditPolicyGuid
    }

    $policyRuleHashtable = [Ordered]@{
        if   = [Ordered]@{
            allOf = @(
                [Ordered]@{
                    field  = 'type'
                    equals = $RPName + '/' + $ResourceName
                }
            )
        }
        then = [Ordered]@{
            effect  = 'auditIfNotExists'
            details = [Ordered]@{
                type = 'Microsoft.GuestConfiguration/guestConfigurationAssignments'
                name = $ConfigurationName
            }
        }

    }

    if ($Platform -ieq 'Windows') {
        $policyRuleHashtable['if']['allOf'] += @(
            [Ordered]@{
                anyOf = @(
                    [Ordered]@{
                        field = $RPName + '/imagePublisher'
                        in    = @(
                            'esri',
                            'incredibuild',
                            'MicrosoftDynamicsAX',
                            'MicrosoftSharepoint',
                            'MicrosoftVisualStudio',
                            'MicrosoftWindowsDesktop',
                            'MicrosoftWindowsServerHPCPack'
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'MicrosoftWindowsServer'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '2008*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'MicrosoftSQLServer'
                            },
                            [Ordered]@{
                                field     = $RPName + '/imageSKU'
                                notEquals = 'SQL2008R2SP3-WS2008R2SP1'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-dsvm'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'dsvm-windows'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-ads'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                in    = @(
                                    'standard-data-science-vm',
                                    'windows-data-science-vm'
                                )
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'batch'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'rendering-windows2016'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'center-for-internet-security-inc'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'cis-windows-server-201*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'pivotal'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'bosh-windows-server*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloud-infrastructure-services'
                            },
                            [Ordered]@{
                                field = $RPName + '/imageOffer'
                                like  = 'ad*'
                            }
                        )
                    }
                )
            }
        )
    }
    elseif ($Platform -ieq 'Linux') {
        $policyRuleHashtable['if']['allOf'] += @(
            [Ordered]@{
                anyOf = @(
                    [Ordered]@{
                        field = $RPName + '/imagePublisher'
                        in    = @(
                            'microsoft-aks',
                            'AzureDatabricks',
                            'qubole-inc',
                            'datastax',
                            'couchbase',
                            'scalegrid',
                            'checkpoint',
                            'paloaltonetworks'
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'OpenLogic'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'CentOS*'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'RedHat'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'RHEL'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'RedHat'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'osa'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'credativ'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'Debian'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '7*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'Suse'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'SLES*'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '11*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'Canonical'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'UbuntuServer'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '12*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-dsvm'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                in    = @(
                                    'linux-data-science-vm-ubuntu',
                                    'azureml'
                                )
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloudera'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'cloudera-centos-os'
                            },
                            [Ordered]@{
                                field   = $RPName + '/imageSKU'
                                notLike = '6*'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'cloudera'
                            },
                            [Ordered]@{ 
                                field  = $RPName + '/imageOffer'
                                equals = 'cloudera-altus-centos-os'
                            }
                        )
                    },
                    [Ordered]@{
                        allOf = @(
                            [Ordered]@{ 
                                field  = $RPName + '/imagePublisher'
                                equals = 'microsoft-ads'
                            },
                            [Ordered]@{ 
                                field = $RPName + '/imageOffer'
                                like  = 'linux*'
                            }
                        )
                    }
                )
            }
        )
    }
    else {
        throw "The specified platform '$Platform' is not currently supported by this script."
    }

    $existenceConditionList = [Ordered]@{
        field  = 'Microsoft.GuestConfiguration/guestConfigurationAssignments/complianceStatus'
        equals = 'Compliant'
    }

    $policyRuleHashtable['then']['details']['existenceCondition'] = $existenceConditionList

    $auditPolicyContentHashtable['properties']['policyRule'] = $policyRuleHashtable

    $auditPolicyContent = ConvertTo-Json -InputObject $auditPolicyContentHashtable -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $formattedAuditPolicyContent = Format-Json -Json $auditPolicyContent

    if (Test-Path -Path $filePath) {
        Write-Error -Message "A file at the policy destination path '$filePath' already exists. Please remove this file or specify a different destination path."
    }
    else {
        $null = New-Item -Path $filePath -ItemType 'File' -Value $formattedAuditPolicyContent
    }

    return $auditPolicyGuid
}

<#
    .SYNOPSIS
        Creates a new policy initiative definition for a guest configuration policy definition set.
#>
function New-GuestConfigurationPolicyInitiativeDefinition {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $FileName,

        [Parameter(Mandatory = $true)]
        [String]
        $FolderPath,

        [Parameter(Mandatory = $true)]
        [Hashtable[]]
        $DeployPolicyInfo,

        [Parameter(Mandatory = $true)]
        [Hashtable[]]
        $AuditPolicyInfo,

        [Parameter(Mandatory = $true)]
        [String]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [String]
        $Description,

        [Parameter()]
        [String]
        $Guid
    )

    if (-not [String]::IsNullOrEmpty($Guid)) {
        $initiativeGuid = $Guid
    }
    else {
        $initiativeGuid = [Guid]::NewGuid()
    }

    $filePath = Join-Path -Path $FolderPath -ChildPath $FileName
    $policyDefinitions = @()

    $initiativeContentHashtable = [Ordered]@{
        properties = [Ordered]@{
            displayName = $DisplayName
            policyType  = 'Custom'
            description = $Description
            metadata    = [Ordered]@{
                category = 'Guest Configuration'
            }
        }
    }

    foreach ($currentDeployPolicyInfo in $DeployPolicyInfo) {
        $deployPolicyContentHash = [Ordered]@{
            policyDefinitionId          = "/providers/Microsoft.Authorization/policyDefinitions/$($currentDeployPolicyInfo.Guid)"
            policyDefinitionReferenceId = $currentDeployPolicyInfo.ReferenceId
        }

        if ($currentDeployPolicyInfo.ContainsKey('ParameterInfo')) {
            if (-not $initiativeContentHashtable['properties'].Contains('parameters')) {
                $initiativeContentHashtable['properties']['parameters'] = [Ordered]@{ }
            }

            if (-not $deployPolicyContentHash.Contains('parameters')) {
                $deployPolicyContentHash['parameters'] = [Ordered]@{ }
            }

            foreach ($currentParameterInfo in $currentDeployPolicyInfo.ParameterInfo) {
                $initiativeContentHashtable['properties']['parameters'] += [Ordered]@{
                    $currentParameterInfo.ReferenceName = [Ordered]@{
                        type     = $currentParameterInfo.Type
                        metadata = [Ordered]@{
                            displayName = $currentParameterInfo.DisplayName
                        }
                    }
                }

                if ($currentParameterInfo.ContainsKey('Description')) {
                    $initiativeContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName]['metadata']['description'] = $currentParameterInfo['Description']
                }

                if ($currentParameterInfo.ContainsKey('DefaultValue')) {
                    $initiativeContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName] += [Ordered]@{
                        defaultValue = $currentParameterInfo.DefaultValue
                    }
                }

                if ($currentParameterInfo.ContainsKey('AllowedValues')) {
                    $initiativeContentHashtable['properties']['parameters'][$currentParameterInfo.ReferenceName] += [Ordered]@{
                        allowedValues = $currentParameterInfo.AllowedValues
                    }
                }

                $deployPolicyContentHash['parameters'] += [Ordered]@{
                    $currentParameterInfo.ReferenceName = [Ordered]@{
                        value = "[parameters('$($currentParameterInfo.ReferenceName)')]"
                    }
                }
            }
        }

        $policyDefinitions += $deployPolicyContentHash
    }

    foreach ($currentAuditPolicyInfo in $AuditPolicyInfo) {
        $auditPolicyContentHash = [Ordered]@{
            policyDefinitionId          = "/providers/Microsoft.Authorization/policyDefinitions/$($currentAuditPolicyInfo.Guid)"
            policyDefinitionReferenceId = $currentAuditPolicyInfo.ReferenceId
        }

        $policyDefinitions += $auditPolicyContentHash
    }

    $initiativeContentHashtable['properties']['policyDefinitions'] = $policyDefinitions
    $initiativeContentHashtable += [Ordered]@{
        id   = "/providers/Microsoft.Authorization/policySetDefinitions/$initiativeGuid"
        name = $initiativeGuid
    }

    $initiativeContent = ConvertTo-Json -InputObject $initiativeContentHashtable -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
    $formattedInitiativeContent = Format-Json -Json $initiativeContent

    if (Test-Path -Path $filePath) {
        Write-Error -Message "A file at the initiative destination path '$filePath' already exists. Please remove this file or specify a different destination path."
    }
    else {
        $null = New-Item -Path $filePath -ItemType 'File' -Value $formattedInitiativeContent
    }

    return $initiativeGuid
}

<#
    .SYNOPSIS
        Creates a new policy set for guest configuration. This set should include at least one
        audit policy definition, at least one deploy policy definition, and only one policy
        initiative definition.
#>
function New-GuestConfigurationPolicyDefinitionSet {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $PolicyFolderPath,

        [Parameter(Mandatory = $true)]
        [Hashtable[]]
        $DeployPolicyInfo,

        [Parameter(Mandatory = $true)]
        [Hashtable[]]
        $AuditPolicyInfo,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $InitiativeInfo,

        [Parameter()]
        [ValidateSet('Windows', 'Linux')]
        [String]
        $Platform = 'Windows'
    )

    if (Test-Path -Path $PolicyFolderPath) {
        $null = Remove-Item -Path $PolicyFolderPath -Force -Recurse -ErrorAction 'SilentlyContinue'
    }

    $null = New-Item -Path $PolicyFolderPath -ItemType 'Directory'

    foreach ($currentDeployPolicyInfo in $DeployPolicyInfo) {
        $currentDeployPolicyInfo['FolderPath'] = $PolicyFolderPath
        $deployPolicyGuid = New-GuestConfigurationDeployPolicyDefinition @currentDeployPolicyInfo -Platform $Platform
        $currentDeployPolicyInfo['Guid'] = $deployPolicyGuid
    }

    foreach ($currentAuditPolicyInfo in $AuditPolicyInfo) {
        $currentAuditPolicyInfo['FolderPath'] = $PolicyFolderPath
        $auditPolicyGuid = New-GuestConfigurationAuditPolicyDefinition @currentAuditPolicyInfo -Platform $Platform
        $currentAuditPolicyInfo['Guid'] = $auditPolicyGuid
    }

    $InitiativeInfo['FolderPath'] = $PolicyFolderPath
    $InitiativeInfo['DeployPolicyInfo'] = $DeployPolicyInfo
    $InitiativeInfo['AuditPolicyInfo'] = $AuditPolicyInfo

    $initiativeGuid = New-GuestConfigurationPolicyInitiativeDefinition @InitiativeInfo
    return $initiativeGuid
}

function New-CustomGuestConfigPolicy {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [String]
        $PolicyFolderPath,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $DeployPolicyInfo,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $AuditPolicyInfo,

        [Parameter(Mandatory = $true)]
        [Hashtable]
        $InitiativeInfo,

        [Parameter()]
        [ValidateSet('Windows', 'Linux')]
        [String]
        $Platform = 'Windows',

        [Parameter(Mandatory = $false)]
        [string]
        $Category = 'Guest Configuration'
    )

    $existingPolicies = Get-AzPolicyDefinition
    $existingDeployPolicy = $existingPolicies | Where-Object { ($_.Properties.PSObject.Properties.Name -contains 'displayName') -and ($_.Properties.displayName -eq $DeployPolicyInfo.DisplayName) }
    if ($null -ne $existingDeployPolicy) {
        Write-Verbose -Message "Found policy with name '$($existingDeployPolicy.Properties.displayName)' and guid '$($existingDeployPolicy.Name)'..."
        $DeployPolicyInfo['Guid'] = $existingDeployPolicy.Name.ToString()
    }

    $existingAuditPolicy = $existingPolicies | Where-Object { ($_.Properties.PSObject.Properties.Name -contains 'displayName') -and ($_.Properties.displayName -eq $AuditPolicyInfo.DisplayName) }
    if ($null -ne $existingAuditPolicy) {
        Write-Verbose -Message "Found policy with name '$($existingAuditPolicy.Properties.displayName)' and guid '$($existingAuditPolicy.Name)'..."
        $AuditPolicyInfo['Guid'] = $existingAuditPolicy.Name.ToString()
    }

    $existingInitiative = Get-AzPolicySetDefinition | Where-Object { ($_.Properties.PSObject.Properties.Name -contains 'displayName') -and ($_.Properties.displayName -eq $InitiativeInfo.DisplayName) }
    if ($null -ne $existingInitiative) {
        Write-Verbose -Message "Found initiative with name '$($existingInitiative.Properties.displayName)' and guid '$($existingInitiative.Name)'..."
        $InitiativeInfo['Guid'] = $existingInitiative.Name.ToString()
    }

    New-GuestConfigurationPolicyDefinitionSet @PSBoundParameters
}
# SIG # Begin signature block
# MIIjlgYJKoZIhvcNAQcCoIIjhzCCI4MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB1CD5GsCkZJ+xY
# mcWG+qo33E+VuoC3s2tYGahfXRR3s6CCDYUwggYDMIID66ADAgECAhMzAAABUptA
# n1BWmXWIAAAAAAFSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTkwNTAyMjEzNzQ2WhcNMjAwNTAyMjEzNzQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCxp4nT9qfu9O10iJyewYXHlN+WEh79Noor9nhM6enUNbCbhX9vS+8c/3eIVazS
# YnVBTqLzW7xWN1bCcItDbsEzKEE2BswSun7J9xCaLwcGHKFr+qWUlz7hh9RcmjYS
# kOGNybOfrgj3sm0DStoK8ljwEyUVeRfMHx9E/7Ca/OEq2cXBT3L0fVnlEkfal310
# EFCLDo2BrE35NGRjG+/nnZiqKqEh5lWNk33JV8/I0fIcUKrLEmUGrv0CgC7w2cjm
# bBhBIJ+0KzSnSWingXol/3iUdBBy4QQNH767kYGunJeY08RjHMIgjJCdAoEM+2mX
# v1phaV7j+M3dNzZ/cdsz3oDfAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQU3f8Aw1sW72WcJ2bo/QSYGzVrRYcw
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzQ1NDEzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AJTwROaHvogXgixWjyjvLfiRgqI2QK8GoG23eqAgNjX7V/WdUWBbs0aIC3k49cd0
# zdq+JJImixcX6UOTpz2LZPFSh23l0/Mo35wG7JXUxgO0U+5drbQht5xoMl1n7/TQ
# 4iKcmAYSAPxTq5lFnoV2+fAeljVA7O43szjs7LR09D0wFHwzZco/iE8Hlakl23ZT
# 7FnB5AfU2hwfv87y3q3a5qFiugSykILpK0/vqnlEVB0KAdQVzYULQ/U4eFEjnis3
# Js9UrAvtIhIs26445Rj3UP6U4GgOjgQonlRA+mDlsh78wFSGbASIvK+fkONUhvj8
# B8ZHNn4TFfnct+a0ZueY4f6aRPxr8beNSUKn7QW/FQmn422bE7KfnqWncsH7vbNh
# G929prVHPsaa7J22i9wyHj7m0oATXJ+YjfyoEAtd5/NyIYaE4Uu0j1EhuYUo5VaJ
# JnMaTER0qX8+/YZRWrFN/heps41XNVjiAawpbAa0fUa3R9RNBjPiBnM0gvNPorM4
# dsV2VJ8GluIQOrJlOvuCrOYDGirGnadOmQ21wPBoGFCWpK56PxzliKsy5NNmAXcE
# x7Qb9vUjY1WlYtrdwOXTpxN4slzIht69BaZlLIjLVWwqIfuNrhHKNDM9K+v7vgrI
# bf7l5/665g0gjQCDCN6Q5sxuttTAEKtJeS/pkpI+DbZ/MIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCFWcwghVjAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAFSm0CfUFaZdYgAAAAA
# AVIwDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIG7F
# 4JsZJA9Ix4UyKh9+LGbkMkiSutdv3i1KEDaB9nsfMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAUqhBwz2syu85JE03yMrTKDDw2ezhDRkURo+i
# cjM9DUGEsfnWKTxHfXYbUYSmO5T82nnTdlKsUycAr8gSy7rTK8IH4WAy3ajUROUH
# AuNECPJsp3P8U3fXSx8sEGJSqI9kSKDq1C/Z9ckrNkv5tV/IisxhWwtcYU5Lj1u4
# IQ5N4QhuacKGiqcRTnq6F3IXR37Z7BNOFpWZBbGB0F9rAx0Rcef98SGrwReAqaij
# qfO54xre0VJC22qinA+EjwKlO6KUJ4G48PhvnP0rlKflt0mqcjV/xuSRxywUc21u
# irpd/q2SuKSk6LWhQj1FcKPBO7gpOttT/gcPBeaVPAqWki2xpqGCEvEwghLtBgor
# BgEEAYI3AwMBMYIS3TCCEtkGCSqGSIb3DQEHAqCCEsowghLGAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFVBgsqhkiG9w0BCRABBKCCAUQEggFAMIIBPAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCBICTvfRhJYObOOne2R9R0XQTWk47h88aOI
# 5bdTIcU6NQIGXpgI9IqVGBMyMDIwMDQyMjIyNDE1MS43MDdaMASAAgH0oIHUpIHR
# MIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQL
# EyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046Nzg4MC1FMzkwLTgwMTQxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg5EMIIE9TCCA92gAwIBAgITMwAAASigDoHhNtVP
# wgAAAAABKDANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0xOTEyMTkwMTE1MDBaFw0yMTAzMTcwMTE1MDBaMIHOMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQg
# T3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046
# Nzg4MC1FMzkwLTgwMTQxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNl
# cnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCdkbHW91Tbhj7N
# vw4KXPYLe+yxtCT5A+FVk5RCS5Ks50yZfkaGX4jsDeolnz7uJP5I/J8GO6by7NTr
# AcuPeMrrIOKxy8BzVCT7cNU3OeDDi4HXKLAODcZIu93w8qlsA7YznZOh+5DXMwT6
# gAw+gffKLe+/8EgAgSSMZvagFLnarkuX3MwhdPvmllGrw7uOlN3L+hxIyHVdmXSU
# 1CoOFlCHU2DEFyNPNvqkrOOVgWY3CvfP7SH8fLqvKvJLFhffs1IxkxYjGih4Z+3E
# gqBI+xNbVZltPCEqUuu/FhT9vgNDkMGlnCSjQAivifi2uy89mxrqQonThs+Vw3sH
# NZQ/Zyz3AgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUhOLyg/F+tTeb1AHDTnR/UATL
# pvIwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
# BggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAi19mRxiFC4A5P4nHB1lMsIw8
# gLAR5YZJrZgaeJZXcC93TaNG12WR4kmQfnNis7z6mOuAZRAo0vz6rq9pvVGk9TdA
# XlKMER0E/PMHc3feIGKil5iw21UfMnlYAZHD/yYlVm13UM3M9REx4Fq4frswPAcF
# IAGhycPp12HHCLg4DyTNVE3jZfUeTr3/us0dhOWSOA6yKr0uIx+ELKDD059uwIze
# 1WbeGpqEcTCxHEAEu7z09SVFGkRaRR5pFGFZZ9WDLMP//+vevGkb8t3JgpUuOLsZ
# JGiC24YdYdPXo2Yx4axJ/pPTHFZFormO9uIyf+e7cpTOwP48yFjY9RfFZYZMsjCC
# BnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29m
# dCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1
# NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/
# aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxh
# MFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhH
# hjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tk
# iVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox
# 8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJN
# AgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIox
# kPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0P
# BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9
# lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQu
# Y29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3Js
# MFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAG
# A1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAG
# CCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEA
# dABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXED
# PZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgr
# UYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c
# 8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFw
# nzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFt
# w5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk
# 7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9d
# dJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zG
# y9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3
# yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7c
# RDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wkn
# HNWzfjUeCLraNtvTX4/edIhJEqGCAtIwggI7AgEBMIH8oYHUpIHRMIHOMQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3Nv
# ZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046Nzg4MC1FMzkwLTgwMTQxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVADE9SxvygBI9F7Ii/Z+5sZl9Wn2boIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEF
# BQACBQDiSxknMCIYDzIwMjAwNDIyMjMyNzM1WhgPMjAyMDA0MjMyMzI3MzVaMHcw
# PQYKKwYBBAGEWQoEATEvMC0wCgIFAOJLGScCAQAwCgIBAAICH6QCAf8wBwIBAAIC
# Ek0wCgIFAOJMaqcCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQDQGqSfoZAX
# M5wMPRrEE82HnnboLrFRGuL6IwrTDHZie37nmpqtT/+TJEJJSyQuvIm3b9BfBMkx
# FmMvGo3gkwOpbVouRffPLTHxREEluFG70cZ2O05/eddkgEof+XT7EsayCAmLRxeJ
# jGa+m9gKn88K4tpZYEmSoetCn2x3UMJG8jGCAw0wggMJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABKKAOgeE21U/CAAAAAAEoMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIJQc9prShI8bUa/GdloMvjd6WBBZ1q4BeEvwEWI7xleAMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgvEVqi68FUnfv3BsQ3wakuG9bT14aDxaw
# uteb1dboFNowgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAASigDoHhNtVPwgAAAAABKDAiBCAKH8L6Lj+tkhab0yCK3FbbJ5RX6Dd0ilyg
# yPsopKvlBzANBgkqhkiG9w0BAQsFAASCAQAtSChlLSAPMDzSB1/hbsa2J0R0nGJo
# d66GPQYAOSIakinLPbuJy7jDUhhqamDsjdxiN+tr4+IFs7xLLtJbsPF5qq6L08eJ
# g57+RWzOk0eq+ERAOvOK9Nk0vnR/PXf8S1dYcnueUgPjJBrMHA0Tc0roROV+0xtv
# ufs4WMD7ucV7HJJ+uM/s3dZGb6C41bhYKZZHHYAwsUz4E0WeOzi67tphnPYzvJSG
# boLL0C436gKngKNkReNevnaAzMUyTr3pBqeJKEeV8v9KLgfTxY5wbH+gQvtesv63
# +wpQSGYDkb7FgJqfZGWcGMdO2+p1NjLkG7NVzajEuSPmNjGJiQyhEMtl
# SIG # End signature block
