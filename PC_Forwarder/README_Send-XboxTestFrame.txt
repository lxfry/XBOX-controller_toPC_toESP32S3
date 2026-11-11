Send a test Xbox report to the ESP32-S3
=======================================

PURPOSE
-------
Send-XboxTestFrame.ps1 sends one fixed, simulated 48-byte Xbox controller
report from Windows to the ESP32-S3 over its native USB Serial/JTAG port.
It helps check the serial connection and the firmware's report decoder without
connecting an Xbox controller or running TShark or USBPcap. It does not capture
real controller input or send a continuous stream of reports.

BEFORE YOU START
----------------
- Build and flash the firmware in ESP32_Firmware. See its README.txt for
  the ESP-IDF build and flash commands.
- Connect the board's native USB port to the Windows PC with a USB data cable.
  The script is hard-coded to send to COM4. Check the port in Windows Device
  Manager and, if it differs, change $portName in Send-XboxTestFrame.ps1 to
  the native USB port assigned to your board.
- Connect the board's USB-to-UART port to the PC to see the firmware's output.
  With the current firmware configuration, open that UART port in a serial
  terminal such as PuTTY at 115200 baud. The example setup uses COM3; your
  port may differ. Close any other program using the UART port.
- Close any program using the native USB port, including
  Forward-XboxUsbReports.ps1, before running the test.

RUN THE TEST
------------
1. Open PowerShell in the XBOX-controller_toPC_toESP32S3 project root folder.
2. Run:

   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC_Forwarder\Send-XboxTestFrame.ps1"

   The execution policy option applies only to this PowerShell process.
3. The script displays the destination port, expected values, and all 48 bytes
   in hexadecimal. At the prompt, type send and press Enter to transmit once.
   Any other answer cancels the test without sending bytes.
4. Check the UART terminal for the decoded report. The script reports when
   its serial write completes, then closes the port. A completed write alone
   does not confirm that the firmware decoded the report.

TEST REPORT AND EXPECTED OUTPUT
-------------------------------
The report begins with the four-byte header 20 00 01 2C: report sequence 01
and a 44-byte payload. The remaining bytes are zero except for these values:

- A button pressed: button mask 10 00 at offsets 4-5.
- Right trigger (RT): 00 02 at offsets 8-9, or 512.
- Left stick X: 18 FC at offsets 10-11, or -1000 as a signed 16-bit value.

Offsets start at zero and multi-byte values use little-endian byte order. The
other mapped buttons, left trigger, and remaining stick axes are zero. With
the current firmware, the UART terminal should show:

   Report=1 | LT=0 RT=512 | L=(-1000,0) R=(0,0) | Buttons=A

TROUBLESHOOTING
---------------
- Port not found or access denied: verify the native USB port and the
  hard-coded $portName, and close other programs using that port.
- No decoded line: check that the firmware is flashed and running, that the
  native USB and UART connections are on the correct ports, and that the
  UART terminal is open at 115200 baud. Reset the board if needed and try again.
- Unexpected values: check that the current ESP32_Firmware firmware is
  flashed and compare the displayed report bytes with the values above.

The test sends one report only; it does not send a release report afterward.
The printed line is a diagnostic result, not a live controller state.
