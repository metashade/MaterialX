"""
Shared render logic for pytest test suite.

This module encapsulates the per-material render logic so it can be called from
pytest test cases (parametrized tests).  All target-specific knowledge lives in
:class:`~mxrenderer.RenderBackend` subclasses; this module is backend-agnostic.
"""
import MaterialX as mx
import MaterialX.PyMaterialXGenShader as mx_gen_shader
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, List


@dataclass
class RenderResult:
    """Result of rendering a single material."""
    success: bool
    material_name: str
    output_path: Optional[Path] = None
    error: Optional[str] = None
    shader_errors: Optional[str] = None
    shader_dump_paths: dict = field(default_factory=dict)


def find_renderable_materials(doc) -> List:
    """Find all renderable elements in a document."""
    from mtlxutils import mxshadergen
    gen = mxshadergen.MtlxShaderGen(doc)
    gen.setup()
    return gen.findRenderableElements(doc)


def render_material(
    backend,
    doc,
    render_node,
    output_path: Optional[Path] = None,
    search_path=None,
    target_colorspace: str = 'lin_rec709',
    target_distance_unit: str = 'centimeter',
    no_render: bool = False,
) -> RenderResult:
    """
    Generate shaders and optionally render a single material node.

    Args:
        backend: A :class:`~mxrenderer.RenderBackend` instance.
        doc: MaterialX document containing the material.
        render_node: The renderable node to render.
        output_path: Directory for images and shader dumps.
        search_path: MaterialX search path for source code and images.
        target_colorspace: Target colorspace override.
        target_distance_unit: Target distance unit.
        no_render: Skip GPU rendering; only generate and dump shaders.

    Returns:
        RenderResult with success status and any errors.
    """
    material_name = render_node.getNamePath()
    renderer = backend.renderer

    if search_path is not None:
        generator = renderer.getCodeGenerator()
        generator.registerSourceCodeSearchPath(search_path)
        image_handler = renderer.getImageHandler()
        if image_handler is not None:
            image_handler.setSearchPath(search_path)

    if isinstance(render_node, mx.Node) and render_node.getType() == 'material':
        shader_nodes = mx.getShaderNodes(render_node)
        if not shader_nodes:
            return RenderResult(
                success=False,
                material_name=material_name,
                error=f"No surface shader found in material: {material_name}",
            )

    shader = renderer.generateShader(
        render_node, target_colorspace, target_distance_unit,
    )
    if not shader:
        return RenderResult(
            success=False,
            material_name=material_name,
            shader_errors=renderer.getActiveShaderErrors(),
        )

    shader_dump_paths = {}
    if output_path:
        shader_dump_paths = backend.dump_stages(
            shader, output_path, material_name,
        )

    if no_render or not backend.can_render:
        return RenderResult(
            success=True,
            material_name=material_name,
            shader_dump_paths=shader_dump_paths,
        )

    if not renderer.createProgram():
        return RenderResult(
            success=False,
            material_name=material_name,
            error="Failed to create GPU program",
            shader_dump_paths=shader_dump_paths,
        )

    rendered, errors = renderer.render()
    if not rendered:
        return RenderResult(
            success=False,
            material_name=material_name,
            error=str(errors),
            shader_dump_paths=shader_dump_paths,
        )

    renderer.captureImage()

    result = RenderResult(
        success=True,
        material_name=material_name,
        shader_dump_paths=shader_dump_paths,
    )

    if output_path:
        output_file = (
            output_path
            / f"{mx.createValidName(material_name)}_{backend.render_suffix}.png"
        )
        renderer.saveCapture(str(output_file), True)
        result.output_path = output_file

    return result
