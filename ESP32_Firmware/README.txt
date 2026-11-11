ESP32_Firmware - Xbox Controller Report Decoder
================================================

PURPOSE
-------
This ESP-IDF firmware runs on an ESP32-S3. It receives binary Xbox controller
reports forwarded by a Windows PC, reconstructs complete reports, decodes the
buttons, triggers and joystick axes, and displays readable values in a terminal.
It is a development and debugging step for the UAV controller project.

CURRENT DATA FLOW
-----------------
Xbox controller -> Windows PC USB capture -> forwarding script -> ESP32-S3
native USB Serial/JTAG input -> report decoder -> terminal output.

In this setup, the Xbox controller is connected to the PC. The firmware does
not implement a direct USB host connection to the controller, ESP-NOW wireless
transmission, or flight-controller commands.

COMPANION PC SCRIPT
-------------------
..\PC_Forwarder\Forward-XboxUsbReports.ps1 uses TShark/USBPcap to capture
controller USB reports and forwards binary messages starting with 20 00 to COM4.
COM4 is hard-coded in the script and must match the ESP32 native USB port.
The script can also show captured frames in a PuTTY Raw TCP viewer, defaulting
to 127.0.0.1:8765. That viewer shows PC capture data, separate from ESP32 output.

REPORT FORMAT
-------------
The parser expects 48 bytes: a 4-byte header and a 44-byte payload.
The following offsets count from zero, starting at the header.

Offset   Size       Interpretation used by the firmware
0        1 byte     Must be 0x20.
1        1 byte     Must be 0x00.
2        1 byte     Displayed as Report; not validated by the parser.
3        1 byte     Must be 0x2C (44 payload bytes).
4-5      2 bytes    Button bitmask, little-endian.
6-7      2 bytes    Left trigger (LT), unsigned little-endian.
8-9      2 bytes    Right trigger (RT), unsigned little-endian.
10-11    2 bytes    Left stick X, signed 16-bit little-endian.
12-13    2 bytes    Left stick Y, signed 16-bit little-endian.
14-15    2 bytes    Right stick X, signed 16-bit little-endian.
16-17    2 bytes    Right stick Y, signed 16-bit little-endian.
18-47    30 bytes   Collected but not decoded or displayed.

Example header: 20 00 01 2C, followed by 44 payload bytes.
Little-endian means the least significant byte comes first: 0E 00 means 14.
Stick values are interpreted as -32768 to 32767. Trigger values are printed raw;
no calibration, scaling or dead zone is applied. This layout is specific to
the reports being tested and is not a universal Xbox controller report format.

BUTTON MAPPING
--------------
A=0x0010       B=0x0020        X=0x0040       Y=0x0080
Menu=0x0004    View=0x0008
Up=0x0100      Down=0x0200     Left=0x0400    Right=0x0800
LB=0x1000      RB=0x2000       LClick=0x4000  RClick=0x8000

LClick/RClick mean pressing down on the sticks. Multiple pressed buttons are
listed together. Button bits 0 and 1 are not mapped by the display function.

CODE OVERVIEW
-------------
main\main.c contains the application logic:

read_u16_le(): combines two bytes into an unsigned 16-bit value.
read_stick_axis(): interprets two bytes as a signed stick-axis value.
print_report(): decodes the fields, builds a comma-separated list of pressed
button names in a 128-byte local buffer, and prints one line per report.
Buttons=none means none of the mapped buttons are pressed.
app_main(): installs the USB Serial/JTAG driver with a 1024-byte receive
buffer, reads up to 64 bytes per call, and assembles complete 48-byte reports.

USB reads do not necessarily align with report boundaries. The parser processes
bytes one at a time. When four accumulated bytes fail the header check, memmove()
shifts the last three bytes left; the next byte forms a new candidate header.
Once 48 bytes are accumulated, print_report() runs and collection starts again.
A read returning no data after its approximately 250 ms timeout resets the
partial-report counter. It does not print a new state or reset trigger values.

Example output:
Report=42 | LT=14 RT=0 | L=(120,-85) R=(0,42) | Buttons=A,LB
Report=43 | LT=0 RT=0 | L=(120,-85) R=(0,42) | Buttons=none

BUILD AND CONSOLE
-----------------
The current sdkconfig targets esp32s3. The primary console is UART0 at
115200 baud; USB Serial/JTAG is configured as a secondary console.
CMakeLists.txt names the project esp32_controller.

From an ESP-IDF-enabled terminal in this project directory:
  idf.py build
  idf.py -p COMx flash
  idf.py -p COMy monitor

After moving or copying this project, regenerate the build directory because
CMake caches absolute paths. From the ESP-IDF terminal, run:
  idf.py fullclean
  idf.py build
Do not copy an existing build directory to a new project location.

Replace COMx/COMy with the appropriate board flash and console ports.
The UART console can be used separately from the native USB input port.
Avoid opening the same COM port in two programs simultaneously: the PC
forwarding script owns its configured COM4 connection while it runs.

TIMING AND LIMITATIONS
----------------------
Receiving and printing run in the same task. While printing, that task does
not read additional input. The USB driver can buffer incoming data, but its
storage is finite. Compact output reduces overhead without guaranteeing that
every controller update is received. PC capture and forwarding can also delay
reports; the PC viewer is handled in the same loop as serial forwarding.

If LT stays at 14 after release, compare the final captured/forwarded report
with the ESP32 output. A released value should decode from 00 00 at offsets
6-7. A missing final release report can leave an old value on the terminal;
the displayed value alone does not prove a controller fault.

The parser checks three header fields only. It has no checksum validation,
sequence-gap detection, stale-data indication or link-loss handling. After
byte loss, header-like payload bytes can produce false alignment. This is
diagnostic firmware, not a complete flight-control input system.
A future improvement is to separate reception from periodic terminal display
using a FreeRTOS task and a queue containing the latest decoded state.
