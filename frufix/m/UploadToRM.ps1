<#
.SYNOPSIS
Automates the process of connecting to the RM via a USB serial session, configuring the network adapter, and uploading firmware.

.DESCRIPTION
This PowerShell script performs several steps to establish a connection the RM. It first prompts the user for a secure password, connects to the RM using a USB serial connection, retrieves network settings (IP address, subnet mask, gateway), and configures the local Ethernet adapter to communicate with the RM device. Additionally, it handles disabling Wi-Fi to prevent network conflicts, resetting Ethernet adapter settings, and launching WinSCP.

.KEY FEATURES
- Detects and configures active Ethernet adapters.
- Checks and manages active Wi-Fi connections to prevent conflicts.
- Establishes a serial connection to the RM device using the correct COM port.
- Logs into the RM and retrieves network settings (IP address, subnet mask, gateway).
- Configures the local Ethernet adapter to match the RM's network settings.
- Disables and enables network adapters as needed to ensure a smooth connection.
- Launches WinSCP for SFTP file transfers and waits for completion.
- Resets all network configurations to their original state after the operations are complete.

.PARAMETERS
None. The script prompts for input as needed.

.REQUIREMENTS
- Administrative privileges to modify network settings
- Serial connection via USB to the RM
- WinSCP installed at "C:\Program Files (x86)\WinSCP\WinSCP.exe" for file transfer operations

.IMPORTANT NOTES
- Ensure no other serial connections or sessions (e.g., PuTTY, MobaXterm) are active before running the script.
- Verify that the Ethernet cable is connected from your laptop to port 1 (far left) of the RM.
- Wi-Fi must be disconnected or disabled as instructed to avoid network conflicts.
#>
param(
    [String]$PASSWORD=""
)

# Function to get the active Ethernet adapter
function Get-EthernetAdapter {
    $ETHERNET_ADAPTERS = Get-NetAdapter -Physical | Where-Object {
        $_.HardwareInterface -and $_.InterfaceAlias -imatch "Ethernet"
    }
    if ($ETHERNET_ADAPTERS.Count -eq 0) {
        Write-Error "No active Ethernet adapter found."
        Initiate-GracefulExit "No active Ethernet adapter found."
    } elseif ($ETHERNET_ADAPTERS.Count -gt 1) {
        Write-Warning "Multiple Ethernet adapters found. Using the first one: $($ETHERNET_ADAPTERS[0].Name)"
    }
    $script:ETHERNET_ADAPTER = $ETHERNET_ADAPTERS[0]
    $script:ETHERNET_INDEX = $script:ETHERNET_ADAPTER.ifIndex
}

function Test-DynamicIPAddressInRangeViaARP {

    # Get the ARP table
    $arpTable = arp -a

    # Define the IP address range start and end
    $startRange = [IPAddress]::Parse("20.0.0.0")
    $endRange = [IPAddress]::Parse("29.255.255.255")

    # Function to check if an IP address is within the range
    function Test-IPInRange {
        param (
            [IPAddress]$ip
        )
        $ipBytes = $ip.GetAddressBytes()
        $startBytes = $startRange.GetAddressBytes()
        $endBytes = $endRange.GetAddressBytes()

        # Compare IP address bytes to determine if it's in range
        for ($i = 0; $i -lt $ipBytes.Length; $i++) {
            if ($ipBytes[$i] -lt $startBytes[$i] -or $ipBytes[$i] -gt $endBytes[$i]) {
                return $false
            }
        }
        return $true
    }

    # Check each line in the ARP table for IP addresses in the specified range
    foreach ($line in $arpTable) {
        if ($line -match "(\d{1,3})\.\d{1,3}\.\d{1,3}\.\d{1,3}") {
            $octetOne = $matches[1]
	    if ([int]$octetOne -eq 169) {
	       return $true
	    }
            
        }
    }

    # Return false if no IP address in the range is found
    return $false
}
# Check if the user is connected to Wi-Fi and prompt to disconnect
function Check-WiFi {
    Disable-WiFi
    return
    
    # This is if I want it optional, right now just force it
    if ($DISABLE_WIFI) {
        Disable-WiFi
    } else {
        $WIFI_ADAPTERS = Get-NetAdapter | Where-Object {
            $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Wireless|Wi-Fi'
        }
        if ($WIFI_ADAPTERS) {
            Write-Warning "You're connected to Wi-Fi. Please disconnect before continuing."
            do {
                Start-Sleep -Seconds 5
                $WIFI_ADAPTERS = Get-NetAdapter | Where-Object {
                    $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Wireless|Wi-Fi'
                }
            } while ($WIFI_ADAPTERS)
        }
    }
}

