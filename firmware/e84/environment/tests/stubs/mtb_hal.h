#ifndef TEST_MTB_HAL_H
#define TEST_MTB_HAL_H
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#define CY_RSLT_SUCCESS 0u
typedef struct { int unused; } mtb_hal_i2c_t;
uint32_t mtb_hal_i2c_controller_read(mtb_hal_i2c_t*, uint8_t, uint8_t*, uint8_t, uint32_t, bool);
uint32_t mtb_hal_i2c_controller_write(mtb_hal_i2c_t*, uint8_t, const uint8_t*, uint8_t, uint32_t, bool);
void mtb_hal_system_delay_us(uint32_t);
#endif
