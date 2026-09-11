//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

#include <MaterialXRenderSlang/SlangRenderer.h>

namespace py = pybind11;
namespace mx = MaterialX;

void bindPySlangRenderer(py::module& mod)
{
    py::class_<mx::SlangRenderer, mx::ShaderRenderer, mx::SlangRendererPtr>(mod, "SlangRenderer")
        .def_static("create", &mx::SlangRenderer::create,
            py::arg("width") = 512, py::arg("height") = 512, py::arg("baseType") = mx::Image::BaseType::UINT8)
        .def("initialize", &mx::SlangRenderer::initialize, py::arg("renderContextHandle") = nullptr)
        .def("createImageHandler", &mx::SlangRenderer::createImageHandler,
            py::arg("imageLoader") = nullptr)
        .def("createProgram", static_cast<void (mx::SlangRenderer::*)(const mx::ShaderPtr)>(&mx::SlangRenderer::createProgram))
        .def("createProgram", static_cast<void (mx::SlangRenderer::*)(const mx::SlangRenderer::StageMap&)>(&mx::SlangRenderer::createProgram))
        .def("validateInputs", &mx::SlangRenderer::validateInputs)
        .def("render", &mx::SlangRenderer::render)
        .def("renderTextureSpace", &mx::SlangRenderer::renderTextureSpace,
            py::arg("uvMin") = mx::Vector2(0.0f, 0.0f), py::arg("uvMax") = mx::Vector2(1.0f, 1.0f))
        .def("captureImage", &mx::SlangRenderer::captureImage,
            py::arg("image") = nullptr)
        .def("getProgram", &mx::SlangRenderer::getProgram);
}
