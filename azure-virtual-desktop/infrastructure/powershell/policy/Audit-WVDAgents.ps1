Configuration Audit
{
    Import-DscResource -Module cChoco

    Node WindowsVirtualDesktopAgents 
    {
        cChocoInstaller Choco
        {
            InstallDir = "c:\choco"
        }

        cChocoPackageInstaller WVDAgentBootloader
        {
            Name                 = 'wvd-boot-loader'
            Ensure               = 'Present'
            DependsOn            = '[cChocoInstaller]Choco'
        }

        cChocoPackageInstaller WVDAgent
        {
            Name                 = 'wvd-agent'
            Ensure               = 'Present'
            DependsOn            = '[cChocoInstaller]Choco'
        }
    }
}

## Compile the configuration to create the MOF files
Audit ./Config