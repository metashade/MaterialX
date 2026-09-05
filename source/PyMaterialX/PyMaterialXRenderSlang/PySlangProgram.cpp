//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

#include <MaterialXRenderSlang/SlangProgram.h>

namespace py = pybind11;
namespace mx = MaterialX;

void bindPySlangProgram(py::module& mod)
{
    py::class_<mx::SlangProgram, mx::SlangProgramPtr>(mod, "SlangProgram")
        .def("setStages", &mx::SlangProgram::setStages)
        .def("addStage", &mx::SlangProgram::addStage)
        .def("getStageSourceCode", &mx::SlangProgram::getStageSourceCode)
        .def("clearStages", &mx::SlangProgram::clearStages)
        .def("getShader", &mx::SlangProgram::getShader)
        .def("build", &mx::SlangProgram::build)
        .def("hasUniform", &mx::SlangProgram::hasUniform)
        .def("bindUniform", &mx::SlangProgram::bindUniform,
            py::arg("name"), py::arg("value"), py::arg("errorIfMissing") = true)
        .def("bindMesh", static_cast<void (mx::SlangProgram::*)(mx::MeshPtr)>(&mx::SlangProgram::bindMesh))
        .def("unbindGeometry", &mx::SlangProgram::unbindGeometry)
        .def("bindTextures", &mx::SlangProgram::bindTextures)
        .def("bindLighting", &mx::SlangProgram::bindLighting)
        .def("bindViewInformation", &mx::SlangProgram::bindViewInformation)
        .def("bindTimeAndFrame", &mx::SlangProgram::bindTimeAndFrame,
            py::arg("time") = 0.0f, py::arg("frame") = 1.0f)
        .def("unbind", &mx::SlangProgram::unbind);
}
