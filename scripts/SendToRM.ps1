# Echo the password to the user
$script:passwordPlainText = ""

function gracefulExit($reason) {
    if ($serialPort) {
            $serialPort.Close() > $null
    }
    if ($reason) {
        Write-Host "[APP] The script has exited. Reason: $reason"
    }
    exit
}

function login() {
    $password = Read-Host "[APP] Enter RM Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    $script:passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    Start-Sleep -Seconds 2
    $serialPort.WriteLine("root")
    $response = ""
    while ($response.ToLower() -notmatch "(password|syntax)") {
        Start-Sleep -Seconds 1
        $response += $serialPort.ReadExisting()
    }
    if ($response -notmatch "syntax") {
	    $serialPort.WriteLine($script:passwordPlainText)
	    Start-Sleep -Seconds 2
    }
}

# Get The Active COM Port
$comPort = cmd.exe /c 'reg query HKLM\HARDWARE\DEVICEMAP\SERIALCOMM' 2>$null

# Kill Putty or MobaXterm if they're active and save which one was killed.
$Used = ""
$Putty = Get-Process | Where-Object { $_.Name -like "putty" }
$Moba = Get-Process | Where-Object { $_.Name -like "mobaxterm" }

if ($Putty) {
	$Putty | Stop-Process -Force
	$Used = "Putty"
}elseif ($Moba) {
	$Moba | Stop-Process -Force
	$Used = "Moba"
}

# Get the port
if ($null -eq $comPort) {
    gracefulExit "[APP] You don't seem to be plugged into a system. Please plug into a system before running this."
}else{
    $comPort = $comPort  | Select-String "(VCP.*?COM[0-9]?[0-9])" | % {$_.matches.value} | Select-string "(COM[0-9]?[0-9])" | % {$_.matches.value} 2>$null -ErrorAction 'SilentlyContinue'
}

# Setup the serial session
$serialPort = new-object System.IO.Ports.SerialPort $comPort, 115200, None, 8, one

# If the port's in use, notify.
if ($null -eq $serialPort) {
    gracefulExit "[APP] The port is already in use. If you have putty or mobaxterm running please close them and retry."
}
try {
    $serialPort.Open()
}catch{
    gracefulExit "[APP] The port is already in use. If you have putty or mobaxterm running please close them and retry."
}
Write-Host "[APP] Continue when you have the ethernet cable plugged from your laptop to port 1 (far left) of the RM."
Write-Host "[APP] IMPORTANT: ENSURE YOU'RE NOT IN THE MIDDLE OF A 'START SERIAL SESSION -I#' SESSION WHEN RUNNING THIS."
pause

# Attempt login
login

# Get NIC 1 IP address and subnet
Write-Host "[APP] Attempting to get the IP address and Subnet now."
$serialPort.WriteLine('wcscli getnic')
Start-Sleep -Seconds 10
$output = $serialPort.ReadExisting()

# Regex to grab information
$regex = "IP Address\s+:\s+(\d{1,3}(?:\.\d{1,3}){3})\s+Subnet Mask\s+:\s+(\d{1,3}(?:\.\d{1,3}){3}).*?"
$regex2 = "Gateway Address\s+:\s+(\d{1,3}(?:\.\d{1,3}){3})"

# If the output from the RM contains the information, continue
if ($output -match $regex) {
    $ipAddress = $matches[1].toString().trim()
    $subnetMask = $matches[2].toString().trim()
    if ($output -match $regex2) {
	    $gateway = $matches[1].toString().trim()
    }else{
	    gracefulExit "[APP] I did not see the correct response from the RM. RM's Response: $output"
    }
	$serialPort.Close()
}else{
	$serialPort.Close()
    gracefulExit "[APP] I did not see the correct response from the RM. RM's Response: $output"
}

# Set the current information and ethernet index
$ethernetAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -and $_.Name -like "Ethernet*"}
$currentIndex = $ethernetAdapter.ifIndex
Set-NetIPInterface -InterfaceIndex $currentIndex -Dhcp Enabled
$currentIP = "192.168.1.5"
$currentSubnet = 24
$currentGateway = "192.168.1.1"
$num = "(\d+)$"

