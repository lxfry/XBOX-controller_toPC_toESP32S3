# Xbox controller to PC to ESP32-S3

This project is a diagnostic step for a UAV controller. A Windows PC captures
USB reports from a wired Xbox controller and forwards them to an ESP32-S3. The
ESP-IDF firmware decodes supported reports and prints button, trigger, and
stick values to a serial terminal.

**Data flow:** Xbox controller -> Windows PC (USB capture and PowerShell
forwarder) -> ESP32-S3 native USB Serial/JTAG -> decoded serial output.

## Project folders

- [ESP32_Firmware](ESP32_Firmware/README.txt): firmware, report format,
  and ESP-IDF build and flash instructions.
- [PC_Forwarder](PC_Forwarder/): Windows PowerShell scripts for
  [forwarding controller reports](PC_Forwarder/README_Forward-XboxUsbReports.txt)
  and [sending a simulated test report](PC_Forwarder/README_Send-XboxTestFrame.txt).

To use a real controller, build and flash the firmware, then follow the
forwarding guide. The PC capture requires TShark and USBPcap. The test-report
script can check the decoder without a controller or capture software.

## Serial ports

- **COM4** is hard-coded in both PowerShell scripts as the ESP32 native USB
  port used to send reports. If Windows assigns a different port, update the
  port in each script you use. The forwarder also hard-codes `SENT COM4` in its
  viewer status message; update that label too if you change its port.
- **COM3** is configured as `idf.port` in `ESP32_Firmware/.vscode/settings.json`
  and is the example USB-to-UART port used for flashing and viewing output.
  Select your actual UART port in VS Code and your serial terminal if it differs.

Check the assigned ports in Windows Device Manager; they can differ between PCs.

This is diagnostic firmware for the report format described in the firmware
README. It does not currently provide direct USB host support, wireless
transmission, or flight-controller commands.
