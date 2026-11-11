
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "driver/usb_serial_jtag.h"
#include "esp_err.h"
#include "freertos/FreeRTOS.h"



enum {                                              // Declare integer that can be use in the code later. 
    HEADER_SIZE = 4,                                // XBOX data header is 20 00 XX 2C, so 4 bytes.
    PAYLOAD_SIZE = 0x2C,                            // XBOX controller send 44 bytes of data after the header
    REPORT_SIZE = HEADER_SIZE + PAYLOAD_SIZE,
};


static uint16_t read_u16_le(const uint8_t *bytes) {     // Read the header: bytes[0] and bytes[1] and reset it in order -> high bit first.  The *bytes contains the address of bytes
    return (uint16_t)(bytes[0] | (bytes[1] << 8));      // XBOX report uses le (little-endian) order -> the low bit first.
}


static int read_stick_axis(const uint8_t *bytes) {
    int value = read_u16_le(bytes);
    return value >= 0x8000 ? value - 0x10000 : value;   // means if (value >= 0x8000) { return value - 0x10000;} else {return value;}   -0x10000 because signed
}


static void print_report(const uint8_t *report)
{
    static const struct {
        const char *name;
        uint16_t mask;
    } 
    
    buttons[] = {
        {"A",      0x0010}, {"B",      0x0020},
        {"X",      0x0040}, {"Y",      0x0080},
        {"Menu",   0x0004}, {"View",   0x0008},
        {"Up",     0x0100}, {"Down",   0x0200},
        {"Left",   0x0400}, {"Right",  0x0800},
        {"LB",     0x1000}, {"RB",     0x2000},
        {"LClick", 0x4000}, {"RClick", 0x8000}
    };

    const uint16_t button_bits = read_u16_le(report + 4);

    char pressed[128] = {0};
    size_t used = 0;

    for (size_t i = 0; i < sizeof(buttons) / sizeof(buttons[0]); ++i) {
        if ((button_bits & buttons[i].mask) == 0) {
            continue;
        }

        int written = snprintf(
            pressed + used,
            sizeof(pressed) - used,
            "%s%s",
            used == 0 ? "" : ",",
            buttons[i].name
        );

        if (written < 0) {
            break;
        }

        if ((size_t)written >= sizeof(pressed) - used) {
            break;
        }

        used += (size_t)written;
    }

    printf(
        "Report=%u | LT=%u RT=%u | L=(%d,%d) R=(%d,%d) | Buttons=%s\n",
        (unsigned)report[2],
        (unsigned)read_u16_le(report + 6),
        (unsigned)read_u16_le(report + 8),
        read_stick_axis(report + 10),
        read_stick_axis(report + 12),
        read_stick_axis(report + 14),
        read_stick_axis(report + 16),
        pressed[0] != '\0' ? pressed : "none"
    );
}



// app_main 
void app_main(void)
{
    usb_serial_jtag_driver_config_t usb_config = USB_SERIAL_JTAG_DRIVER_CONFIG_DEFAULT();       // Config the usb port in a structure
    usb_config.rx_buffer_size = 1024;
    ESP_ERROR_CHECK(usb_serial_jtag_driver_install(&usb_config));                               // Create the buffer and check its status

    printf("Waiting for 48-byte XBOX reports on native USB \n");

    uint8_t input[64];                  // Init an input table with 64* 8bits
    uint8_t report[REPORT_SIZE];        // Init the report -> ESP32 result
    size_t used = 0;

    for (;;) {
        int count = usb_serial_jtag_read_bytes(input, sizeof(input), pdMS_TO_TICKS(250));   // Reads the bytes received through USB and store them in "input", returns the number of bytes

        if (count == 0) {
            used = 0; //drop an incomplete report after a pause.
            continue;
        }

        for (int i = 0; i < count; ++i) {
            report[used++] = input[i];      //used++ is a post-increment different from ++used; this line is equivalent to report[used] = input[i]; used = used + 1;

            if (used == HEADER_SIZE && (report[0] != 0x20 || report[1] != 0x00 || report[3] != PAYLOAD_SIZE)) {     // If the header is wrong we slide left to find the correct one
                memmove(report, report + 1, HEADER_SIZE - 1);                                                       // Slide the header by one byte deleting the first one 
                --used;
            }

            if (used == REPORT_SIZE) {
                print_report(report);
                used = 0;
            }
        }
    }
}