# Exit gracefully and close the serial connection
function Initiate-GracefulExit($REASON) {
    if ($script:SERIAL_CONNECTION) {
        $script:SERIAL_CONNECTION.Close() | Out-Null
    }
    if ($REASON) {
        Write-Host "The script has exited. Reason: $REASON"
    }
    exit
}

# Login to the RM via serial connection
function Login-ToRM() {
    if (-not $script:PASSWORD) {
        $SECURE_PASSWORD = Read-Host "Enter RM Password" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SECURE_PASSWORD)
        $script:PASSWORD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    Start-Sleep -Seconds 2
    $script:SERIAL_CONNECTION.WriteLine("root")
    $SERIAL_RESPONSE = ""
    $TIMEOUT = [DateTime]::Now.AddSeconds(10)

    while (([DateTime]::Now -lt $TIMEOUT) -and ($SERIAL_RESPONSE -notmatch "(password|syntax)")) {
        Start-Sleep -Milliseconds 500
        $SERIAL_RESPONSE += $script:SERIAL_CONNECTION.ReadExisting()
    }

    if ($SERIAL_RESPONSE -match "(password|syntax)") {
        if ($SERIAL_RESPONSE -notmatch "syntax") {
            $script:SERIAL_CONNECTION.WriteLine($script:PASSWORD)
            Start-Sleep -Seconds 2
        }
    } else {
        Initiate-GracefulExit "Login prompt not received from RM."
    }
}

