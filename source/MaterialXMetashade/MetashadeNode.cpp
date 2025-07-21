//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <MaterialXMetashade/MetashadeNode.h>

#include <MaterialXGenShader/Shader.h>
#include <MaterialXGenShader/ShaderNode.h>
#include <MaterialXGenShader/GenContext.h>
#include <MaterialXGenShader/ShaderStage.h>
#include <MaterialXGenShader/ShaderGenerator.h>

// pybind11 for Python integration
#include <pybind11/embed.h>
#include <pybind11/pybind11.h>

namespace py = pybind11;

MATERIALX_NAMESPACE_BEGIN

ShaderNodeImplPtr MetashadeNode::create()
{
    return ShaderNodeImplPtr(new MetashadeNode());
}

void MetashadeNode::registerImplementations(ShaderGenerator& generator)
{
    // Register MetashadeNode for specific node types
    // You can register it for multiple node categories/names as needed
    
    // Example: Register for custom Metashade nodes
    generator.registerImplementation("IM_Metashade", MetashadeNode::create);
}

MetashadeNode::MetashadeNode()
{
    // Constructor - ready for future implementation
}

void MetashadeNode::initialize(const InterfaceElement& element, GenContext& context)
{
    ShaderNodeImpl::initialize(element, context);
    
    // Set a specific hash for the purple function so it's only emitted once
    _hash = std::hash<string>{}("mx_metashade_purple");
}

void MetashadeNode::emitFunctionDefinition(const ShaderNode& node, GenContext& context, ShaderStage& stage) const
{
    const ShaderGenerator& shadergen = context.getShaderGenerator();
    
    try {
        // Ensure Python interpreter is initialized
        if (!Py_IsInitialized()) {
            py::initialize_interpreter();
        }
        
        // Import the metashade_mtlx module and call get_purple_glsl_function
        py::module_ metashade_module = py::module_::import("metashade_mtlx");
        py::object get_purple_func = metashade_module.attr("get_purple_glsl_function");
        
        // Call the Python function and get the GLSL code
        py::str glsl_code = get_purple_func();
        std::string glsl_string = glsl_code.cast<std::string>();
        
        // Emit the GLSL code returned from Python
        shadergen.emitLine(glsl_string, stage, false);
        shadergen.emitLineBreak(stage);
        
    } catch (const py::error_already_set& e) {
        // Log Python error
        std::cerr << "MetashadeNode: Python error occurred: " << e.what() << std::endl;
        throw ExceptionShaderGenError("Failed to call Python function get_purple_glsl_function: " + std::string(e.what()));
    } catch (const std::exception& e) {
        // Log general error
        std::cerr << "MetashadeNode: Exception occurred: " << e.what() << std::endl;
        throw ExceptionShaderGenError("Failed to generate shader code from Python: " + std::string(e.what()));
    }
}

void MetashadeNode::emitFunctionCall(const ShaderNode& node, GenContext& context, ShaderStage& stage) const
{
    const ShaderGenerator& shadergen = context.getShaderGenerator();
    
    // Emit the function call to get purple color
    shadergen.emitLineBegin(stage);
    shadergen.emitOutput(node.getOutput(), true, false, context, stage);
    shadergen.emitString(" = mx_metashade_purple()", stage);
    shadergen.emitLineEnd(stage);
}

MATERIALX_NAMESPACE_END
