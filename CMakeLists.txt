set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")
cmake_minimum_required(VERSION 3.20)

# Step 1: 工具链设置
set(WCH_TOOL_CHAIN 1)
if(WCH_TOOL_CHAIN)
  # http://www.mounriver.com/download
  set(TOOLPATH
      /Users/kevin/Dev_tools/WCH/xpack-riscv-none-embed-gcc-8.2.0/bin/riscv-none-embed-
  )
else()
  # https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
  set(TOOLPATH
      /Users/kevin/Dev_tools/riscv-none-elf-gcc/xpack-riscv-none-elf-gcc-12.3.0-1/bin/riscv-none-elf-
  )
endif()

if(WIN32)
  message(STATUS "Now is windows!")
  set(CMAKE_C_COMPILER ${TOOLPATH}gcc.exe)
  set(CMAKE_CXX_COMPILER ${TOOLPATH}g++.exe)
  set(CMAKE_ASM_COMPILER ${TOOLPATH}gcc.exe)
  set(CMAKE_AR ${TOOLPATH}ar.exe)
  set(CMAKE_OBJCOPY ${TOOLPATH}objcopy.exe)
  set(CMAKE_OBJDUMP ${TOOLPATH}objdump.exe)
  set(SIZE ${TOOLPATH}size.exe)
elseif(UNIX)
  message(STATUS "Now is UNIX-like OS!")
  set(CMAKE_C_COMPILER ${TOOLPATH}gcc)
  set(CMAKE_CXX_COMPILER ${TOOLPATH}g++)
  set(CMAKE_ASM_COMPILER ${TOOLPATH}gcc)
  set(CMAKE_AR ${TOOLPATH}ar)
  set(CMAKE_OBJCOPY ${TOOLPATH}objcopy)
  set(CMAKE_OBJDUMP ${TOOLPATH}objdump)
  set(SIZE ${TOOLPATH}size)
else()
  message(STATUS "Unsupported system!")
endif()

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# Step 2: 设置工程名称为"ch58x-ninja"
set(TOP_PROJECT_NAME "ch58x-ninja")
# 项目设置
project(${TOP_PROJECT_NAME} C CXX ASM)
set(CMAKE_CXX_STANDARD 11) # C++ 11
set(CMAKE_C_STANDARD 99) # C99
set(CMAKE_INSTALL_PREFIX
    "/Users/kevin/Dev_tools/WCH/WCHISPTool_CMD/macOS/bin"
    CACHE PATH "Install path prefix" FORCE)

# 编译参数 一般不用改
if(WCH_TOOL_CHAIN)
  add_compile_options(-march=rv32imac)
else()
  add_compile_options(-march=rv32imac_zicsr)
endif()

add_compile_options(-mabi=ilp32 -mcmodel=medany -msmall-data-limit=8
                    -mno-save-restore)
add_compile_options(-fmessage-length=0 -fsigned-char -ffunction-sections
                    -fdata-sections -fno-common)

# 编译警告部分 参照：https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
# 解释：https://tonybai.com/2006/03/14/explain-gcc-warning-options-by-examples/
add_compile_options(
  # -w # 禁止所有警告
  -Wall
  -Wextra # 除-Wall外其它的警告
  -Wunused # 未使用警告
  -Wfatal-errors # 出现第一个错误就停止编译
  -Wswitch-default # Switch 应该有一个默认的defalut
  # -Wcast-qual           # 被去掉cast限制警告
)

# Step 3: 设定编译类型 使用本命令查看是否包含debug符号 Linux : readelf -S Hexfile | grep debug
# MacOS : greadelf -S Hexfile | grep debug
set(CMAKE_BUILD_TYPE "Debug")
# SET(CMAKE_BUILD_TYPE "Release")

# 编译信息等级 & 编译优化等级
if(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE STREQUAL "Debug"))
  set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -ggdb -O0")
  set(CMAKE_CXX_FLAGS_DEBUG "-DDEBUG -O0 -g")
  set(CMAKE_ASM_FLAGS_DEBUG "-DDEBUG -O0 -g")
  message("Debug mode:${CMAKE_C_FLAGS_DEBUG}")
