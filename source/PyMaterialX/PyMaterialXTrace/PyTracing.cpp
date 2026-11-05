//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

#include <MaterialXTrace/Tracing.h>

#include <stdexcept>

namespace py = pybind11;
namespace mxt = MaterialX::Tracing;

namespace
{

// A trace event spanning a Python "with" block.
class PyScope
{
  public:
    PyScope(mxt::Category category, std::string name) :
        _category(category),
        _name(std::move(name))
    {
    }

    void enter()
    {
        mxt::Dispatcher::getInstance().beginEvent(_category, _name.c_str());
    }

    void exit()
    {
        mxt::Dispatcher::getInstance().endEvent(_category);
    }

  private:
    mxt::Category _category;
    std::string _name;
};

} // anonymous namespace

void bindPyTracing(py::module& mod)
{
    py::enum_<mxt::Category>(mod, "Category")
        .value("Render", mxt::Category::Render)
        .value("ShaderGen", mxt::Category::ShaderGen)
        .value("Optimize", mxt::Category::Optimize)
        .value("Material", mxt::Category::Material);

    py::enum_<mxt::AsyncTrack>(mod, "AsyncTrack")
        .value("GPU", mxt::AsyncTrack::GPU);

    // Counters aren't bound: PerfettoSink keeps their names by pointer,
    // which a Python string doesn't outlive.
    py::class_<mxt::Dispatcher, std::unique_ptr<mxt::Dispatcher, py::nodelete>>(mod, "Dispatcher")
        .def_static("getInstance", &mxt::Dispatcher::getInstance, py::return_value_policy::reference)
        .def("setPerfettoSink", [](mxt::Dispatcher& dispatcher, const std::string& outputPath, size_t bufferSizeKb)
            {
                if (dispatcher.isEnabled())
                {
                    throw std::runtime_error("A trace sink is already set; call shutdownSink() first");
                }
                dispatcher.setSink(mxt::createPerfettoSink(outputPath, bufferSizeKb));
            },
            py::arg("outputPath"), py::arg("bufferSizeKb") = 32768)
        .def("shutdownSink", &mxt::Dispatcher::shutdownSink)
        .def("isEnabled", &mxt::Dispatcher::isEnabled)
        .def("beginEvent", [](mxt::Dispatcher& dispatcher, mxt::Category category, const std::string& name)
            {
                dispatcher.beginEvent(category, name.c_str());
            })
        .def("endEvent", &mxt::Dispatcher::endEvent)
        .def("asyncEvent", [](mxt::Dispatcher& dispatcher, mxt::AsyncTrack track, mxt::Category category,
                              const std::string& eventName, uint64_t startNs, uint64_t durationNs)
            {
                dispatcher.asyncEvent(track, category, eventName.c_str(), startNs, durationNs);
            });

    py::class_<PyScope>(mod, "Scope")
        .def(py::init<mxt::Category, std::string>(), py::arg("category"), py::arg("name"))
        .def("__enter__", [](PyScope& scope) -> PyScope&
            {
                scope.enter();
                return scope;
            },
            py::return_value_policy::reference_internal)
        .def("__exit__", [](PyScope& scope, py::object, py::object, py::object)
            {
                scope.exit();
            });
}
