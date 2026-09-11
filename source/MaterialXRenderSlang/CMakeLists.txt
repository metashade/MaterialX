file(GLOB materialx_source "${CMAKE_CURRENT_SOURCE_DIR}/*.cpp")
file(GLOB materialx_headers "${CMAKE_CURRENT_SOURCE_DIR}/*.h*")

mx_add_library(MaterialXRenderSlang
    SOURCE_FILES
        ${materialx_source}
    HEADER_FILES
        ${materialx_headers}
    MTLX_MODULES
        MaterialXRender
        MaterialXRenderHw
    EXPORT_DEFINE
        MATERIALX_RENDERSLANG_EXPORTS
    SKIP_INSTALL)

set(SLANG_RHI_BINARY_DIR ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/$<CONFIG>)
add_subdirectory(${MATERIALX_SLANG_RHI_SOURCE_DIR} build)
target_link_libraries(MaterialXRenderSlang PUBLIC slang-rhi)

# Install MaterialXRenderSlang without joining the MaterialX export set,
# since its public slang-rhi dependency is not export-set compatible.
if(NOT SKBUILD)
    install(TARGETS MaterialXRenderSlang
            ARCHIVE DESTINATION ${MATERIALX_INSTALL_LIB_PATH}
            LIBRARY DESTINATION ${MATERIALX_INSTALL_LIB_PATH}
            RUNTIME DESTINATION ${MATERIALX_INSTALL_BIN_PATH})
endif()
