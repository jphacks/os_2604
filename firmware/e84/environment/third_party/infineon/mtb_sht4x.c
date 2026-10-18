/******************************************************************************
 * \file mtb_sht4x.c
 *
 * \brief
 *     This file contains the functions for interacting with the
 *     SHT4x humidity sensor.
 *
 ******************************************************************************
 * \copyright
 * Copyright 2025 Cypress Semiconductor Corporation
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#include "cy_result.h"
#include "mtb_hal_i2c.h"
#include "mtb_sht4x.h"
#include "sensirion_i2c_hal.h"
#include "sensirion_common.h"
#include "sensirion_i2c.h"
#if defined(__cplusplus)
extern "C"
{
#endif

/******************************************************************************
* Macros
******************************************************************************/
#define SHT4X_DELAY (1000)


/******************************************************************************
* Global variables
******************************************************************************/
mtb_hal_i2c_t* sht4x_i2c = NULL;

/******************************************************************************
* Function Name: _mtb_convert_ticks_to_celsius
******************************************************************************/
int32_t _mtb_convert_ticks_to_celsius(uint16_t ticks);


/******************************************************************************
* Function Name: _mtb_convert_ticks_to_celsius
******************************************************************************/
int32_t _mtb_convert_ticks_to_percent_rh(uint16_t ticks);


/******************************************************************************
* mtb_sht4x_init
******************************************************************************/
cy_rslt_t mtb_sht4x_init(mtb_hal_i2c_t* i2c_instance,
                         mtb_sht40_address_t i2c_address)
{
    cy_rslt_t result;

    CY_ASSERT(i2c_instance != NULL);
    sht4x_init(i2c_address);

    sht4x_i2c = i2c_instance;

    sensirion_i2c_hal_sleep_usec(SHT4X_DELAY);
    result = mtb_sht4x_soft_reset(sht4x_i2c);
    sensirion_i2c_hal_sleep_usec(SHT4X_DELAY);

    return result;
}


/******************************************************************************
* mtb_sht4x_measure_high_precision
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_high_precision(mtb_hal_i2c_t* i2c_instance,
                                           int32_t* temperature,
                                           int32_t* humidity)
{
    CY_ASSERT(i2c_instance != NULL);

    sht4x_i2c = i2c_instance;

    return sht4x_measure_high_precision(temperature, humidity);
}


/******************************************************************************
* mtb_sht4x_measure_medium_precision
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_medium_precision(mtb_hal_i2c_t* i2c_instance,
                                             int32_t* temperature,
                                             int32_t* humidity)
{
    CY_ASSERT(i2c_instance != NULL);

    sht4x_i2c = i2c_instance;

    return sht4x_measure_medium_precision(temperature, humidity);
}


/******************************************************************************
* mtb_sht4x_measure_low_precision
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_low_precision(mtb_hal_i2c_t* i2c_instance,
                                          int32_t* temperature,
                                          int32_t* humidity)
{
    CY_ASSERT(i2c_instance != NULL);

    sht4x_i2c = i2c_instance;

    return sht4x_measure_lowest_precision(temperature, humidity);
}


/******************************************************************************
* mtb_sht4x_soft_reset
******************************************************************************/
cy_rslt_t mtb_sht4x_soft_reset(mtb_hal_i2c_t* i2c_instance)
{
    CY_ASSERT(i2c_instance != NULL);

    sht4x_i2c = i2c_instance;

    return sht4x_soft_reset();
}


/******************************************************************************
* mtb_sht4x_free
******************************************************************************/
void mtb_sht4x_free(mtb_hal_i2c_t* i2c_instance)
{
    CY_ASSERT(i2c_instance != NULL);

    sht4x_i2c = i2c_instance;

    sensirion_i2c_hal_free();
}


/******************************************************************************
* mtb_sht4x_measure_nonblocking
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_nonblocking(int32_t* temperature, int32_t* humidity)
{
    int16_t status = 0;
    uint8_t comm_buf[6] = { 0 };
    uint16_t rawT;
    uint16_t rawRH;

    status = sensirion_i2c_read_data_inplace(MTB_SHT40_ADDRESS_DEFAULT, comm_buf, 4);
    if (status != 0)
    {
        return status;
    }

    rawT = sensirion_common_bytes_to_uint16_t(&comm_buf[0]);
    rawRH = sensirion_common_bytes_to_uint16_t(&comm_buf[2]);

    *temperature = _mtb_convert_ticks_to_celsius(rawT);
    *humidity = _mtb_convert_ticks_to_percent_rh(rawRH);
    return CY_RSLT_SUCCESS;
}


/******************************************************************************
* mtb_sht4x_measurement_init
******************************************************************************/
void mtb_sht4x_measurement_init(uint8_t cmd)
{
    uint16_t reg_offset = 0;
    uint8_t comm_buf[6] = { 0 };

    /* Send measurement command */
    reg_offset = sensirion_i2c_add_command8_to_buffer(comm_buf, reg_offset, cmd);
    sensirion_i2c_write_data(MTB_SHT40_ADDRESS_DEFAULT, comm_buf, reg_offset);
}


/******************************************************************************
* _mtb_convert_ticks_to_celsius
******************************************************************************/
int32_t _mtb_convert_ticks_to_celsius(uint16_t ticks)
{
    return ((21875 * (int32_t)ticks) >> 13) - 45000;
}


/******************************************************************************
* _mtb_convert_ticks_to_percent_rh
******************************************************************************/
int32_t _mtb_convert_ticks_to_percent_rh(uint16_t ticks)
{
    return ((15625 * (int32_t)ticks) >> 13) - 6000;
}


#if defined(__cplusplus)
}
#endif


/* [] END OF FILE */
