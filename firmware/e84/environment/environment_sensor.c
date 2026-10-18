/* Project-specific SHT40 task. No sensor I/O runs in a Bluetooth callback. */
#include "environment_sensor.h"
#include "cybsp.h"
#include "mtb_hal.h"
#include "mtb_sht4x.h"
#include "FreeRTOS.h"
#include "task.h"
#include <string.h>
#include <limits.h>

uint8_t app_environment_value[20] = {1, 1};
static cy_stc_scb_i2c_context_t i2c_context;
static mtb_hal_i2c_t i2c;
static struct {
    uint32_t sequence;
    TickType_t acquired;
    int32_t temperature;
    int32_t humidity;
    uint8_t status;
} sample = {.status = 1};

static void put32(uint8_t *p, uint32_t value)
{
    for (unsigned i = 0; i < 4; ++i) p[i] = (uint8_t)(value >> (8 * i));
}

void environment_prepare_read(void)
{
    uint8_t packet[20] = {1};
    taskENTER_CRITICAL();
    packet[1] = sample.status;
    put32(packet + 2, sample.sequence);
    if (sample.status == 0) {
        uint64_t age = (uint64_t)(TickType_t)(xTaskGetTickCount() - sample.acquired) * portTICK_PERIOD_MS;
        put32(packet + 6, age > UINT32_MAX ? UINT32_MAX : (uint32_t)age);
        put32(packet + 10, (uint32_t)sample.temperature);
        put32(packet + 14, (uint32_t)sample.humidity);
    }
    taskEXIT_CRITICAL();
    /* Only the serialized Bluetooth callback writes this GATT buffer. */
    memcpy(app_environment_value, packet, sizeof packet);
}

static void sensor_task(void *unused)
{
    (void)unused;
    bool bus_ready = Cy_SCB_I2C_Init(CYBSP_I2C_CONTROLLER_HW,
        &CYBSP_I2C_CONTROLLER_config, &i2c_context) == CY_SCB_I2C_SUCCESS;
    if (bus_ready) {
        Cy_SCB_I2C_Enable(CYBSP_I2C_CONTROLLER_HW);
        bus_ready = mtb_hal_i2c_setup(&i2c, &CYBSP_I2C_CONTROLLER_hal_config,
            &i2c_context, NULL) == CY_RSLT_SUCCESS;
    }
    bool sensor_ready = false;
    for (;;) {
        uint8_t status = 2;
        int32_t temperature = 0, humidity = 0;
        if (bus_ready && !sensor_ready) {
            sensor_ready = mtb_sht4x_init(&i2c, MTB_SHT40_ADDRESS_DEFAULT) == CY_RSLT_SUCCESS;
        }
        if (sensor_ready) {
            cy_rslt_t result = mtb_sht4x_measure_high_precision(&i2c, &temperature, &humidity);
            if (result == CY_RSLT_SUCCESS) {
                status = temperature >= -40000 && temperature <= 125000 &&
                    humidity >= 0 && humidity <= 100000 ? 0 : 3;
            } else {
                sensor_ready = false; /* Reinitialize next attempt; never reuse old values. */
            }
        }
        taskENTER_CRITICAL();
        sample.sequence++;
        sample.status = status;
        sample.acquired = xTaskGetTickCount();
        sample.temperature = status == 0 ? temperature : 0;
        sample.humidity = status == 0 ? humidity : 0;
        taskEXIT_CRITICAL();
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

void environment_start(void)
{
    /* Allocation failure is represented by a sensor error; BLE still runs. */
    if (xTaskCreate(sensor_task, "sht40", 768, NULL, tskIDLE_PRIORITY + 1, NULL) != pdPASS) {
        sample.status = 2;
    }
}
