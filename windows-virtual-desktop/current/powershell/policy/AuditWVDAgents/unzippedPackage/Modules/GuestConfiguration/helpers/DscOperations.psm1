Set-StrictMode -Version latest
$ErrorActionPreference = 'Stop'

Import-Module $PSScriptRoot/GuestConfigPath.psm1 -Force

$script:ExecuteDscOperationsScript = @"
using System;
using System.Runtime.InteropServices;
using System.Management.Automation;
using System.Collections;
using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace GuestConfig
{{
    public class DscOperations
    {{
        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern IntPtr new_dsc_library_context(string assignment_name, string dsc_binary_path, IntPtr writeMessageCallback, IntPtr writeErrorCallback, IntPtr writeResultCallback);

        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern Int32 test_dsc_configuration(IntPtr context, string job_id, string assignment_name, string file_path);

        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern Int32 get_dsc_configuration(IntPtr context, string job_id, string assignment_name, string file_path);

        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern Int32 publish_dsc_assignment(IntPtr context, string job_id, string assignment_name, string assignments_path);

        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern Int32 set_dsc_meta_configuration(IntPtr context, string job_id, string assignment_name, string assignments_path);

        [DllImport("{0}", CharSet = CharSet.Ansi, SetLastError = true, CallingConvention = CallingConvention.StdCall)]
        public static extern void delete_dsc_library_context(IntPtr context);

        internal enum MessageChannel
        {{
            Warning,
            Verbose,
            Debug,
            Error
        }}

        public DscOperations()
        {{
            m_messages = new List<Tuple<MessageChannel, string>>();
            m_result = "";

            WriteMessageDelegate delegate_write_message = new WriteMessageDelegate(WriteMessage);
            GCHandle m_write_message_gc_handle = GCHandle.Alloc(delegate_write_message);
            m_write_message_callback = Marshal.GetFunctionPointerForDelegate(delegate_write_message);

            WriteErrorDelegate delegate_write_error = new WriteErrorDelegate(WriteError);
            m_write_error_gc_handle = GCHandle.Alloc(delegate_write_error);
            m_write_error_callback = Marshal.GetFunctionPointerForDelegate(delegate_write_error);

            WriteResultDelegate delegate_write_result = new WriteResultDelegate(WriteResult);
            m_write_result_gc_handle = GCHandle.Alloc(delegate_write_result);
            m_write_result_callback = Marshal.GetFunctionPointerForDelegate(delegate_write_result);
        }}

        ~DscOperations()
        {{
            if (m_write_message_gc_handle.IsAllocated)
            {{
                m_write_message_gc_handle.Free();
            }}

            if (m_write_error_gc_handle.IsAllocated)
            {{
                m_write_error_gc_handle.Free();
            }}

            if (m_write_result_gc_handle.IsAllocated)
            {{
                m_write_result_gc_handle.Free();
            }}
        }}

        public string TestDscConfiguration(PSCmdlet ps_cmdlet, string job_id, string configuration_name, string gc_bin_path)
        {{
            IntPtr context = IntPtr.Zero;
            try
            {{
                ClearMessages();

                context = new_dsc_library_context(configuration_name, gc_bin_path, m_write_message_callback, m_write_error_callback, m_write_result_callback);
                if(context == IntPtr.Zero) 
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to initialize Guest Configuration library.", true));
                }}

                Int32 result = test_dsc_configuration(context, job_id, configuration_name, "");
                for (int i = 0; i < m_messages.Count; i++) 
                {{
                    var message = m_messages[i];
                    if(message.Item1 == MessageChannel.Error) 
                    {{
                        ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", message.Item2, false));
                    }}
                    else if(message.Item1 == MessageChannel.Warning) 
                    {{
                        ps_cmdlet.WriteWarning(message.Item2);
                    }}
                    else if(message.Item1 == MessageChannel.Debug) 
                    {{
                        ps_cmdlet.WriteDebug(message.Item2);
                    }}
                    else 
                    {{
                        ps_cmdlet.WriteVerbose(message.Item2);
                    }}
                }}
            }}
            finally 
            {{
                delete_dsc_library_context(context);
            }}

            return m_result;
        }}

        public string GettDscConfiguration(PSCmdlet ps_cmdlet, string job_id, string configuration_name, string gc_bin_path)
        {{
            IntPtr context = IntPtr.Zero;
            try
            {{
                ClearMessages();

                context = new_dsc_library_context(configuration_name, gc_bin_path, m_write_message_callback, m_write_error_callback, m_write_result_callback);
                if(context == IntPtr.Zero) 
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to initialize Guest Configuration library.", true));
                }}

                Int32 result = get_dsc_configuration(context, job_id, configuration_name, "");
                for (int i = 0; i < m_messages.Count; i++) 
                {{
                    var message = m_messages[i];
                    if(message.Item1 == MessageChannel.Error) 
                    {{
                        ps_cmdlet.WriteError(new ErrorRecord(
                                    new InvalidOperationException(message.Item2),
                                    "TestGuestConfiguration",
                                    ErrorCategory.InvalidResult,
                                    null));
                    }}
                    else if(message.Item1 == MessageChannel.Warning) 
                    {{
                        ps_cmdlet.WriteWarning(message.Item2);
                    }}
                    else 
                    {{
                        ps_cmdlet.WriteVerbose(message.Item2);
                    }}
                }}
            }}
            finally 
            {{
                delete_dsc_library_context(context);
            }}

            return m_result;
        }}

        public void PublishDscConfiguration(PSCmdlet ps_cmdlet, string job_id, string configuration_name, string gc_bin_path, string policy_path)
        {{
            IntPtr context = IntPtr.Zero;
            try
            {{
                ClearMessages();

                context = new_dsc_library_context(configuration_name, gc_bin_path, m_write_message_callback, m_write_error_callback, m_write_result_callback);
                if(context == IntPtr.Zero)
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to initialize Guest Configuration library.", true));
                }}

                Int32 result = publish_dsc_assignment(context, job_id, configuration_name, policy_path);
                if(result != 0)
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to publish Guest Configuration policy package.", true));
                }}
            }}
            finally 
            {{
                delete_dsc_library_context(context);
            }}
        }}

        public void SetDscLocalConfigurationManager(PSCmdlet ps_cmdlet, string job_id, string configuration_name, string gc_bin_path, string policy_path)
        {{
            IntPtr context = IntPtr.Zero;
            try
            {{
                ClearMessages();

                context = new_dsc_library_context(configuration_name, gc_bin_path, m_write_message_callback, m_write_error_callback, m_write_result_callback);
                if(context == IntPtr.Zero)
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to initialize Guest Configuration library.", true));
                }}

                Int32 result = set_dsc_meta_configuration(context, job_id, configuration_name, policy_path);
                if(result != 0) 
                {{
                    ps_cmdlet.WriteError(CreateErrorRecord("TestGuestConfiguration", "Failed to set Meta config settings.", true));
                }}
            }}
            finally 
            {{
                delete_dsc_library_context(context);
            }}
        }}

        private delegate Int32 WriteMessageDelegate(Int32 channel, IntPtr message);
        private delegate Int32 WriteErrorDelegate(IntPtr error);
        private delegate Int32 WriteResultDelegate(IntPtr result);

        private string m_result;
        private List<Tuple<MessageChannel, string>> m_messages;

        private GCHandle m_write_message_gc_handle;
        private GCHandle m_write_error_gc_handle;
        private GCHandle m_write_result_gc_handle;
        private IntPtr m_write_message_callback;
        private IntPtr m_write_error_callback;
        private IntPtr m_write_result_callback;

        internal Int32 WriteMessage(Int32 channel, IntPtr message_ptr)
        {{
            string message;
            message = Marshal.PtrToStringAnsi(message_ptr);
            m_messages.Add(Tuple.Create((MessageChannel)channel, message));
            return 0;
        }}

        internal Int32 WriteError(IntPtr error_ptr)
        {{
            string error;
            error = Marshal.PtrToStringAnsi(error_ptr);
            m_messages.Add(Tuple.Create(MessageChannel.Error, error));
            return 0;
        }}

        internal Int32 WriteResult(IntPtr result_ptr)
        {{
            m_result = Marshal.PtrToStringAnsi(result_ptr);
            return 0;
        }}

        private void ClearMessages()
        {{
            m_messages.Clear();
        }}

        private ErrorRecord CreateErrorRecord(string error_id, string error_message, bool include_error_from_message_list) 
        {{
            string error = error_message + "\r\n";
            for (int i = 0; include_error_from_message_list && i < m_messages.Count; i++) 
            {{
                var message = m_messages[i];
                if(message.Item1 == MessageChannel.Error) 
                {{
                    error = message.Item2 + "\r\n";
                }}
            }}

            return new ErrorRecord(
                    new InvalidOperationException(error),
                    error_id,
                    ErrorCategory.InvalidResult,
                    null);
        }}
    }}
}}
"@


