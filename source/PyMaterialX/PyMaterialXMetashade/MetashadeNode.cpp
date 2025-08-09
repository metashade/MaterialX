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
    
    // Set a specific hash for the metashade function so it's only emitted once
    _hash = std::hash<string>{}("mx_metashade_function");
}

void MetashadeNode::emitFunctionDefinition(const ShaderNode& node, GenContext& context, ShaderStage& stage) const
{
    const ShaderGenerator& shadergen = context.getShaderGenerator();
    
    // Simple C++ implementation - emits a placeholder function
    // This can be overridden by the Python-enabled version or enhanced later
    shadergen.emitLine("vec3 mx_metashade_function()", stage, false);
    shadergen.emitScopeBegin(stage);
    shadergen.emitLine("return vec3(0.5, 0.0, 0.5); // Placeholder purple color", stage);
    shadergen.emitScopeEnd(stage);
    shadergen.emitLineBreak(stage);
}

void MetashadeNode::emitFunctionCall(const ShaderNode& node, GenContext& context, ShaderStage& stage) const
{
    const ShaderGenerator& shadergen = context.getShaderGenerator();
    
    // Emit the function call
    shadergen.emitLineBegin(stage);
    shadergen.emitOutput(node.getOutput(), true, false, context, stage);
    shadergen.emitString(" = mx_metashade_function()", stage);
    shadergen.emitLineEnd(stage);
}

MATERIALX_NAMESPACE_END
