#include "mtb_hal.h"
#include "sensirion_i2c_hal.h"
#include <assert.h>
mtb_hal_i2c_t* sht4x_i2c;
static uint32_t result;
uint32_t mtb_hal_i2c_controller_read(mtb_hal_i2c_t* i, uint8_t a, uint8_t* d, uint8_t n, uint32_t t, bool s) {
    (void)i; (void)a; (void)d; (void)n; (void)t; (void)s; return result;
}
uint32_t mtb_hal_i2c_controller_write(mtb_hal_i2c_t* i, uint8_t a, const uint8_t* d, uint8_t n, uint32_t t, bool s) {
    (void)i; (void)a; (void)d; (void)n; (void)t; (void)s; return result;
}
void mtb_hal_system_delay_us(uint32_t t) { (void)t; }
int main(void) {
    uint8_t data = 0;
    for (unsigned i = 0; i < 3; ++i) {
        result = (uint32_t[]){0, 0x100, 0x80010000}[i];
        assert((sensirion_i2c_hal_read(0x44, &data, 1) == 0) == (result == 0));
        assert((sensirion_i2c_hal_write(0x44, &data, 1) == 0) == (result == 0));
    }
    return 0;
}
