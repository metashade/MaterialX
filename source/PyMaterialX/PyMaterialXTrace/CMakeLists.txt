file(GLOB pymaterialxtrace_source "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB pymaterialxtrace_headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h")

pybind11_add_module(PyMaterialXTrace SHARED ${PYBIND11_MODULE_FLAGS} ${pymaterialxtrace_source} ${pymaterialxtrace_headers})

if(APPLE)
    set_target_properties(PyMaterialXTrace PROPERTIES CXX_VISIBILITY_PRESET "default")
endif()

set_target_properties(
    PyMaterialXTrace
    PROPERTIES
    OUTPUT_NAME PyMaterialXTrace
    COMPILE_FLAGS "${EXTERNAL_COMPILE_FLAGS}"
    LINK_FLAGS "${EXTERNAL_LINK_FLAGS}"
    INSTALL_RPATH "${MATERIALX_UP_TWO_RPATH}"
    DEBUG_POSTFIX "${MATERIALX_PYTHON_DEBUG_POSTFIX}")

target_link_libraries(
    PyMaterialXTrace
    PUBLIC MaterialXTrace
    PRIVATE ${CMAKE_DL_LIBS})

install(TARGETS PyMaterialXTrace
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}")
