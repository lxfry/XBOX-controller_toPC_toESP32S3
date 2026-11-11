function Send-XboxTestFrame {
    $portName = 'COM4'
    $frame = [byte[]]::new(48)

    # Report type, flags, sequence number, and payload length.
    $frame[0] = 0x20
    $frame[1] = 0x00
    $frame[2] = 0x01
    $frame[3] = 0x2C

    $frame[4] = 0x10   # A button pressed
    $frame[9] = 0x02   # RT = 512
    $frame[10] = 0x18  # Left stick X = -1000
    $frame[11] = 0xFC

    $hex = [BitConverter]::ToString($frame).Replace('-', ' ')
    Write-Host "Xbox test report for ${portName} ($($frame.Length) bytes)"
    Write-Host 'A pressed | RT = 512 | Left stick X = -1000'
    Write-Host $hex

    $answer = Read-Host 'Type send and press Enter to send this report'
    if ($answer.Trim() -ne 'send') {
        Write-Host 'Canceled. No bytes sent.'
        return
    }

    $port = [System.IO.Ports.SerialPort]::new($portName, 115200)
    $port.WriteTimeout = 2000

    try {
        $port.Open()
        Write-Host "Sending $($frame.Length) bytes to $portName..."
        $port.Write($frame, 0, $frame.Length)
        Write-Host "Wrote $($frame.Length) bytes to $portName."
    }
    finally {
        $port.Dispose()
    }
}

Send-XboxTestFrame
