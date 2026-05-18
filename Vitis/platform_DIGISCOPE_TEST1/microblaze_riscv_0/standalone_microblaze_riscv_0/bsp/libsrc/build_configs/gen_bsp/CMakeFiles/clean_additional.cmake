# Additional clean files
cmake_minimum_required(VERSION 3.16)

if("${CONFIG}" STREQUAL "" OR "${CONFIG}" STREQUAL "")
  file(REMOVE_RECURSE
  "/home/parkdoyoung/workspace_ondevice_2/Project_DIGISCOPE/DIGISCOPE_Vitis/platform_DIGISCOPE_TEST1/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/sleep.h"
  "/home/parkdoyoung/workspace_ondevice_2/Project_DIGISCOPE/DIGISCOPE_Vitis/platform_DIGISCOPE_TEST1/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xiltimer.h"
  "/home/parkdoyoung/workspace_ondevice_2/Project_DIGISCOPE/DIGISCOPE_Vitis/platform_DIGISCOPE_TEST1/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/include/xtimer_config.h"
  "/home/parkdoyoung/workspace_ondevice_2/Project_DIGISCOPE/DIGISCOPE_Vitis/platform_DIGISCOPE_TEST1/microblaze_riscv_0/standalone_microblaze_riscv_0/bsp/lib/libxiltimer.a"
  )
endif()
