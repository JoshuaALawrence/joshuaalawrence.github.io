
# Function to check and install Firefox
function CheckAndInstallFirefox {
    $firefoxPath = "C:\Program Files\Mozilla Firefox\firefox.exe"
    if (Test-Path $firefoxPath) {
        Write-Host "Firefox is already installed."
    } else {
        Write-Host "Firefox is not installed. Installing..."
        $installer = "firefox_installer.exe"
        $url = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US"
        Invoke-WebRequest -Uri $url -OutFile $installer
        Start-Process -FilePath $installer -Args "/s" -Wait
        Remove-Item $installer
    }
}

# Function to check, download, and prepare MobaXterm
function CheckAndInstallMobaXterm {
    $mobaxtermPath = "C:\Program Files (x86)\Mobatek\MobaXterm\MobaXterm.exe"
    if (Test-Path $mobaxtermPath) {
        Write-Host "MobaXterm is already installed."
    } else {
        Write-Host "MobaXterm is not installed. Downloading and preparing..."
        
        # Fetch the HTML content of the MobaXterm download page
        $response = Invoke-WebRequest -Uri "https://mobaxterm.mobatek.net/download-home-edition.html"

        # Extract the download link for the ZIP file
        $pattern = 'href="(https://download.mobatek.net/.*?Installer.*?zip)"'
        if ($response.Content -match $pattern) {
            $downloadLink = $matches[1]

            # Define the destination path for the download
            $destinationZip = "$HOME\Downloads\MobaXterm.zip"

            # Download the ZIP file
            Invoke-WebRequest -Uri $downloadLink -OutFile $destinationZip

            # Define the path where the ZIP file will be extracted
            $extractPath = "$HOME\Downloads\MobaXterm"

            # Extract the ZIP file
            Expand-Archive -LiteralPath $destinationZip -DestinationPath $extractPath -Force

            Start-Process -FilePath $(Get-ChildItem "$extractPath\" -Filter "*.msi" | Select-Object -First 1).FullName -Wait
           
            Remove-Item -FilePath $extractPath -Recurse -Force
            Remove-Item -FilePath $destinationZip -Recurse -Force
        } else {
            Write-Host "Could not find the download link on the page."
        }
    }
}

# Check and update Taskbar alignment only if needed
$taskbarAlignment = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl"
if ($taskbarAlignment.TaskbarAl -ne 0) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
    $restartExplorer = $true
}

# Check and update Theme settings only if needed
$appsUseLightTheme = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme"
$systemUsesLightTheme = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme"

if ($appsUseLightTheme.AppsUseLightTheme -ne 0 -or $systemUsesLightTheme.SystemUsesLightTheme -ne 0) {
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -Value 0
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Value 0
    $restartExplorer = $true
}

# Restart Explorer if needed
if ($restartExplorer) {
    Stop-Process -Name explorer -Force
}

# Download the Wallpaper
$wallpaperUrl = "https://joshuaalawrence.github.io/img/Wallpaper.png"
$wallpaperPath = "$env:USERPROFILE\Pictures\Wallpaper.png"
Invoke-WebRequest -Uri $wallpaperUrl -OutFile $wallpaperPath

# Set the Wallpaper
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
$SPI_SETDESKWALLPAPER = 20
$SPIF_UPDATEINIFILE = 0x1
$SPIF_SENDWININICHANGE = 0x2

[Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE) | Out-Null

# Download the Lock Screen image
$lockScreenUrl = "https://joshuaalawrence.github.io/img/Lock.png"
$lockScreenPath = "$env:USERPROFILE\Desktop\Lock.png"
Invoke-WebRequest -Uri $lockScreenUrl -OutFile $lockScreenPath

# Open the Lock Screen settings UI
Start-Process "ms-settings:lockscreen"

# Execute the functions
CheckAndInstallFirefox
CheckAndInstallMobaXterm