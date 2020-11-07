Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

Import-Module $PSScriptRoot/helpers/DscOperations.psm1 -Force
Import-Module $PSScriptRoot/helpers/GuestConfigurationPolicy.psm1 -Force
Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName GuestConfiguration.psd1 -BindingVariable GuestConfigurationManifest

$currentCulture = [System.Globalization.CultureInfo]::CurrentCulture
if(($currentCulture.Name -eq 'en-US-POSIX') -and ($(Get-OSPlatform) -eq 'Linux')) {
    Write-Warning "'$($currentCulture.Name)' Culture is not supported, changing it to 'en-US'"
    # Set Culture info to en-US
    [System.Globalization.CultureInfo]::CurrentUICulture = [System.Globalization.CultureInfo]::new('en-US')
    [System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::new('en-US')
}

#inject version info to GuestConfigPath.psm1
InitReleaseVersionInfo $GuestConfigurationManifest.moduleVersion

<#
    .SYNOPSIS
        Creates a Guest Configuration policy package.

    .Parameter Name
        Guest Configuration package name.

    .Parameter Configuration
        Compiled DSC configuration document full path.

    .Parameter Path
        Output folder path.
        This is an optional parameter. If not specified, the package will be created in the current directory.

    .Parameter ChefInspecProfilePath
        Chef profile path, supported only on Linux.

    .Example
        New-GuestConfigurationPackage -Name WindowsTLS -Configuration ./custom_policy/WindowsTLS/localhost.mof -Path ./git/repository/release/policy/WindowsTLS

    .OUTPUTS
        Return name and path of the new Guest Configuration Policy package.
#>

function New-GuestConfigurationPackage
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        [parameter(Position=1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Configuration,

        [ValidateNotNullOrEmpty()]
        [string] $ChefInspecProfilePath,

        [string] $Path = '.'
    )

    Try {
        $verbose = ($PSBoundParameters.ContainsKey("Verbose") -and ($PSBoundParameters["Verbose"] -eq $true))
        $reservedResourceName = @('OMI_ConfigurationDocument')
        $unzippedPackagePath = New-Item -ItemType Directory -Force -Path (Join-Path (Join-Path $Path $Name) 'unzippedPackage')
        $Configuration = Resolve-Path $Configuration

        if(-not (Test-Path -Path $Configuration -PathType Leaf)) {
            Throw "Invalid mof file path, please specify full file path for dsc configuration in -Configuration parameter."
        }
         
        Write-Verbose "Creating Guest Configuration package in temporary directory '$unzippedPackagePath'"

        # Verify that only supported resources are used in DSC configuration.
        Test-GuestConfigurationMofResourceDependencies -Path $Configuration -Verbose:$verbose

        # Save DSC configuration to the temporary package path.
        Save-GuestConfigurationMofDocument -Name $Name -SourcePath $Configuration -DestinationPath (Join-Path $unzippedPackagePath "$Name.mof") -Verbose:$verbose

        # Copy DSC resources
        Copy-DscResources -MofDocumentPath $Configuration -Destination $unzippedPackagePath -Verbose:$verbose

        if ($null -ne $ChefInspecProfilePath) {
            # Copy Chef resource and profiles.
            Copy-ChefInspecDependencies -PackagePath $unzippedPackagePath -Configuration $Configuration -ChefInspecProfilePath $ChefInspecProfilePath
        }
        
        # Create Guest Configuration Package.
        $packagePath = Join-Path $Path $Name
        New-Item -ItemType Directory -Force -Path $packagePath | Out-Null
        $packagePath = Resolve-Path $packagePath
        $packageFilePath = join-path $packagePath "$Name.zip"
        Remove-Item $packageFilePath -Force -ErrorAction SilentlyContinue

        Write-Verbose "Creating Guest Configuration package : $packageFilePath."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($unzippedPackagePath, $packageFilePath)

        $result = [pscustomobject]@{
            Name = $Name
            Path = $packageFilePath
        }
        return $result
    }
    Finally {
    }
}

<#
    .SYNOPSIS
        Tests a Guest Configuration policy package.

    .Parameter Path
        Full path of the zipped Guest Configuration package.

    .Parameter Parameter
        Policy parameters.

    .Example
        Test-GuestConfigurationPackage -Path ./custom_policy/WindowsTLS.zip

        $Parameter = @(
            @{
                ResourceType = "Service"            # dsc configuration resource type (mandatory)
                ResourceId = 'windowsService'       # dsc configuration resource property id (mandatory)
                ResourcePropertyName = "Name"       # dsc configuration resource property name (mandatory)
                ResourcePropertyValue = 'winrm'     # dsc configuration resource property value (mandatory)
            })

        Test-GuestConfigurationPackage -Path ./custom_policy/AuditWindowsService.zip -Parameter $Parameter

    .OUTPUTS
        Returns compliance details.
#>

function Test-GuestConfigurationPackage
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [parameter(Mandatory = $false)]
        [Hashtable[]] $Parameter = @()
    )

    if(-not (Test-Path $Path -PathType Leaf)) {
        Throw 'Invalid Guest Configuration package path.'
    }

    $verbose = ($PSBoundParameters.ContainsKey("Verbose") -and ($PSBoundParameters["Verbose"] -eq $true))
    $systemPSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath", "Process")

    Try {
        # Create policy folder
        $Path = Resolve-Path $Path
        $policyPath = Join-Path $(Get-GuestConfigPolicyPath) ([System.IO.Path]::GetFileNameWithoutExtension($Path))
        Remove-Item $policyPath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $policyPath | Out-Null

        # Unzip policy package.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $policyPath)

        # Get policy name
        $dscDocument = Get-ChildItem -Path $policyPath -Filter *.mof
        if(-not $dscDocument) {
            Throw "Invalid policy package, failed to find dsc document in policy package."
        }
        $policyName = [System.IO.Path]::GetFileNameWithoutExtension($dscDocument)

        # update configuration parameters
        if($Parameter.Count -gt 0) {
            Update-MofDocumentParameters -Path $dscDocument.FullName -Parameter $Parameter
        }

        # Unzip Guest Configuration binaries
        $gcBinPath = Get-GuestConfigBinaryPath
        $gcBinRootPath = Get-GuestConfigBinaryRootPath
        if(-not (Test-Path $gcBinPath)) {
            # Clean the bin folder
            Remove-Item $gcBinRootPath'\*' -Recurse -Force -ErrorAction SilentlyContinue

            $zippedBinaryPath = Join-Path $(Get-GuestConfigurationModulePath) 'bin'
            if($(Get-OSPlatform) -eq 'Windows') {
                $zippedBinaryPath = Join-Path $zippedBinaryPath 'DSC_Windows.zip'
            }
            else {
                # Linux zip package contains an additional DSC folder
                # Remove DSC folder from binary path to avoid two nested DSC folders.
                New-Item -ItemType Directory -Force -Path $gcBinPath | Out-Null
                $gcBinPath = (Get-Item $gcBinPath).Parent.FullName
                $zippedBinaryPath = Join-Path $zippedBinaryPath 'DSC_Linux.zip'
            }
            [System.IO.Compression.ZipFile]::ExtractToDirectory($zippedBinaryPath, $gcBinPath)
        }

        # Publish policy package
        Publish-DscConfiguration -ConfigurationName $policyName -Path $policyPath -Verbose:$verbose

        # Set LCM settings to force load powershell module.
        $metaConfigPath = Join-Path $policyPath "$policyName.metaconfig.json"
        "{""debugMode"":""ForceModuleImport""}" | Out-File $metaConfigPath -Encoding ascii
        Set-DscLocalConfigurationManager -ConfigurationName $policyName -Path $policyPath -Verbose:$verbose

        # Clear Inspec profiles
        Remove-Item $(Get-InspecProfilePath) -Recurse -Force -ErrorAction SilentlyContinue

        $testResult = Test-DscConfiguration -ConfigurationName $policyName -Verbose:$verbose
        $getResult = @()
        $getResult = $getResult + (Get-DscConfiguration -ConfigurationName $policyName -Verbose:$verbose)

        $testResult.resources_not_in_desired_state | ForEach-Object {
            $resourceId = $_;
            if ($getResult.count -gt 1) {
                for($i = 0; $i -lt $getResult.Count; $i++) {
                    if($getResult[$i].ResourceId -ieq $resourceId) {
                        $getResult[$i] = $getResult[$i] | Select-Object *, @{n='complianceStatus';e={$false}}
                    }
                }
            }
            elseif ($getResult.ResourceId -ieq $resourceId) {
                $getResult = $getResult | Select-Object *, @{n='complianceStatus';e={$false}}
            }
        }

        $testResult.resources_in_desired_state | ForEach-Object {
            $resourceId = $_;
            if ($getResult.count -gt 1) {
                for($i = 0; $i -lt $getResult.Count; $i++) {
                    if($getResult[$i].ResourceId -ieq $resourceId) {
                        $getResult[$i] = $getResult[$i] | Select-Object *, @{n='complianceStatus';e={$true}}
                    }
                }
            }
            elseif ($getResult.ResourceId -ieq $resourceId) {
                $getResult = $getResult | Select-Object *, @{n='complianceStatus';e={$true}}
            }
        }

        $result = New-Object -TypeName PSObject
        $properties = [ordered]@{ complianceStatus = $testResult.compliance_state; resources = $getResult}
        $result | Add-Member -NotePropertyMembers $properties

        return $result;
    }
    Finally {
        $env:PSModulePath = $systemPSModulePath
    }
}

