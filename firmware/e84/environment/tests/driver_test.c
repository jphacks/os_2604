#include "sht4x_i2c.h"
#include "sensirion_i2c.h"
#include "sensirion_i2c_hal.h"
#include <assert.h>
#include <string.h>
static uint8_t bytes[6];
static int8_t fail_read, fail_write;
int8_t sensirion_i2c_hal_read(uint8_t address, uint8_t *data, uint8_t count) {
    assert(address == 0x44 && count == 6);
    memcpy(data, bytes, 6); return fail_read;
}
int8_t sensirion_i2c_hal_write(uint8_t address, const uint8_t *data, uint8_t count) {
    assert(address == 0x44 && count == 1 && data[0] == 0xfd);
    return fail_write;
}
void sensirion_i2c_hal_sleep_usec(uint32_t useconds) { (void)useconds; }
void sensirion_i2c_hal_init(void) {}
void sensirion_i2c_hal_free(void) {}
int main(void) {
    sht4x_init(0x44);
    bytes[0] = 0x60; bytes[1] = 0x00;
    bytes[3] = 0x80; bytes[4] = 0x00;
    bytes[2] = sensirion_i2c_generate_crc(bytes, 2);
    bytes[5] = sensirion_i2c_generate_crc(bytes + 3, 2);
    int32_t t, h;
    assert(sht4x_measure_high_precision(&t, &h) == 0);
    assert(t == 20625 && h == 56500); /* milli C / milli %RH */
    for (unsigned index = 2; index <= 5; index += 3) {
        bytes[index] ^= 1; t = -999999; h = -999999;
        assert(sht4x_measure_high_precision(&t, &h) != 0);
        assert(t == -999999 && h == -999999); bytes[index] ^= 1;
    }
    fail_write = -1; assert(sht4x_measure_high_precision(&t, &h) != 0);
    fail_write = 0; fail_read = -1; assert(sht4x_measure_high_precision(&t, &h) != 0);
    return 0;
}
