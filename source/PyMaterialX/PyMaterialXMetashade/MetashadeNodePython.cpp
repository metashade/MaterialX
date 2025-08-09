//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include "MetashadeNode.h"

#include <MaterialXGenShader/Shader.h>
#include <MaterialXGenShader/ShaderNode.h>
#include <MaterialXGenShader/GenContext.h>
#include <MaterialXGenShader/ShaderStage.h>
#include <MaterialXGenShader/ShaderGenerator.h>

// Standard library includes
#include <iostream>

// pybind11 for Python integration
#include <pybind11/embed.h>
#include <pybind11/pybind11.h>

namespace py = pybind11;

MATERIALX_NAMESPACE_BEGIN

// Python-enabled implementation that can embed a Python interpreter
class MetashadeNodePython : public MetashadeNode
{
public:
    void emitFunctionDefinition(const ShaderNode& node, GenContext& context, ShaderStage& stage) const override
    {
        // Initialize Python interpreter if not already done
        static bool pythonInitialized = false;
        if (!pythonInitialized) {
            py::initialize_interpreter();
            pythonInitialized = true;
        }

        try {
            // Import the metashade module and call the function
            py::module_ metashade_module = py::module_::import("metashade_mtlx");
            py::object get_purple_func = metashade_module.attr("get_purple_glsl_function");
            
            // Call the Python function to get GLSL code
            py::str glsl_code = get_purple_func();
            
            // Convert to C++ string and emit
            std::string cppGlslCode = glsl_code.cast<std::string>();
            stage.addString(cppGlslCode);
            
        } catch (const py::error_already_set& e) {
            std::cerr << "Python error in MetashadeNode: " << e.what() << std::endl;
            // Fallback implementation
            MetashadeNode::emitFunctionDefinition(node, context, stage);
        } catch (const std::exception& e) {
            std::cerr << "Error in MetashadeNode: " << e.what() << std::endl;
            // Fallback implementation
            MetashadeNode::emitFunctionDefinition(node, context, stage);
        }
    }
};

// Factory function that creates the Python-enabled version
ShaderNodeImplPtr MetashadeNode::createPython()
{
    return ShaderNodeImplPtr(new MetashadeNodePython());
}

MATERIALX_NAMESPACE_END