<#
    .SYNOPSIS
        Signs a Guest Configuration policy package using certificate on Windows and Gpg keys on Linux.

    .Parameter Path
        Full path of the Guest Configuration package.

    .Parameter Certificate
        'Code Signing' certificate to sign the package. This is only supported on Windows.

    .Parameter PrivateGpgKeyPath
        Private Gpg key path. This is only supported on Linux.

    .Parameter PublicGpgKeyPath
        Public Gpg key path. This is only supported on Linux.

    .Example
        $Cert = Get-ChildItem -Path Cert:/CurrentUser/AuthRoot -Recurse | Where-Object {($_.Thumbprint -eq "0563b8630d62d75abbc8ab1e4bdfb5a899b65d43") }
        Protect-GuestConfigurationPackage -Path ./custom_policy/WindowsTLS.zip -Certificate $Cert

    .OUTPUTS
        Return name and path of the signed Guest Configuration Policy package.
#>

function Protect-GuestConfigurationPackage
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Certificate")]
        [parameter(Position=0, Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "GpgKeys")]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [parameter(Mandatory = $true, ParameterSetName = "Certificate")]
        [ValidateNotNullOrEmpty()]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [parameter(Mandatory = $true, ParameterSetName = "GpgKeys")]
        [ValidateNotNullOrEmpty()]
        [string] $PrivateGpgKeyPath,

        [parameter(Mandatory = $true, ParameterSetName = "GpgKeys")]
        [ValidateNotNullOrEmpty()]
        [string] $PublicGpgKeyPath
    )

    $Path = Resolve-Path $Path
    if(-not (Test-Path $Path -PathType Leaf)) {
        Throw 'Invalid Guest Configuration package path.'
    }

    Try {
        $packageFileName = ([System.IO.Path]::GetFileNameWithoutExtension($Path))
        $signedPackageFilePath = Join-Path (Get-ChildItem $Path).Directory "$($packageFileName)_signed.zip"
        $tempDir = Join-Path (Get-ChildItem $Path).Directory 'temp'
        Remove-Item $signedPackageFilePath -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

        # Unzip policy package.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($Path, $tempDir)

        # Get policy name
        $dscDocument = Get-ChildItem -Path $tempDir -Filter *.mof
        if(-not $dscDocument) {
            Throw "Invalid policy package, failed to find dsc document in policy package."
        }
        $policyName = [System.IO.Path]::GetFileNameWithoutExtension($dscDocument)

        $osPlatform  = Get-OSPlatform
        if($PSCmdlet.ParameterSetName -eq "Certificate") {
            if($osPlatform -eq "Linux") {
                throw 'Certificate signing not supported on Linux.'
            }

            # Create catalog file
            $catalogFilePath = Join-Path $tempDir "$policyName.cat"
            Remove-Item $catalogFilePath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Creating catalog file : $catalogFilePath."
            New-FileCatalog -Path $tempDir -CatalogVersion 2.0 -CatalogFilePath $catalogFilePath | Out-Null

            # Sign catalog file
            Write-Verbose "Signing catalog file : $catalogFilePath."
            $CodeSignOutput = Set-AuthenticodeSignature -Certificate $Certificate -FilePath $catalogFilePath

            if ($CodeSignOutput.Status -match 'Error') {
                Write-Error $CodeSignOutput.StatusMessage
            }
        }
        else {
            if($osPlatform -eq "Windows") {
                throw 'Gpg signing not supported on Windows.'
            }

            $PrivateGpgKeyPath = Resolve-Path $PrivateGpgKeyPath
            $PublicGpgKeyPath = Resolve-Path $PublicGpgKeyPath
            $ascFilePath = Join-Path $tempDir "$policyName.asc"
            $hashFilePath = Join-Path $tempDir "$policyName.sha256sums"

            Remove-Item $ascFilePath -Force -ErrorAction SilentlyContinue
            Remove-Item $hashFilePath -Force -ErrorAction SilentlyContinue

            Write-Verbose "Creating file hash : $hashFilePath."
            pushd $tempDir
            bash -c "find ./ -type f -print0 | xargs -0 sha256sum | grep -v sha256sums > $hashFilePath"
            popd

            Write-Verbose "Signing file hash : $hashFilePath."
            gpg --import $PrivateGpgKeyPath
            gpg --no-default-keyring --keyring $PublicGpgKeyPath --output $ascFilePath --armor --detach-sign $hashFilePath
        }

        # Zip the signed Guest Configuration package
        Write-Verbose "Creating signed Guest Configuration package : $signedPackageFilePath."
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $signedPackageFilePath)

        $result = [pscustomobject]@{
            Name = $policyName
            Path = $signedPackageFilePath
        }
        return $result
    }
    Finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