# If the found IP address contains digits at the last octet, increment it or decrement it
if ($ipAddress -match $num) {
	$num = $matches[0]
	if ([int]$num -ge 255) {
		$ipAddressPlusOne = ($ipAddress -replace "$num$", "") + ([int]$num.trim() - 1).toString()
	}else{
		$ipAddressPlusOne = ($ipAddress -replace "$num$", "") + ([int]$num.trim() + 1).toString()
	}
}else{
	gracefulExit "[APP] The IP I found doesn't seem correct. It doesn't contain only an IP. Send this to the developer: $($ipAddressPlusOne)"
}

# Remove the current network settings and make sure DNS exists.
Set-NetIPInterface -InterfaceIndex $currentIndex -Dhcp Disabled
Set-DnsClientServerAddress -InterfaceIndex $currentIndex -ServerAddresses ("1.1.1.1","8.8.8.8")
Remove-NetIPAddress -InterfaceIndex $currentIndex -Confirm:$false -ErrorAction 'SilentlyContinue'
Remove-NetRoute -InterfaceIndex $currentIndex -Confirm:$false -ErrorAction 'SilentlyContinue'

# Setup new network settings that match the RM
Write-Host "[NETWORK] Setting Ethernet adapter to correct settings."
New-NetIPAddress -InterfaceIndex $currentIndex -IPAddress $ipAddressPlusOne -PrefixLength ([System.Net.IPAddress]::Parse($subnetMask).GetAddressBytes() | ForEach-Object { [Convert]::ToString($_, 2) } | ForEach-Object { $_.ToCharArray() } | Where-Object { $_ -eq "1" } | Measure-Object).Count -DefaultGateway $gateway > $null

# Wait until it can see the connection before continuing.
Write-Host "[APP] Waiting to see $ipAddress before continuing."
do {
    $online = Test-Connection -ComputerName $ipAddress -Count 1 -Quiet
    Start-Sleep -Seconds 2
} while (-not $online)

# Display the information to the user to use WinSCP
Write-Host "======================================================="
Write-Host "[RM] IP: $ipAddress"
Write-Host "[RM] Subnet: $subnetMask"
Write-Host "[RM] Gateway: $gateway"
Write-Host "======================================================="

# If WinSCP exists, run it and wait otherwise let the user do it.
if (Test-Path "C:\Program Files (x86)\WinSCP\WinSCP.exe") {
    # Notify the user
    Write-Host "[APP] Found WinSCP, attempting to start it."

    # Start WinSCP
    & "C:\Program Files (x86)\WinSCP\WinSCP.exe" "sftp://root:$($script:passwordPlainText.trim())@$($ipAddress.trim())/"

    Write-Host "[APP] Running WinSCP."
    Write-Host "[APP] If WinSCP doesn't open or doesn't work do it manually with ip: $ipAddress"
    Write-Host "[APP] We will continue automatically after Winscp closes."

    # Wait for WinSCP to exit
    Start-Sleep -Seconds 10
    do {
        Start-Sleep -Seconds 1
    } while (get-process | Where-Object{$_.path -eq "C:\Program Files (x86)\WinSCP\WinSCP.exe"})
} else {
    # Notify the user
    Write-Host "[APP] We were unable to find WinScp. Please run a file transfer application."
    Write-Host "[APP] Press enter once you have files transferred."
    pause > $null
}

# Remove the new network settings
Remove-NetIPAddress -InterfaceIndex $currentIndex -Confirm:$false
Remove-NetRoute -InterfaceIndex $currentIndex -Confirm:$false -ErrorAction 'SilentlyContinue'

# Reset adapter settings back to match linux
Write-Host "[NETWORK] Resetting to Linux test adapter settings."
New-NetIPAddress -InterfaceIndex $currentIndex -IPAddress $currentIP -PrefixLength $currentSubnet -DefaultGateway $currentGateway > $null

# Boot back into your session
if ($Used -eq "Putty") {
	PuTTY.exe -serial $comPort -sercfg 115200,8,n,1,N
} elseif ($Used -eq "Moba") {
	MobaXterm.exe -newtab "Serial:$comPort,115200,8,1,n,N"
}