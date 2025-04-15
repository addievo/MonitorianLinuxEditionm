cmake_minimum_required(VERSION 3.14)
project(monitor-control LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(QT NAMES Qt6 Qt5 REQUIRED COMPONENTS Core Quick)
find_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core Quick)

# Source files
set(PROJECT_SOURCES
        src/main.cpp
        src/monitor.h
        src/monitor.cpp
        src/monitormanager.h
        src/monitormanager.cpp
        src/ddcutilinterface.h
        src/ddcutilinterface.cpp
        resources.qrc
)

if(${QT_VERSION_MAJOR} GREATER_EQUAL 6)
    qt_add_executable(monitor-control
            MANUAL_FINALIZATION
            ${PROJECT_SOURCES}
    )
else()
    add_executable(monitor-control
            ${PROJECT_SOURCES}
    )
endif()

target_link_libraries(monitor-control
        PRIVATE Qt${QT_VERSION_MAJOR}::Core Qt${QT_VERSION_MAJOR}::Quick)

# Finalization step for Qt 6
if(QT_VERSION_MAJOR EQUAL 6)
    qt_finalize_executable(monitor-control)
endif()