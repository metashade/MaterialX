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

if(WIN32)
    # Install slang-rhi runtime DLL dependencies to python package directory
    install(FILES
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/slang.dll
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/slang-compiler.dll
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/dxcompiler.dll
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>/dxil.dll
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
elseif(APPLE)
    install(FILES
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/libslang.dylib
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/libslang-compiler.dylib
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
else()
    install(FILES
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/libslang.so
        ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/libslang-compiler.so
        DESTINATION "${MATERIALX_PYTHON_FOLDER_NAME}"
        OPTIONAL)
endif()