<#
    .SYNOPSIS
        Creates Audit, DeployIfNotExists and Initiative policy definitions on specified Destination Path.

    .Parameter ContentUri
        Public http uri of Guest Configuration content package.

    .Parameter DisplayName
        Policy display name.

    .Parameter Description
        Policy description.

    .Parameter Parameter
        Policy parameters.

    .Parameter Version
        Policy version.

    .Parameter Path
        Destination path.

    .Parameter Platform
        Target platform (Windows/Linux) for Guest Configuration policy and content package.
        Windows is the default platform.

    .Example
        New-GuestConfigurationPolicy `
                                 -ContentUri https://github.com/azure/auditservice/release/AuditService.zip `
                                 -DisplayName 'Monitor Windows Service Policy.' `
                                 -Description 'Policy to monitor service on Windows machine.' `
                                 -Version 1.0.0.0 
                                 -Path ./git/custom_policy

        $PolicyParameterInfo = @(
            @{
                Name = 'ServiceName'                                       # Policy parameter name (mandatory)
                DisplayName = 'windows service name.'                      # Policy parameter display name (mandatory)
                Description = "Name of the windows service to be audited." # Policy parameter description (optional)
                ResourceType = "Service"                                   # dsc configuration resource type (mandatory)
                ResourceId = 'windowsService'                              # dsc configuration resource property name (mandatory)
                ResourcePropertyName = "Name"                              # dsc configuration resource property name (mandatory)
                DefaultValue = 'winrm'                                     # Policy parameter default value (optional)
                AllowedValues = @('wscsvc','WSearch','wcncsvc','winrm')    # Policy parameter allowed values (optional)
            })

            New-GuestConfigurationPolicy -ContentUri 'https://github.com/azure/auditservice/release/AuditService.zip' `
                                 -DisplayName 'Monitor Windows Service Policy.' `
                                 -Description 'Policy to monitor service on Windows machine.' `
                                 -Version 1.0.0.0 
                                 -Path ./policyDefinitions `
                                 -Parameter $PolicyParameterInfo 

    .OUTPUTS
        Return name and path of the Guest Configuration policy definitions.
