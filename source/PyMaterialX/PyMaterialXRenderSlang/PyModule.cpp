//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

namespace py = pybind11;

void bindPySlangProgram(py::module& mod);
void bindPySlangRenderer(py::module& mod);
void bindPySlangTextureHandler(py::module& mod);
void bindPyTextureBaker(py::module& mod);

PYBIND11_MODULE(PyMaterialXRenderSlang, mod)
{
    mod.doc() = "Rendering support for the Slang shading language.";

    // PyMaterialXRenderSlang depends on types defined in PyMaterialXRender
    PYMATERIALX_IMPORT_MODULE(PyMaterialXRender);

    bindPySlangProgram(mod);
    bindPySlangRenderer(mod);
    bindPySlangTextureHandler(mod);
    bindPyTextureBaker(mod);
}