<#
    .SYNOPSIS
        Test DSC configuration.

    .Parameter ConfigurationName
        Configuration name.

    .Example
        Test-DscConfiguration -ConfigurationName WindowsTLS
#>

function Test-DscConfiguration
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationName
    )

    $job_id = [guid]::NewGuid().Guid
    $gcBinPath = Get-GuestConfigBinaryPath
    $dsclibPath = $(Get-DscLibPath) -replace  '[""\\]','\$&'

    if(-not ([System.Management.Automation.PSTypeName]'GuestConfig.DscOperations').Type) {
        $addTypeScript = $ExecuteDscOperationsScript -f $dsclibPath
        Add-Type -TypeDefinition $addTypeScript -ReferencedAssemblies 'System.Management.Automation','System.Console','System.Collections'
    }

    $dscOperation = [GuestConfig.DscOperations]::New()
    $result = $dscOperation.TestDscConfiguration($PSCmdlet, $job_id, $ConfigurationName, $gcBinPath)

    return ConvertFrom-Json $result
}

<#
    .SYNOPSIS
        Get DSC configuration.

    .Parameter ConfigurationName
        Configuration name.

    .Example
        Get-DscConfiguration -ConfigurationName WindowsTLS
#>

function Get-DscConfiguration
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationName
    )

    $job_id = [guid]::NewGuid().Guid
    $gcBinPath = Get-GuestConfigBinaryPath
    $dsclibPath = $(Get-DscLibPath) -replace  '[""\\]','\$&'

    if(-not ([System.Management.Automation.PSTypeName]'GuestConfig.DscOperations').Type) {
        $addTypeScript = $ExecuteDscOperationsScript -f $dsclibPath
        Add-Type -TypeDefinition $addTypeScript -ReferencedAssemblies 'System.Management.Automation','System.Console','System.Collections'
    }

    $dscOperation = [GuestConfig.DscOperations]::New()
    $result = $dscOperation.GettDscConfiguration($PSCmdlet, $job_id, $ConfigurationName, $gcBinPath)

    return ConvertFrom-Json $result
}

