"""Shader generation on top of MaterialX's ``GenContext``.

All generation state lives in the C++ ``GenContext`` and the
``ShaderGenerator`` it references; this module only configures them.
"""
from __future__ import annotations

import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader

DEFAULT_COLOR_SPACE = "lin_rec709"
DEFAULT_DISTANCE_UNIT = "meter"


def create_gen_context(
    generator: mx_gen_shader.ShaderGenerator,
    stdlib: mx.Document,
    search_path: mx.FileSearchPath,
) -> mx_gen_shader.GenContext:
    """Configure *generator* and return a ``GenContext`` for it.

    Color management and the unit system are attached to the generator
    itself, so each context should get its own generator instance.
    """
    target = generator.getTarget()

    cms = mx_gen_shader.DefaultColorManagementSystem.create(target)
    cms.loadLibrary(stdlib)
    generator.setColorManagementSystem(cms)

    unit_registry = mx.UnitConverterRegistry.create()
    for unit_type in ("distance", "angle"):
        type_def = stdlib.getUnitTypeDef(unit_type)
        if type_def:
            unit_registry.addUnitConverter(
                type_def, mx.LinearUnitConverter.create(type_def),
            )
    unit_system = mx_gen_shader.UnitSystem.create(target)
    unit_system.loadLibrary(stdlib)
    unit_system.setUnitConverterRegistry(unit_registry)
    generator.setUnitSystem(unit_system)

    context = mx_gen_shader.GenContext(generator)
    context.registerSourceCodeSearchPath(search_path)
    options = context.getOptions()
    options.emitColorTransforms = True
    options.fileTextureVerticalFlip = True
    return context


def generate_shader(
    context: mx_gen_shader.GenContext,
    node: mx.Element,
    target_color_space: str = DEFAULT_COLOR_SPACE,
    target_distance_unit: str = DEFAULT_DISTANCE_UNIT,
) -> tuple[mx_gen_shader.Shader | None, str]:
    """Generate a shader for *node*, returning ``(shader, errors)``.

    Per-material options (transparency, color space, distance unit) are
    set on *context* before generation.  Unsupported color spaces and
    units fall back to the defaults.
    """
    generator = context.getShaderGenerator()
    doc = node.getDocument()

    options = context.getOptions()
    options.hwMaxActiveLightSources = 0
    options.hwTransparency = mx_gen_shader.isTransparentSurface(
        node, generator.getTarget(),
    )
    options.targetDistanceUnit = _supported_distance_unit(
        doc, target_distance_unit,
    )
    options.targetColorSpaceOverride = _supported_color_space(
        doc, target_color_space,
    )

    try:
        shader = generator.generate(
            mx.createValidName(node.getName()), node, context,
        )
    except LookupError as err:
        return None, str(err)
    return shader, ""


def _supported_distance_unit(doc: mx.Document, unit: str) -> str:
    unit_defs = doc.getUnitDefs()
    if not unit_defs:
        return unit
    distance_units = {
        u.getName()
        for unit_def in unit_defs
        if unit_def.getAttribute("unittype") == "distance"
        for u in unit_def.getChildren()
    }
    return unit if unit in distance_units else DEFAULT_DISTANCE_UNIT


def _supported_color_space(doc: mx.Document, color_space: str) -> str:
    targets = set()
    for nodedef in doc.getNodeDefs():
        if nodedef.getNodeGroup() != "colortransform":
            continue
        source_to_target = nodedef.getName().removeprefix("ND_").split("_to_")
        if "color4" in source_to_target[1]:
            continue
        targets.add(source_to_target[1].removesuffix("_color3"))
    if targets and color_space not in targets:
        return DEFAULT_COLOR_SPACE
    return color_space
