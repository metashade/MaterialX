//
// Copyright Contributors to the MaterialX Project
// SPDX-License-Identifier: Apache-2.0
//

#include <PyMaterialX/PyMaterialX.h>

#include <MaterialXRenderSlang/TextureBaker.h>
#include <MaterialXCore/Material.h>

namespace py = pybind11;
namespace mx = MaterialX;

void bindPyTextureBaker(py::module& mod)
{
    py::class_<mx::TextureBakerSlang, mx::SlangRenderer, mx::TextureBakerSlangPtr>(mod, "TextureBaker")
        .def_static("create", &mx::TextureBakerSlang::create)
        .def("setExtension", &mx::TextureBakerSlang::setExtension)
        .def("getExtension", &mx::TextureBakerSlang::getExtension)
        .def("setColorSpace", &mx::TextureBakerSlang::setColorSpace)
        .def("getColorSpace", &mx::TextureBakerSlang::getColorSpace)
        .def("setDistanceUnit", &mx::TextureBakerSlang::setDistanceUnit)
        .def("getDistanceUnit", &mx::TextureBakerSlang::getDistanceUnit)
        .def("setAverageImages", &mx::TextureBakerSlang::setAverageImages)
        .def("getAverageImages", &mx::TextureBakerSlang::getAverageImages)
        .def("setOptimizeConstants", &mx::TextureBakerSlang::setOptimizeConstants)
        .def("getOptimizeConstants", &mx::TextureBakerSlang::getOptimizeConstants)
        .def("setOutputImagePath", &mx::TextureBakerSlang::setOutputImagePath)
        .def("getOutputImagePath", &mx::TextureBakerSlang::getOutputImagePath)
        .def("setBakedGraphName", &mx::TextureBakerSlang::setBakedGraphName)
        .def("getBakedGraphName", &mx::TextureBakerSlang::getBakedGraphName)
        .def("setBakedGeomInfoName", &mx::TextureBakerSlang::setBakedGeomInfoName)
        .def("getBakedGeomInfoName", &mx::TextureBakerSlang::getBakedGeomInfoName)
        .def("setTextureFilenameTemplate", &mx::TextureBakerSlang::setTextureFilenameTemplate)
        .def("getTextureFilenameTemplate", &mx::TextureBakerSlang::getTextureFilenameTemplate)
        .def("setFilenameTemplateVarOverride", &mx::TextureBakerSlang::setFilenameTemplateVarOverride)
        .def("setHashImageNames", &mx::TextureBakerSlang::setHashImageNames)
        .def("getHashImageNames", &mx::TextureBakerSlang::getHashImageNames)
        .def("setTextureSpaceMin", &mx::TextureBakerSlang::setTextureSpaceMin)
        .def("getTextureSpaceMin", &mx::TextureBakerSlang::getTextureSpaceMin)
        .def("setTextureSpaceMax", &mx::TextureBakerSlang::setTextureSpaceMax)
        .def("getTextureSpaceMax", &mx::TextureBakerSlang::getTextureSpaceMax)
        .def("setupUnitSystem", &mx::TextureBakerSlang::setupUnitSystem)
        .def("bakeMaterialToDoc", &mx::TextureBakerSlang::bakeMaterialToDoc)
        .def("bakeAllMaterials", &mx::TextureBakerSlang::bakeAllMaterials)
        .def("writeDocumentPerMaterial", &mx::TextureBakerSlang::writeDocumentPerMaterial);
}