<#
    .SYNOPSIS
        Publish DSC configuration.

    .Parameter ConfigurationName
        Configuration name.

    .Example
        Publish-DscConfiguration -Path C:\metaconfig
#>

function Publish-DscConfiguration
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationName,

        [parameter(Position=1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $job_id = [guid]::NewGuid().Guid
    $gcBinPath = Get-GuestConfigBinaryPath
    $dsclibPath = $(Get-DscLibPath) -replace  '[""\\]','\$&'

    if(-not ([System.Management.Automation.PSTypeName]'GuestConfig.DscOperations').Type) {
        $addTypeScript = $ExecuteDscOperationsScript -f $dsclibPath
        Add-Type -TypeDefinition $addTypeScript -ReferencedAssemblies 'System.Management.Automation','System.Console','System.Collections'
    }

    $dscOperation = [GuestConfig.DscOperations]::New()
    $result = $dscOperation.PublishDscConfiguration($PSCmdlet, $job_id, $ConfigurationName, $gcBinPath, $Path)
}

<#
    .SYNOPSIS
        Set DSC LCM settings.

    .Parameter ConfigurationName
        Configuration name.

    .Example
        Set-DscLocalConfigurationManager -Path C:\metaconfig
#>

function Set-DscLocalConfigurationManager
{
    [CmdletBinding()]
    param (
        [parameter(Position=0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ConfigurationName,

        [parameter(Position=1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    $job_id = [guid]::NewGuid().Guid
    $gcBinPath = Get-GuestConfigBinaryPath
    $dsclibPath = $(Get-DscLibPath) -replace  '[""\\]','\$&'

    if(-not ([System.Management.Automation.PSTypeName]'GuestConfig.DscOperations').Type) {
        $addTypeScript = $ExecuteDscOperationsScript -f $dsclibPath
        Add-Type -TypeDefinition $addTypeScript -ReferencedAssemblies 'System.Management.Automation','System.Console','System.Collections'
    }

    $dscOperation = [GuestConfig.DscOperations]::New()
    $result = $dscOperation.SetDscLocalConfigurationManager($PSCmdlet, $job_id, $ConfigurationName, $gcBinPath, $Path)
}
# SIG # Begin signature block
# MIIjhgYJKoZIhvcNAQcCoIIjdzCCI3MCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAAkvwUjU+YNGW
# DNatoF2ltxzi2l7hN1kht2NWZVHveaCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
# chVZQMcJAAAAAAGHMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAwMzA0MTgzOTQ3WhcNMjEwMzAzMTgzOTQ3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOt8kLc7P3T7MKIhouYHewMFmnq8Ayu7FOhZCQabVwBp2VS4WyB2Qe4TQBT8aB
# znANDEPjHKNdPT8Xz5cNali6XHefS8i/WXtF0vSsP8NEv6mBHuA2p1fw2wB/F0dH
# sJ3GfZ5c0sPJjklsiYqPw59xJ54kM91IOgiO2OUzjNAljPibjCWfH7UzQ1TPHc4d
# weils8GEIrbBRb7IWwiObL12jWT4Yh71NQgvJ9Fn6+UhD9x2uk3dLj84vwt1NuFQ
# itKJxIV0fVsRNR3abQVOLqpDugbr0SzNL6o8xzOHL5OXiGGwg6ekiXA1/2XXY7yV
# Fc39tledDtZjSjNbex1zzwSXAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhov4ZyO96axkJdMjpzu2zVXOJcsw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU4Mzg1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAixmy
# S6E6vprWD9KFNIB9G5zyMuIjZAOuUJ1EK/Vlg6Fb3ZHXjjUwATKIcXbFuFC6Wr4K
# NrU4DY/sBVqmab5AC/je3bpUpjtxpEyqUqtPc30wEg/rO9vmKmqKoLPT37svc2NV
# BmGNl+85qO4fV/w7Cx7J0Bbqk19KcRNdjt6eKoTnTPHBHlVHQIHZpMxacbFOAkJr
# qAVkYZdz7ikNXTxV+GRb36tC4ByMNxE2DF7vFdvaiZP0CVZ5ByJ2gAhXMdK9+usx
# zVk913qKde1OAuWdv+rndqkAIm8fUlRnr4saSCg7cIbUwCCf116wUJ7EuJDg0vHe
# yhnCeHnBbyH3RZkHEi2ofmfgnFISJZDdMAeVZGVOh20Jp50XBzqokpPzeZ6zc1/g
# yILNyiVgE+RPkjnUQshd1f1PMgn3tns2Cz7bJiVUaqEO3n9qRFgy5JuLae6UweGf
# AeOo3dgLZxikKzYs3hDMaEtJq8IP71cX7QXe6lnMmXU/Hdfz2p897Zd+kU+vZvKI
# 3cwLfuVQgK2RZ2z+Kc3K3dRPz2rXycK5XCuRZmvGab/WbrZiC7wJQapgBodltMI5
# GMdFrBg9IeF7/rP4EqVQXeKtevTlZXjpuNhhjuR+2DMt/dWufjXpiW91bo3aH6Ea
# jOALXmoxgltCp1K7hrS6gmsvj94cLRf50QQ4U8Qwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWzCCFVcCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgi9bEadFz
# f6GEk1eCR7lYzrqUrFsIMEnqatJaWWamazMwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCjiWySIXnWsrnyyW8kUfTx5QjUP7wQL0qBgQJWzlY5
# lE2Ub/aNXh7jDCh1/Ez7MQsVOYPF/p03FFZVKkZK9cj49PWNbZm/rhkwrkcxPfXl
# 5uhY4Y+ObqpxUBjJjJJJoheYSDun4CWX8oXTSfKgIC1VIyRz4W0HDHSxExUrEik4
# 7sZ7L0NCROKlU4p3lQU5fy1SsPeRAYEa1QyoNdcSoAwCT8c4/b+z4hODkF5yL97I
# 2qOeemWGwpeASzBxG7IoSdgcWVjxFwliRrWTJMd+4/piiIWsvNllK7fobOSNJGrr
# 1BFirpOPVzWkQkH5aI5tGw0kzYhw6Ry2PUbr9dTA/fyloYIS5TCCEuEGCisGAQQB
# gjcDAwExghLRMIISzQYJKoZIhvcNAQcCoIISvjCCEroCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMtUyIXJDvJK3QUUGpMIA+ANFotAKU/Z3fBZvDEv
# RifQAgZegg4hjXQYEzIwMjAwNDIyMjI0MTQzLjMxN1owBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQg
# SXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjJBRDQtNEI5Mi1GQTAxMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIOPDCCBPEwggPZoAMCAQICEzMAAAEIff9FWXBF+oQAAAAAAQgw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MTkxMDIzMjMxOTEzWhcNMjEwMTIxMjMxOTEzWjCByjELMAkGA1UEBhMCVVMxCzAJ
# BgNVBAgTAldBMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
# Q29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJhdGlv
# bnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MkFENC00QjkyLUZB
# MDExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC5E4jLyHDxZk05wGziyso3t6RNRL6/
# vG1sZeC01Kl5BnaWNXfUAyhr8CuThyyjwQ7YfYiZ+F+zEHh3wM2KHmwPyl4CPCUg
# ZLIXmy02+xusq9mMmh3R5N5yup6NrvDftP4HgRLOXTAy8LbrP1A573a2Jinpfa8U
# sO2iEmHBTivFrFHYN4UAdbrMI6ls9ZyMHnph6oMw5QJSDfh99u4yGDNYFa5N89kF
# 4mrcMFF3lvDmb95hn4BLi+mUa/hj7ok7gyscK+GI5J3n8XNLCNKbszHyvuIrHfVJ
# l+lqW8aRydJfrn1Pi5/lh/5GcBpeoBQAjYrPLxocpTlf1VS1/8TocGgLAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQU85RiSQuUCJR0KryRPfMVQ8K+AFQwHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEAeHkZLhdho+Jm0M2d2nfjwT/CBDO/PtS13eyvm722
# J4bqN1Kl26z+T65lxhPxBisJmSI39itM61F6U9FdmcxM9joxleIH7SeTpZMZOm+x
# 4kyF2GdywALg93RYPcdYj/91/MFsdk8/YPI8cFUPwN7P0nucgy3SvVD462WMPI76
# T8+bQMb8XsuiGYObZ0xH1SqsJntKA0SO8gREuXiLm7BZuGFCHn5mcEjy54z4j+o2
# 9nk21sKPzqhdQTDIav8WZtJTXVCkMMDfZVoUSP7ha8xzUTdfSMUAEmsgc4SJ2lN2
# bjWo1KQ1dLFB+D6PCWo+y3bcpVlfoot07xoeCNAk4DrdlTCCBnEwggRZoAMCAQIC
# CmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIx
# NDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF
# ++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRD
# DNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSx
# z5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1
# rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16Hgc
# sOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB
# 4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCB
# kjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQe
# MiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQA
# LiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUx
# vs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GAS
# inbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1
# L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWO
# M7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4
# pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45
# V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x
# 4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEe
# gPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKn
# QqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp
# 3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvT
# X4/edIhJEqGCAs4wggI3AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzELMAkG
# A1UECBMCV0ExEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9u
# cyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoyQUQ0LTRCOTItRkEw
# MTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAiOLRN/zGucSkQ6IL4N/BU+T20AyggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOJK3rwwIhgPMjAy
# MDA0MjIyMzE4MjBaGA8yMDIwMDQyMzIzMTgyMFowdzA9BgorBgEEAYRZCgQBMS8w
# LTAKAgUA4krevAIBADAKAgEAAgINRwIB/zAHAgEAAgIRyTAKAgUA4kwwPAIBADA2
# BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIB
# AAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBABovrWQZ89KpLbEDGwwhdS4ipEVQRj5r
# tMTqTpF8CC8NfJNh1ZC90QO7SKTDsR8w6Uq3DpRSac9Ok74TZNveORQ8N1cJvFP0
# gFatIVDMA/0cI7zrIb2/zIf7kaPX0qs9tV+od7VA/WofUwlp6ITDgTvpivPKmQ2N
# tOhutaeXW5YyMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAEIff9FWXBF+oQAAAAAAQgwDQYJYIZIAWUDBAIBBQCgggFKMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgTltKPxb/
# bCg0ihJcr6+XGCnZdSi3IKPwmnJE2ibq2H0wgfoGCyqGSIb3DQEJEAIvMYHqMIHn
# MIHkMIG9BCDgAzZO4EXd9UqiFVHP2IiCy0/tDAky9BuuDiapxVmDRzCBmDCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAABCH3/RVlwRfqEAAAA
# AAEIMCIEIFz9zSC+A5fRf8+1bNkfPTrbLP0GtLGAJtbVWgTAXzKDMA0GCSqGSIb3
# DQEBCwUABIIBAKHHp54wa2/9kU7SK6pkGzX31XBVv1/2aJR5lVJRgJS70kIVUCfA
# Oh6J1OJ9nBxMC/bDDmUXe5Wl7jv8JZ5aZtxZJrK8T0Dl5/8mzC3KOKVxJ/70XJ7a
# sNl8T6mwbjBmW1eZ9eUMptFOL912Whdnc7/6T/lxp8xW/8astdfzaTYGU1+RGTg7
# m51OXoseLOfRSobjh2Iip7eOYlwksPskz0tbZfG3Shl4r8iIbcRfzk1KgLA9XbZm
# LpLHlf1LRr40FuKzxLv8hRunj9CgB8my5yntyWrxjiF0WESo6jaTa2nNjZwqRlAz
# qM1r45HdJDdmXn0ijc/KtD0JTWuaDC+dp/k=
# SIG # End signature block