# Stop any sessions the user has so it doesn't block the connection
function Stop-UserSessions {
    Get-Process -Name "putty", "mobaxterm" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Get the serial COM port for USB
function Get-ComPort {
    $script:ACTIVE_COM_PORT = cmd.exe /c 'reg query HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' 2>$null
    if ($null -eq $script:ACTIVE_COM_PORT) {
        Initiate-GracefulExit "You don't seem to be plugged into a system. Please plug into a system before running this."
    }else{
        $script:ACTIVE_COM_PORT = $script:ACTIVE_COM_PORT  | Select-String "(VCP.*?COM[0-9]?[0-9])" | % {$_.matches.value} | Select-string "(COM[0-9]?[0-9])" | % {$_.matches.value} 2>$null -ErrorAction 'SilentlyContinue'
    }
}

# Initialize the serial session
function Start-SerialSession {
    try {
        $script:SERIAL_CONNECTION = New-Object System.IO.Ports.SerialPort $script:ACTIVE_COM_PORT, 115200, None, 8, One
        $script:SERIAL_CONNECTION.Open()
    } catch {
        Initiate-GracefulExit "Failed to open serial port. Ensure no other applications are using it."
    }
}

# Alert the user when it starts up
function Initial-Alert {
    $ACTIVE = Test-DynamicIPAddressInRangeViaARP
    if (!$ACTIVE) {
    	Write-Host "Ensure the Ethernet cable is plugged from your laptop to port 1 (far left) of the RM."
    	Write-Host "IMPORTANT: Do not have an active serial session running when executing this script."
    	Read-Host "Press Enter to continue..."
    } else {
        Write-Host "Detected that ethernet is plugged in. Ensure you're connected to the right port however."
    }
}

# Get the network information from the node
function Get-NodeNetworking {
    Write-Host "Attempting to retrieve IP address and subnet from RM."
    $script:SERIAL_CONNECTION.DiscardInBuffer()
    $script:SERIAL_CONNECTION.WriteLine('wcscli getnic')
    Start-Sleep -Seconds 2
    $SERIAL_OUTPUT = $script:SERIAL_CONNECTION.ReadExisting()

    $IP_REGEX = 'IP Address\s*:\s*(\d{1,3}(?:\.\d{1,3}){3})'
    $SUBNET_REGEX = 'Subnet Mask\s*:\s*(\d{1,3}(?:\.\d{1,3}){3})'
    $GATEWAY_REGEX = 'Gateway Address\s*:\s*(\d{1,3}(?:\.\d{1,3}){3})'

    if ($SERIAL_OUTPUT -match $IP_REGEX) {
        $script:NODE_IP_ADDRESS = $Matches[1]
    }
    if ($SERIAL_OUTPUT -match $SUBNET_REGEX) {
        $script:NODE_SUBNET_MASK = $Matches[1]
    }
    if ($SERIAL_OUTPUT -match $GATEWAY_REGEX) {
        $script:NODE_GATEWAY = $Matches[1]
    }

    if (!$script:NODE_IP_ADDRESS -or !$script:NODE_SUBNET_MASK -or !$script:NODE_GATEWAY) {
        Initiate-GracefulExit "Failed to parse network information from RM. Response: $SERIAL_OUTPUT"
    }
    $script:SERIAL_CONNECTION.Close()
}

# Disable Wi-Fi to prevent conflicts
function Disable-WiFi {
    Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'Wireless|Wi-Fi'
    } | Disable-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue
}

# Update the Ethernet adapter to communicate with the node
function Update-LocalEthernetAdapter {
    Reset-Ethernet

    # Calculate new IP address
    $NODE_IP = [IPAddress]$script:NODE_IP_ADDRESS
    $NEW_IP = ""

    if ($NODE_IP.Address -ne 0) {
        $IP_BYTES = $NODE_IP.GetAddressBytes()
        if ($IP_BYTES[3] -lt 254) {
            $IP_BYTES[3] += 1
        } else {
            $IP_BYTES[3] -= 1
        }
        $NEW_IP = [IPAddress]::Parse(($IP_BYTES -join '.'))
    } else {
        Initiate-GracefulExit "Invalid node IP address."
    }

    # Set the adapter IP configuration
    try {
        $null = New-NetIPAddress -InterfaceIndex $script:ETHERNET_INDEX -IPAddress $NEW_IP.IPAddressToString `
            -PrefixLength ([IPAddress]::Parse($script:NODE_SUBNET_MASK).GetAddressBytes() |
            ForEach-Object { [Convert]::ToString($_,2).PadLeft(8,'0') } |
            ForEach-Object { $_.ToCharArray() } |
            Where-Object { $_ -eq '1' } | Measure-Object).Count `
            -DefaultGateway $script:NODE_GATEWAY -ErrorAction Stop
    } catch {
        Initiate-GracefulExit "Failed to set local Ethernet adapter configuration. Error: $_"
    }
}

# Display RM network settings
function Echo-RMNetworking {
    Write-Host "======================================================="
    Write-Host "RM IP Address   : $script:NODE_IP_ADDRESS"
    Write-Host "Subnet Mask     : $script:NODE_SUBNET_MASK"
    Write-Host "Gateway Address : $script:NODE_GATEWAY"
    Write-Host "======================================================="
}

# Reset Ethernet adapter to default settings
function Reset-Ethernet {
    try {
        Set-NetIPInterface -InterfaceIndex $script:ETHERNET_INDEX -Dhcp Enabled -ErrorAction Stop
        Remove-NetIPAddress -InterfaceIndex $script:ETHERNET_INDEX -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceIndex $script:ETHERNET_INDEX -Confirm:$false -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to reset Ethernet adapter. Error: $_"
    }
}

