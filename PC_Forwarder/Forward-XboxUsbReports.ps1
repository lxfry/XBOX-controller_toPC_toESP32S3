[CmdletBinding()]
param(
    [string]$UsbInterface = '\\.\USBPcap1',

    [Parameter(Mandatory)]
    [ValidateRange(1, 127)]
    [int]$DeviceAddress,

    [ValidateRange(1024, 65535)]
    [int]$ViewerPort = 8765,

    [string]$TsharkPath = 'C:\Program Files\Wireshark\tshark.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $TsharkPath -PathType Leaf)) {
    throw "TShark was not found at $TsharkPath."
}

$serial = [System.IO.Ports.SerialPort]::new('COM4', 115200)
$serial.WriteTimeout = 2000
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $ViewerPort)
$viewer = $null
$ascii = [System.Text.Encoding]::ASCII
$filter = "usb.device_address == $DeviceAddress && usb.endpoint_address.direction == 1 && usb.transfer_type == 0x01 && usb.capdata"

try {
    $serial.Open()
    $listener.Start()
    Write-Host "Controller capture: $UsbInterface, USB device address $DeviceAddress."
    Write-Host "Open a second PuTTY session in Raw mode at 127.0.0.1 port $ViewerPort."
    Write-Host 'Capture starts when PuTTY connects. Press Ctrl+C to stop.'

    while (-not $listener.Pending()) {
        Start-Sleep -Milliseconds 100
    }

    & $TsharkPath -n -l -i $UsbInterface -Y $filter -T fields -E occurrence=f -e frame.time_relative -e usb.endpoint_address -e usb.capdata |
        ForEach-Object {
            $time, $endpoint, $payload = $_ -split '\t', 3
            $hex = $payload -replace ':', ''
            if ($hex -match '^(?:[0-9a-fA-F]{2})+$') {
                $status = 'VIEW'
                if ($hex.StartsWith('2000')) {
                    $frame = [byte[]]::new($hex.Length / 2)
                    for ($i = 0; $i -lt $frame.Length; $i++) {
                        $frame[$i] = [Convert]::ToByte($hex.Substring(2 * $i, 2), 16)
                    }
                    $serial.Write($frame, 0, $frame.Length)
                    $status = 'SENT COM4'
                }

                if ($null -eq $viewer -and $listener.Pending()) {
                    $viewer = $listener.AcceptTcpClient()
                    $viewer.NoDelay = $true
                    $viewer.SendTimeout = 250
                }
                if ($null -ne $viewer) {
                    $displayHex = ($hex.ToUpperInvariant() -replace '(..)(?=.)', '$1 ')
                    $line = '{0,-9}  {1}s  EP {2}  {3}' -f $status, $time, $endpoint, $displayHex
                    $lineBytes = $ascii.GetBytes($line + [Environment]::NewLine)
                    try {
                        $viewer.GetStream().Write($lineBytes, 0, $lineBytes.Length)
                    }
                    catch {
                        $viewer.Dispose()
                        $viewer = $null
                        Write-Host 'PuTTY disconnected. Forwarding continues. Reopen PuTTY to resume viewing.'
                    }
                }
            }
        }
    if ($LASTEXITCODE -ne 0) {
        throw "TShark exited with code $LASTEXITCODE. Check the USBPcap interface and the capture error above."
    }
}
finally {
    if ($null -ne $viewer) { $viewer.Dispose() }
    $listener.Stop()
    $serial.Dispose()
}
