file(GLOB_RECURSE materialx_source "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB_RECURSE materialx_headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h*")

# Add Python and pybind11 support if Python is enabled
if(MATERIALX_BUILD_PYTHON)
    # Find Python components
    find_package(Python COMPONENTS Interpreter Development REQUIRED)
    
    # Add pybind11 subdirectory if not already added
    if(NOT TARGET pybind11::headers)
        add_subdirectory(${CMAKE_SOURCE_DIR}/source/PyMaterialX/External/PyBind11 
                         ${CMAKE_BINARY_DIR}/pybind11 EXCLUDE_FROM_ALL)
    endif()
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

# Link Python and pybind11 if available
if(MATERIALX_BUILD_PYTHON AND TARGET pybind11::headers)
    target_link_libraries(MaterialXMetashade PUBLIC 
        Python::Python 
        pybind11::headers
    )
    target_include_directories(MaterialXMetashade PRIVATE 
        ${Python_INCLUDE_DIRS}
    )
endif()
