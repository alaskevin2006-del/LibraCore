cmake_minimum_required(VERSION 3.16)

project(server VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Drogon REQUIRED)

# 源码自动收集：新增 controllers / services / repositories 下的 .cpp 无需改本文件
file(GLOB_RECURSE SERVER_SOURCES CONFIGURE_DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/*.cpp
)

if(NOT SERVER_SOURCES)
    message(FATAL_ERROR
        "server/src 下没有找到 .cpp 源文件。\n"
        "请先执行 drogon_ctl create project 生成入口文件，或手动创建 src/main.cpp。")
endif()

add_executable(${PROJECT_NAME} ${SERVER_SOURCES})

target_include_directories(${PROJECT_NAME}
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${PROJECT_NAME}
    PRIVATE Drogon::Drogon
)

# Drogon 运行时需要 config.json 位于工作目录：
# 从 server/config/config.example.json 复制为 config.local.json 使用（本地副本不入库）
