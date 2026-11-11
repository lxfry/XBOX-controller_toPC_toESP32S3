Forward Xbox USB reports to the ESP32
====================================

This test captures the wired Xbox controller's raw USB input reports on the
laptop, displays them in PuTTY, and forwards reports starting with 20 00
through COM4. The ESP32 decodes them and prints the result on COM3.

1. Connect the hardware

   - Plug the Xbox controller directly into the laptop with a USB data cable.
   - Red cable, COM3. Connect the ESP32's USB-to-UART port to the laptop.
     This is the flashing port and the ESP32 debug output.
   - Pink cable, COM4. Connect the ESP32's native USB port to the laptop.
     The script uses this port to send report bytes to the ESP32.
   - Use the flashed firmware with the one-line Report summary enabled.
     Printing a separate line for every button made COM3 fall behind
     during the earlier test.

2. Check the Xbox USB address

   Open Wireshark and click the gear next to USBPcap1 (or another USBPcap
   interface). Under Attached USB Devices, find Xbox Controller. If the
   entry reads [20] Xbox Controller, use 20 as the device address.
   Close the dialog without starting a capture. Check the address again
   after reconnecting the controller or moving it to another USB port.

   The script uses Wireshark's TShark and USBPcap. The default capture
   interface is \\.\USBPcap1.

3. Start PowerShell and both PuTTY sessions

   - Open PuTTY in Serial mode on COM3 at 115200 baud for the decoded
     ESP32 output. Close any ESP-IDF monitor that already holds COM3.
   - Open PowerShell in the XBOX-controller_toPC_toESP32S3 project root folder.
   - Run this single line in PowerShell. Replace 20 with the address
     shown in Wireshark.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\PC_Forwarder\Forward-XboxUsbReports.ps1" -DeviceAddress 20

   If the controller is under USBPcap2, append this to the same command:

-UsbInterface "\\.\USBPcap2"

   - Open a second PuTTY session. Select Raw, enter host 127.0.0.1 and
     port 8765, then click Open. Capture starts when this session connects.
   - The raw window marks controller payloads starting with 20 00 as
     SENT COM4 once the PC writes them. VIEW means display only. The
     COM3 window confirms what the ESP32 actually decoded.

4. Verify the trigger release

   - Press and release A to produce a few reports.
   - Squeeze LT and RT together, then slowly release both and let the
     output settle.
   - Compare the last 20 00 report in the raw window with the last
     summary on COM3. The raw report's third byte is the sequence
     number in hex. COM3 prints it in decimal. For example, 8A is 138.
   - The seventh and eighth bytes are LT. The ninth and tenth bytes
     are RT. Both should be 00 00 in the fully released report, and
     the matching COM3 line should show LT=0 RT=0.
   - If the raw report shows zero but COM3 stops at an earlier sequence
     number, the ESP32 output is still showing an earlier report.

5. Stop or troubleshoot

   - Press Ctrl+C in PowerShell to stop the capture and release COM4.
   - If COM4 is busy, close any other script or terminal using it.
   - If the raw window stays blank when you press A, check the USBPcap
     interface and device address again. If USBPcap is unavailable or
     reports a permissions error, retry from PowerShell opened as
     administrator.