# Launch WinSCP and wait for it to close
function Launch-WinSCP {
    $WINSCP_PATH = "C:\Program Files (x86)\WinSCP\WinSCP.exe"
    if (Test-Path $WINSCP_PATH) {
        Write-Host "Launching WinSCP..."
        Start-Process -FilePath $WINSCP_PATH -ArgumentList "sftp://root:`"$($script:PASSWORD)`"@$($script:NODE_IP_ADDRESS)/" -Wait
    } else {
        Write-Warning "WinSCP not found. Please install WinSCP or use another SFTP client."
        Read-Host "Press Enter after transferring files..."
    }
}

# Wait until the node is reachable on the network
function Wait-ForSubnet {
    Write-Host "Waiting for RM to become reachable at $script:NODE_IP_ADDRESS..."
    do {
        Start-Sleep -Seconds 2
        $nodeOnline = Test-Connection -ComputerName $script:NODE_IP_ADDRESS -Count 1 -Quiet -ea SilentlyContinue
    } while (-not $nodeOnline)
}

function Enable-WiFi {
    # Find the Wi-Fi adapter(s) and enable them
    $wifiAdapters = Get-NetAdapter | Where-Object {
        $_.InterfaceDescription -match 'Wireless|Wi-Fi'
    }

    if ($wifiAdapters) {
        foreach ($adapter in $wifiAdapters) {
            # Enable the adapter if it's disabled
            if ($adapter.Status -ne 'Up') {
                Write-Host "Enabling Wi-Fi adapter: $($adapter.Name)"
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
            }
        }

        # Ensure the adapter is powered on
        Start-Sleep -Seconds 5 # Wait for a few seconds to ensure the adapter is fully enabled
        
        # Connect to the specified SSID
        $ssid = "MSFTGUEST"  # Replace with your SSID

        # Check if Wi-Fi is enabled and then connect
        try {
            netsh wlan connect name=$ssid
            Write-Host "Attempting to connect to SSID: $ssid"
        } catch {
            Write-Warning "Failed to connect to SSID: $ssid. Error: $_"
        }
    } else {
        Write-Warning "No Wi-Fi adapters found."
    }
}


# Reset Ethernet adapter to default VFDK settings
function Reset-ToLinux {
    Write-Host "Resetting Ethernet adapter to use DHCP for IP and DNS settings."
    try {
        Set-NetIPInterface -InterfaceIndex $script:ETHERNET_INDEX -Dhcp Enabled -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceIndex $script:ETHERNET_INDEX -ResetServerAddresses -ErrorAction Stop
        Write-Host "Ethernet adapter successfully reset to use DHCP for IP and DNS."
    } catch {
        Write-Warning "Failed to reset Ethernet adapter to DHCP settings. Error: $_"
    }
}


function Open-Putty {
    & "C:\Program Files\PuTTY\putty.exe" -serial $script:ACTIVE_COM_PORT -sercfg 115200,8,n,1,N
}

# Main script execution with error handling
try {
    Get-EthernetAdapter
    Initial-Alert
    Check-WiFi
    Stop-UserSessions
    Get-ComPort
    Start-SerialSession
    Login-ToRM
    Get-NodeNetworking
    Disable-WiFi
    Update-LocalEthernetAdapter
    Echo-RMNetworking
    Wait-ForSubnet
    Launch-WinSCP
    Reset-Ethernet
    Enable-WiFi
    Reset-ToLinux
    Open-Putty
} catch {
    # Log the error for debugging
    $errorMessage = @"
Error occurred:
$($_.Exception.Message)

Stack Trace:
$($_.Exception.StackTrace)
"@
    Add-Content -Path ".\error.log" -Value $errorMessage
    Initiate-GracefulExit "An unexpected error occurred. Details logged to error.log."
}
