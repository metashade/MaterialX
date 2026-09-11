file(GLOB pymaterialxrenderslang_source "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB pymaterialxrenderslang_headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h")

pybind11_add_module(PyMaterialXRenderSlang SHARED ${PYBIND11_MODULE_FLAGS} ${pymaterialxrenderslang_source} ${pymaterialxrenderslang_headers})

if(APPLE)
    set_target_properties(PyMaterialXRenderSlang PROPERTIES CXX_VISIBILITY_PRESET "default")
endif()

set_target_properties(
    PyMaterialXRenderSlang
    PROPERTIES
    OUTPUT_NAME PyMaterialXRenderSlang
    COMPILE_FLAGS "${EXTERNAL_COMPILE_FLAGS}"
    LINK_FLAGS "${EXTERNAL_LINK_FLAGS}"
    INSTALL_RPATH "${MATERIALX_UP_TWO_RPATH}"
    DEBUG_POSTFIX "${MATERIALX_PYTHON_DEBUG_POSTFIX}")

target_link_libraries(
    PyMaterialXRenderSlang
    PUBLIC PyMaterialXRender
           MaterialXRenderSlang
           MaterialXRenderHw
           PyMaterialXGenSlang
           MaterialXGenSlang
    PRIVATE ${CMAKE_DL_LIBS})

install(TARGETS PyMaterialXRenderSlang
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}")

# Install Slang runtime libraries alongside the Python module.
# Use target-based paths so the correct location is resolved on all platforms,
# since slang-rhi's imported targets may place libraries outside
# CMAKE_RUNTIME_OUTPUT_DIRECTORY on non-Windows.
install(FILES $<TARGET_FILE:slang>
    DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
    OPTIONAL)
if(WIN32)
    install(FILES
        $<TARGET_FILE_DIR:slang>/slang-compiler.dll
        $<TARGET_FILE_DIR:slang>/dxcompiler.dll
        $<TARGET_FILE_DIR:slang>/dxil.dll
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
elseif(APPLE)
    install(FILES
        $<TARGET_FILE_DIR:slang>/libslang-compiler.dylib
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
else()
    install(FILES
        $<TARGET_FILE_DIR:slang>/libslang-compiler.so
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
endif()
