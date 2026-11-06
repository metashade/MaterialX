//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

namespace py = pybind11;

void bindPyTracing(py::module& mod);

PYBIND11_MODULE(PyMaterialXTrace, mod)
{
    mod.doc() = "Performance tracing, recorded to Perfetto traces.";

    bindPyTracing(mod);
}
