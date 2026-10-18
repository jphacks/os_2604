/******************************************************************************
 * \file mtb_sht4x.h
 *
 * \brief
 *     This file is the public interface of the SHT4x humidity sensor.
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

#pragma once

#include "mtb_hal_i2c.h"
#include "sht4x_i2c.h"

#if defined(__cplusplus)
extern "C"
{
#endif

/* Commands to read sensor */
#define CMD_HIGH_PRECISION  (0xFD)
#define CMD_MED_PRECISION   (0xF6)
#define CMD_LOW_PRECISION   (0xE0)

/* Enumeration used for selecting I2C address*/
typedef enum
{
    /** Use the default addresses for the SHT40 sensors (0x44) */
    MTB_SHT40_ADDRESS_DEFAULT  = SHT40_I2C_ADDR_44,
    MTB_SHT40_ADDRESS_SEC      = SHT40_I2C_ADDR_45
} mtb_sht40_address_t;


/******************************************************************************
* Function Name: mtb_sht4x_init
*******************************************************************************
* Summary:
* This function initializes the I2C instance and configures the SHT40.
*
* Parameters:
*  i2c_instance    Pointer to an initialized I2C object
*  i2c_address     I2C address to use when communicating with the sensor
*
* Return:
*  Status of execution
*
******************************************************************************/
cy_rslt_t mtb_sht4x_init(mtb_hal_i2c_t* i2c_instance,
                         mtb_sht40_address_t i2c_address);

/******************************************************************************
* Function Name: mtb_sht4x_measure_high_precision
*******************************************************************************
* Summary:
* Single shot measurement with high precision
*
* Parameters:
*  i2c_instance        Pointer to an initialized I2C object
*  temperature         Measured temperature in milli degree celsius
*  humidity            Measured humidity in milli percent RH
*
* Return:
*  Status of execution
*
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_high_precision(mtb_hal_i2c_t* i2c_instance,
                                           int32_t* temperature,
                                           int32_t* humidity);

/******************************************************************************
* Function Name: mtb_sht4x_measure_medium_precision
*******************************************************************************
* Summary:
* Single shot measurement with medium precision
*
* Parameters:
*  i2c_instance        Pointer to an initialized I2C object
*  temperature         Measured temperature in milli degree celsius
*  humidity            Measured humidity in milli percent RH
*
* Return:
*  Status of execution
*
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_medium_precision(mtb_hal_i2c_t* i2c_instance,
                                             int32_t* temperature,
                                             int32_t* humidity);

/******************************************************************************
* Function Name: mtb_sht4x_measure_low_precision
*******************************************************************************
* Summary:
* Single shot measurement with low precision
*
* Parameters:
*  i2c_instance        Pointer to an initialized I2C object
*  temperature         Measured temperature in milli degree celsius
*  humidity            Measured humidity in milli percent RH
*
* Return:
*  Status of execution
*
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_low_precision(mtb_hal_i2c_t* i2c_instance,
                                          int32_t* temperature,
                                          int32_t* humidity);

/******************************************************************************
* Function Name: mtb_sht4x_soft_reset
*******************************************************************************
* Summary:
* Performs a soft reset
*
* Parameters:
*  i2c_instance        Pointer to an initialized I2C object
*
* Return:
*  Status of execution
*
******************************************************************************/
cy_rslt_t mtb_sht4x_soft_reset(mtb_hal_i2c_t* i2c_instance);

/******************************************************************************
* Function Name: mtb_sht4x_free
*******************************************************************************
* Summary:
* Frees up any resources allocated by mtb_sht4x_init()
*
* Parameters:
*  i2c_instance        Pointer to an initialized I2C object
*
* Return: None
*
******************************************************************************/
void mtb_sht4x_free(mtb_hal_i2c_t* i2c_instance);

/******************************************************************************
* Function Name: mtb_sht4x_measure_nonblocking
*******************************************************************************
* Summary:
* reading the sensor
*
* Parameters:
*  temperature        Pointer to temperature
*  humidity           Pointer to humidity
* Return: cy_rslt_t
*
******************************************************************************/
cy_rslt_t mtb_sht4x_measure_nonblocking(int32_t* temperature, int32_t* humidity);

/******************************************************************************
* Function Name: mtb_sht4x_measurement_init
*******************************************************************************
* Summary:
* Send the measurement initialization command based on precision
*
* Parameters:
*  cmd        Measurement initialization command based on precision
*
* Return: None
*
******************************************************************************/
void mtb_sht4x_measurement_init(uint8_t cmd);


#if defined(__cplusplus)
}
#endif


/* [] END OF FILE */