elseif(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE STREQUAL "Release"))
  set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O2")
  set(CMAKE_CXX_FLAGS_RELEASE "-DNDEBUG -Os") # -flto
  set(CMAKE_ASM_FLAGS_RELEASE "-DNDEBUG -Os")
  message("Release mode:${CMAKE_C_FLAGS_RELEASE}")
else()
  message("else:${CMAKE_BUILD_TYPE}")
  message("else:${CMAKE_C_FLAGS_RELEASE}")
endif()

# 头文件路径
include_directories(
  Dependency/BLE_LIB
  Dependency/USB_LIB
  Dependency/RVMSIS
  Dependency/StdPeriphDriver/inc
  Dependency/printf
  Dependency/HAL/include
  APP/include
  Profile/include)

# 用户宏定义
add_definitions(-DDEBUG=1)
add_definitions(-DDEBUG_BLE_MAC=1)
# 源码文件
file(
  GLOB_RECURSE
  SOURCES
  "Dependency/Startup/*.S"
  "Dependency/USB_LIB/*.c"
  "Dependency/RVMSIS/*.c"
  "Dependency/StdPeriphDriver/*.c"
  "Dependency/printf/printf.c"
  "Dependency/HAL/*.c"
  "APP/*.c"
  "Profile/*.c")

# 链接参数
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/Dependency/Ld/Link.ld)

if(WCH_TOOL_CHAIN)
  add_link_options(-march=rv32imac)
else()
  add_link_options(-march=rv32imac_zicsr)
endif()

add_link_options(
  -mabi=ilp32
  -nostartfiles
  -Xlinker
  --gc-sections
  -Wl,--print-memory-usage
  -Wl,-Map,${PROJECT_NAME}.map
  # -u _printf_float
  --specs=nano.specs
  --specs=nosys.specs)
add_link_options(-T ${LINKER_SCRIPT})

# ---------------------------- 链接标准库 ----------------------------
# 用在add_executable之前
link_libraries(m) # -lm  添加方法1

# 编译可执行文件
add_executable(${PROJECT_NAME}.elf ${SOURCES} ${LINKER_SCRIPT})

# ---------------------------- 链接私有库 ----------------------------
# 用在add_executable之后

target_link_libraries(
  ${PROJECT_NAME}.elf
  # PRIVATE m                #-lm  添加方法2
  ${CMAKE_SOURCE_DIR}/Dependency/StdPeriphDriver/libISP583.a
  ${CMAKE_SOURCE_DIR}/Dependency/BLE_LIB/LIBCH58xBLE.a
  ${CMAKE_SOURCE_DIR}/Dependency/USB_LIB/libRV3UFI.a)

set(CMAKE_INSTALL_PREFIX /Users/kevin/Dev_tools/WCH/WCHISPTool_CMD/macOS/bin)

# 设置ELF, Bin / Hex 文件路径
if(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE STREQUAL "Debug"))
  set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/build/debug) # ELF
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/build/debug)
  set(PROJECT_BINARY_DIR ${PROJECT_SOURCE_DIR}/build/debug) # Hex/build
elseif(CMAKE_BUILD_TYPE AND (CMAKE_BUILD_TYPE STREQUAL "Release"))
  set(EXECUTABLE_OUTPUT_PATH ${PROJECT_SOURCE_DIR}/build/release) # ELF
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/build/release)
  set(PROJECT_BINARY_DIR ${PROJECT_SOURCE_DIR}/build/release) # Hex/Bin
endif()

# 输出hex和bin
set(HEX_FILE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.hex)
set(BIN_FILE ${PROJECT_BINARY_DIR}/${PROJECT_NAME}.bin)
add_custom_command(
  TARGET ${PROJECT_NAME}.elf
  POST_BUILD
  COMMAND ${CMAKE_OBJCOPY} -Oihex $<TARGET_FILE:${PROJECT_NAME}.elf> ${HEX_FILE}
  COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${PROJECT_NAME}.elf>
          ${BIN_FILE})
