Configuration dConfiguration
{
    Import-DscResource -ModuleName 'DatadogConfigurationManagement'
    Import-DscResource -ModuleName 'SqlServerDsc'

    Node 'SQLServer'
    {
        Apply 'Configuration files'
        {
            configurations = "sqlserver","main","win32_event_log"
            storageAccountName = Get-AutomationVariable -Name 'dStorageAccountName'
            token = Get-AutomationVariable -Name 'dToken'
        }

        
        SqlServerLogin 'Datadog service account'
        {
            Ensure                         = 'Present'
            Name                           = (Get-AutomationPSCredential -Name 'dSQLServerSvcAccount').Username
            LoginType                      = 'SqlLogin'
            ServerName                     = ''
            InstanceName                   = ''
            LoginCredential                = Get-AutomationPSCredential -Name 'dSQLServerSvcAccount'
            LoginMustChangePassword        = $false
            LoginPasswordExpirationEnabled = $false
            LoginPasswordPolicyEnforced    = $false
            PsDscRunAsCredential           = Get-AutomationPSCredential -Name 'dSQLServerAdministratorAccount'
        }
    }
}