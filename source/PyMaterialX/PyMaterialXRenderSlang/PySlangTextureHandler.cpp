//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

#include <MaterialXRenderSlang/SlangTextureHandler.h>

namespace py = pybind11;
namespace mx = MaterialX;

void bindPySlangTextureHandler(py::module& mod)
{
    py::class_<mx::SlangTextureHandler, mx::ImageHandler, mx::SlangTextureHandlerPtr>(mod, "SlangTextureHandler")
        .def("bindImage", static_cast<bool (mx::SlangTextureHandler::*)(mx::ImagePtr, const mx::ImageSamplingProperties&)>(&mx::SlangTextureHandler::bindImage))
        .def("unbindImage", &mx::SlangTextureHandler::unbindImage)
        .def("createRenderResources", &mx::SlangTextureHandler::createRenderResources,
            py::arg("image"), py::arg("generateMipMaps") = true, py::arg("useAsRenderTarget") = false)
        .def("releaseRenderResources", &mx::SlangTextureHandler::releaseRenderResources,
            py::arg("image") = nullptr);
}
