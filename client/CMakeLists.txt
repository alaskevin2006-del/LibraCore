cmake_minimum_required(VERSION 3.16)

project(client VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appclient
    src/main.cpp
)

qt_add_qml_module(appclient
    URI client
    QML_FILES
        qml/Main.qml
        qml/reader/ReaderHome.qml
        qml/admin/AdminHome.qml
        # qml/components/ 下的公共组件在此注册
    # 注意：QML 文件放在 qml/ 子目录时，与模块 URI 的映射由 DHW/HYQ 按需调整
    # （可用 set_source_files_properties(... QT_RESOURCE_ALIAS ...)，或拆成 client.reader / client.admin 子模块）
)

# 图片、图标等静态资源（放入 resources/ 后在 QML 中以 "qrc:/..." 引用）
# qt_add_resources(appclient "appclient_resources"
#     PREFIX "/"
#     FILES
#         resources/app.ico
# )

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appclient PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appclient
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appclient
    PRIVATE Qt6::Quick
)

install(TARGETS appclient
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
