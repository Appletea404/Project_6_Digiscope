# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "/home/leeseokhyun/workspace_ondevice_2/Team_Project/6th_Team_Project/Vitis/platform_pwm/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/sleep.h"
  "/home/leeseokhyun/workspace_ondevice_2/Team_Project/6th_Team_Project/Vitis/platform_pwm/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xiltimer.h"
  "/home/leeseokhyun/workspace_ondevice_2/Team_Project/6th_Team_Project/Vitis/platform_pwm/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xtimer_config.h"
  "/home/leeseokhyun/workspace_ondevice_2/Team_Project/6th_Team_Project/Vitis/platform_pwm/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/lib/libxiltimer.a"
  )
endif()
