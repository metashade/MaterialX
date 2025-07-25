file(GLOB_RECURSE materialx_source "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB_RECURSE materialx_headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h*")

# Add Python and pybind11 support if Python is enabled# Apply Python version and location requests from the user.
set(PYBIND11_PYTHON_VERSION ${MATERIALX_PYTHON_VERSION})
set(PYTHON_EXECUTABLE ${MATERIALX_PYTHON_EXECUTABLE})

# First look for a PyBind11 package via CMake.
if(MATERIALX_PYTHON_PYBIND11_DIR STREQUAL "")
    find_package(pybind11 QUIET)
    if(pybind11_FOUND)
        include_directories(${PYBIND11_INCLUDE_DIR})
    else()
        set(MATERIALX_PYTHON_PYBIND11_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../PyMaterialX/External/PyBind11")
    endif()
endif()

# Then look for PyBind11 at its native or user-specified location.
if(NOT pybind11_FOUND)
    add_subdirectory(${MATERIALX_PYTHON_PYBIND11_DIR})
    include_directories(${PYBIND11_INCLUDE_DIR})
endif()

if(NOT MATERIALX_PYTHON_LTO)
    set(PYBIND11_MODULE_FLAGS "NO_EXTRAS")
endif()

mx_add_library(MaterialXMetashade
    SOURCE_FILES
        ${materialx_source}
    HEADER_FILES
        ${materialx_headers}
    MTLX_MODULES
        MaterialXGenShader
        MaterialXFormat
        MaterialXCore
    EXPORT_DEFINE
        MATERIALX_METASHADE_EXPORTS)