#>

function New-GuestConfigurationPolicy
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ContentUri,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Description,

        [parameter(Mandatory = $false)]
        [Hashtable[]] $Parameter,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [version] $Version = '1.0.0.0',

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter()]
        [ValidateSet('Windows', 'Linux')]
        [string]
        $Platform = 'Windows',

        [parameter(Mandatory = $false)]
        [string] $Category = 'Guest Configuration'
    )

    Try {
        $verbose = ($PSBoundParameters.ContainsKey("Verbose") -and ($PSBoundParameters["Verbose"] -eq $true))
        $policyDefinitionsPath = $Path
        $unzippedPkgPath = Join-Path $policyDefinitionsPath 'temp'
        $tempContentPackageFilePath = Join-Path $policyDefinitionsPath 'temp.zip'

        # update parameter info
        $ParameterInfo = Update-PolicyParameter -Parameter $Parameter

        New-Item -ItemType Directory -Force -Path $policyDefinitionsPath | Out-Null

        # Check if ContentUri is a valid web Uri
        $uri = $ContentUri -as [System.URI]
        if(-not ($uri.AbsoluteURI -ne $null -and $uri.Scheme -match '[http|https]')) {
            Throw "Invalid ContentUri : $ContentUri. Please specify a valid http URI in -ContentUri parameter."
        }

        # Generate checksum hash for policy content.
        Invoke-WebRequest -Uri $ContentUri -OutFile $tempContentPackageFilePath
        $tempContentPackageFilePath = Resolve-Path $tempContentPackageFilePath
        $contentHash = (Get-FileHash $tempContentPackageFilePath -Algorithm SHA256).Hash
        Write-Verbose "SHA256 Hash for content '$ContentUri' : $contentHash."

        # Get the policy name from policy content.
        Remove-Item $unzippedPkgPath -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Force -Path $unzippedPkgPath | Out-Null
        $unzippedPkgPath = Resolve-Path $unzippedPkgPath
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($tempContentPackageFilePath, $unzippedPkgPath)
        $dscDocument = Get-ChildItem -Path $unzippedPkgPath -Filter *.mof -Exclude '*.schema.mof' -Depth 1
        if(-not $dscDocument) {
            Throw "Invalid policy package, failed to find dsc document in policy package."
        }
        $policyName = [System.IO.Path]::GetFileNameWithoutExtension($dscDocument)

        $packageIsSigned = (((Get-ChildItem -Path $unzippedPkgPath -Filter *.cat) -ne $null) -or `
                            (((Get-ChildItem -Path $unzippedPkgPath -Filter *.asc) -ne $null) -and ((Get-ChildItem -Path $unzippedPkgPath -Filter *.sha256sums) -ne $null)))

        $DeployPolicyInfo = @{
            FileName = "DeployIfNotExists.json"
            DisplayName = "[Deploy] $DisplayName"
            Description = $Description 
            ConfigurationName = $policyName
            ConfigurationVersion = $Version
            ContentUri = $ContentUri
            ContentHash = $contentHash
            ReferenceId = "Deploy_$policyName"
            ParameterInfo = $ParameterInfo
            UseCertificateValidation = $packageIsSigned
            Category = $Category
        }
        $AuditPolicyInfo = @{
            FileName = "AuditIfNotExists.json"
            DisplayName = "[Audit] $DisplayName"
            Description = $Description 
            ConfigurationName = $policyName
            ReferenceId = "Audit_$policyName"
        }
        $InitiativeInfo = @{
            FileName = "Initiative.json"
            DisplayName = "[Initiative] $DisplayName"
            Description = $Description 
        }

        Write-Verbose "Creating policy definitions at $policyDefinitionsPath path."
        New-CustomGuestConfigPolicy -PolicyFolderPath $policyDefinitionsPath -DeployPolicyInfo $DeployPolicyInfo -AuditPolicyInfo $AuditPolicyInfo -InitiativeInfo $InitiativeInfo -Platform $Platform -Verbose:$verbose | Out-Null

        $result = [pscustomobject]@{
            Name = $policyName
            Path = $Path
        }
        return $result
    }
    Finally {
        # Remove temporary content package.
        Remove-Item $tempContentPackageFilePath -Force -ErrorAction SilentlyContinue
        Remove-Item $unzippedPkgPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

<#
    .SYNOPSIS
        Publishes the Guest Configuration policy in Azure Policy Center.

    .Parameter Path
        Guest Configuration policy path.

    .Example
        Publish-GuestConfigurationPolicy -Path ./git/custom_policy
#>

function Publish-GuestConfigurationPolicy
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [parameter(Mandatory = $false)]
        [string] $ManagementGroupName
    )

    $rmContext = Get-AzContext
    Write-Verbose "Publishing Guest Configuration policy using '$($rmContext.Name)' AzContext."

    # Publish policies
    $subscriptionId = $rmContext.Subscription.Id
    foreach ($policy in @("AuditIfNotExists.json", "DeployIfNotExists.json")){
        $policyFile = join-path $Path $policy
        $jsonDefinition = Get-Content $policyFile | ConvertFrom-Json | ForEach-Object {$_}
        $definitionContent = $jsonDefinition.Properties

        $newAzureRmPolicyDefinitionParameters = @{
            Name = $jsonDefinition.name
            DisplayName = $($definitionContent.DisplayName | ConvertTo-Json -Depth 20).replace('"','')
            Description = $($definitionContent.Description | ConvertTo-Json -Depth 20).replace('"','')
            Policy = $($definitionContent.policyRule | ConvertTo-Json -Depth 20)
            Metadata = $($definitionContent.Metadata | ConvertTo-Json -Depth 20)
            ApiVersion = '2018-05-01'
            Verbose = $true
        }

        if ($definitionContent.PSObject.Properties.Name -contains 'parameters')
        {
            $newAzureRmPolicyDefinitionParameters['Parameter'] = ConvertTo-Json -InputObject $definitionContent.parameters -Depth 15
        }

        if ($ManagementGroupName) {
            $newAzureRmPolicyDefinitionParameters['ManagementGroupName'] = $ManagementGroupName
        }

        Write-Verbose "Publishing '$($jsonDefinition.properties.displayName)' ..."
        New-AzPolicyDefinition @newAzureRmPolicyDefinitionParameters
    }

    # Process initiative
    $initiativeFile = join-path $Path "Initiative.json"
    $jsonDefinition = Get-Content $initiativeFile | ConvertFrom-Json | ForEach-Object {$_}

    # Update with subscriptionId
    foreach($definitions in $jsonDefinition.properties.policyDefinitions){
        $definitions.policyDefinitionId = "/subscriptions/$subscriptionId" + $definitions.policyDefinitionId
    }

    Write-Verbose "Publishing '$($jsonDefinition.properties.displayName)' ..."
    $initiativeContent = $jsonDefinition.Properties

    $newAzureRmPolicySetDefinitionParameters = @{
        Name = $jsonDefinition.name
        DisplayName = $($initiativeContent.DisplayName | ConvertTo-Json -Depth 20).replace('"','')
        Description = $($initiativeContent.Description | ConvertTo-Json -Depth 20).replace('"','')
        PolicyDefinition = $($initiativeContent.policyDefinitions | ConvertTo-Json -Depth 20)
        Metadata = $($initiativeContent.Metadata | ConvertTo-Json -Depth 20)
        ApiVersion = '2018-05-01'
        Verbose = $true
    }

    if ($initiativeContent.PSObject.Properties.Name -contains 'parameters')
    {
        $newAzureRmPolicySetDefinitionParameters['Parameter'] = ConvertTo-Json -InputObject $initiativeContent.parameters -Depth 15
    }

    New-AzPolicySetDefinition @newAzureRmPolicySetDefinitionParameters
}

Export-ModuleMember -Function @('New-GuestConfigurationPackage', 'Test-GuestConfigurationPackage', 'Protect-GuestConfigurationPackage', 'New-GuestConfigurationPolicy', 'Publish-GuestConfigurationPolicy')
# SIG # Begin signature block
# MIIjlgYJKoZIhvcNAQcCoIIjhzCCI4MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA95uQnfPJTgCgA
# lEYO0GhMmdjJ05eIu7XPbjUuxJIBTaCCDYUwggYDMIID66ADAgECAhMzAAABUptA
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIA/y
# s7mP1zlyfZfwCJD7JfejNrmk68gAKKC36hAwUX96MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAVwiRNjPzEst3QVrNDqNP0XWtGlD/wF+w1/vm
# T4TenoOCO1A0K16L2F5iml0WBFobSFRfj2L60bgXHp1VfmXrGwS7jBj7T4LfQ2A8
# Ynz9Qlg5QOJxayzdIZSMskkK8YAYTLlZTRqhK7Pf0ZhYMQGRXhQJdQn5OWUMFJWQ
# HgT5wgnBbx8Vyj9Yu1E88ORX55rAky1a6myLCZUKJsS4seCShT9ZylhJiF3oTOYC
# CCCQ2a2+3/uPp/cbRGbluBxFFHEdctf6kLKIzYytpLRJ/rPFxCaRt063AouIApKe
# 0awcNtMcNqXgy8NAF6AxHakEnGdw0SziGu+0mhVyzJjxHM93p6GCEvEwghLtBgor
# BgEEAYI3AwMBMYIS3TCCEtkGCSqGSIb3DQEHAqCCEsowghLGAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFVBgsqhkiG9w0BCRABBKCCAUQEggFAMIIBPAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCBVoQnu6VOioutoRJBiDiqUBwdRd2xP+Wvn
# dujPTisHawIGXnjYDHZuGBMyMDIwMDQyMjIyNDE1Ni43MzZaMASAAgH0oIHUpIHR
# MIHOMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQL
# EyBNaWNyb3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046NjBCQy1FMzgzLTI2MzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2Wggg5EMIIE9TCCA92gAwIBAgITMwAAASbfuksiuYKC
# BwAAAAABJjANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0Eg
# MjAxMDAeFw0xOTEyMTkwMTE0NTlaFw0yMTAzMTcwMTE0NTlaMIHOMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQg
# T3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046
# NjBCQy1FMzgzLTI2MzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNl
# cnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCeML6GnE7zDZV0
# E7XxfwseTpd19H3I1DTL4y4E5juflh2CRW6e9uT9/qrxSg0UB1hCNUs9IAduLq1Q
# yI14wYeTVTSVTECSNrZbb+zOP+CG4WSW98c0Fuy6JRKGWFGWpwU1LspcvaLAoOKO
# Y6FYk9hrZssSvhb+ZAttJdqKXmnqbXfxO3HgwBUTPO4YjQrCvyh8gvvPrMJ5YOIE
# znsus0Koc4DbBuh64ywbg7Q7PYswDMEtslk9E+dkAPYd0PgdQvabNnzCjHvgx6Rv
# tHOtQ/eGIenFdlx4m+EgQp8CBWQHmRNlCeKjwDUmKMyPDx/hOawk90lamLx6Lvex
# 7F7z9iNzAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUSausHxewfphCjdFYpl/GozQO
# YUEwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBL
# oEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMv
# TWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggr
# BgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
# BggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAQJb7nWjpb/Qn87+em51+NXMx
# erS7RyweOpel1HIfqjTeOWZjkxcC6LdyY8Eq5+KMnEPakxE9UxQ2HdUDQ9C4l5is
# /TqgV2oukvF3cgkBGb3y/NoyALPacLAEOl71fYzcmz0rUYBf7DgDPw3sn5no/U4P
# RXEcF2p5NqoM3WWTW/BqBM3u39aK3ExdEPPSFF1iJZsBMEBWBdcI5/OzeGcS/Wf8
# QNpv0dc4sxcpVj/5qWpgp1X2WS5GnxSzVDVZnL3PvYDO73HibN+3d8nWm5OMEejm
# 0d+LFmi6aZsj5bCNUKuS7umyQlqF82LlqZKCuqBHqdYDC+kkQtxylUt1LHGYbTCC
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
# U046NjBCQy1FMzgzLTI2MzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WiIwoBATAHBgUrDgMCGgMVAApnMjlpmcRK6atOgfHcuqDGev/8oIGD
# MIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEF
# BQACBQDiSuM0MCIYDzIwMjAwNDIyMTkzNzI0WhgPMjAyMDA0MjMxOTM3MjRaMHcw
# PQYKKwYBBAGEWQoEATEvMC0wCgIFAOJK4zQCAQAwCgIBAAICKKsCAf8wBwIBAAIC
# EQgwCgIFAOJMNLQCAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAK
# MAgCAQACAwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQAFO0jxApTo
# BfsZw+j+QN+sFqSG6lH31sLmWxh0twx+4N+77E4bcIZr0BKGsMQkbFUQAPblFx+z
# sSHHVtuKlRYxkiwaCwsnihxmStlmStlI/ZZOMcNbPWggG0JdaDPscKniLQQrNTX1
# 5WTdyAAFDoHYzSMSLiZPzuWtSiqMcXY3MTGCAw0wggMJAgEBMIGTMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABJt+6SyK5goIHAAAAAAEmMA0GCWCG
# SAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZI
# hvcNAQkEMSIEIBM10IX452tVu0xh+QSshuChXibdNUILiwDJsbUTHuXNMIH6Bgsq
# hkiG9w0BCRACLzGB6jCB5zCB5DCBvQQgNv3P7569XnAM72qTlmdsRnwJM65H6RnK
# 7zFtOwkJdQ8wgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAASbfuksiuYKCBwAAAAABJjAiBCCp1CLL2pCTMlws6E/HzizSvTxHg6fZVMvt
# Ozlm+Q4LnTANBgkqhkiG9w0BAQsFAASCAQA521CO4kJSIQvgEKgwGv4v1tmwSx/g
# v6lOU5f6ktUDYGfT1wry+yNB4RqKSovAiEG9CrtVwItYn+DUABmJCY+xLtCgCdov
# bE2tNsyODZVIfrL2sqtZfz69Sulk2S0kqrVgjz066FX3w4XVT2mL/6L6mv2q5z75
# HKpEAhfu2jwp6dw09oO3bl3+SzzEEWGDCDWc7aeGeqttMdYmc5RRoPlk2v+43bS4
# hPETUFlO4YXciQJdChrbMezjRdgz9UD1I7hPA65zM33TS4tpfkTufYaFCzZ228d5
# ujdA3R3o9hs/7KwBe+fn7pxq1rH+epdebuqbUsMJ3BkZ+Cm2api4KwLj
# SIG # End signature block
