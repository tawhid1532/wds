# Automated WinPE Boot Image Creation and WDS Upload for Windows Server 2025
# Run this script in an elevated PowerShell window

# Set Paths
$WinPEPath = "C:\WinPE"
$MountPath = "$WinPEPath\Mount"
$DriversPath = "$WinPEPath\Drivers"
$ISOOutput = "$WinPEPath\WinPE.iso"
$BootImageWIM = "$WinPEPath\media\sources\boot.wim"
$WDSBootImageName = "WinPE 2025 Boot Image"
$WDSBootImageDescription = "Customized WinPE Boot Image for WDS Deployment"

# Create WinPE working directory
Write-Host "Creating WinPE directory..." -ForegroundColor Cyan
if (!(Test-Path $WinPEPath)) {
    mkdir $WinPEPath
}

# Create a WinPE environment
Write-Host "Generating WinPE environment..." -ForegroundColor Cyan
copype.cmd amd64 $WinPEPath

# Mount the Boot Image
Write-Host "Mounting Boot Image..." -ForegroundColor Cyan
Dism /Mount-Image /ImageFile:$BootImageWIM /Index:1 /MountDir:$MountPath

# Add Drivers (Optional)
Write-Host "Adding drivers to Boot Image..." -ForegroundColor Cyan
if (Test-Path $DriversPath) {
    Dism /Image:$MountPath /Add-Driver /Driver:$DriversPath /Recurse
}

# Add PowerShell and Network Support
Write-Host "Adding PowerShell to Boot Image..." -ForegroundColor Cyan
$ADKPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
Dism /Image:$MountPath /Add-Package /PackagePath:"$ADKPath\WinPE-PowerShell.cab"
Dism /Image:$MountPath /Add-Package /PackagePath:"$ADKPath\WinPE-WMI.cab"
Dism /Image:$MountPath /Add-Package /PackagePath:"$ADKPath\WinPE-NetFX.cab"

# Modify startnet.cmd to Auto-run Commands
Write-Host "Modifying startup script..." -ForegroundColor Cyan
$StartNetCmd = "$MountPath\Windows\System32\startnet.cmd"
Add-Content -Path $StartNetCmd -Value "wpeinit"
Add-Content -Path $StartNetCmd -Value "cmd.exe"

# Unmount and Save Boot Image
Write-Host "Saving Boot Image..." -ForegroundColor Green
Dism /Unmount-Image /MountDir:$MountPath /Commit

# Create ISO
Write-Host "Generating WinPE ISO..." -ForegroundColor Green
MakeWinPEMedia /ISO $WinPEPath $ISOOutput

# Ask if USB should be made bootable
$usbChoice = Read-Host "Do you want to create a bootable USB drive? (Y/N)"
if ($usbChoice -eq "Y" -or $usbChoice -eq "y") {
    $USBDrive = Read-Host "Enter the USB Drive letter (e.g., E:)"
    
    Write-Host "Formatting USB Drive..." -ForegroundColor Yellow
    diskpart /s "diskpart_script.txt"
    
    # Create DiskPart Script for Formatting
    Set-Content -Path "diskpart_script.txt" -Value "select volume $USBDrive"
    Add-Content -Path "diskpart_script.txt" -Value "clean"
    Add-Content -Path "diskpart_script.txt" -Value "create partition primary"
    Add-Content -Path "diskpart_script.txt" -Value "format fs=ntfs quick"
    Add-Content -Path "diskpart_script.txt" -Value "assign"
    Add-Content -Path "diskpart_script.txt" -Value "exit"
    
    # Copy ISO Contents to USB
    Write-Host "Copying boot files to USB..." -ForegroundColor Yellow
    xcopy "$WinPEPath\media\*" "$USBDrive\" /E /H /F
    Write-Host "Bootable USB created successfully!" -ForegroundColor Green
}

# Ask if the boot image should be added to WDS
$wdsChoice = Read-Host "Do you want to add this Boot Image to Windows Deployment Services (WDS)? (Y/N)"
if ($wdsChoice -eq "Y" -or $wdsChoice -eq "y") {
    # Check if WDS is installed
    if (!(Get-Service -Name WDSServer -ErrorAction SilentlyContinue)) {
        Write-Host "WDS is not installed on this server. Exiting..." -ForegroundColor Red
        Exit
    }

    # Import Boot Image into WDS
    Write-Host "Adding Boot Image to WDS..." -ForegroundColor Cyan
    Import-WdsBootImage -Path $BootImageWIM -NewImageName $WDSBootImageName -NewDescription $WDSBootImageDescription

    Write-Host "Boot Image added to WDS successfully!" -ForegroundColor Green
}

Write-Host "Boot image creation and deployment complete!" -ForegroundColor Green

