"""Test backends: one per MaterialX shader generator.

A :class:`Backend` pairs a configured ``GenContext`` with an optional C++
``ShaderRenderer``.  Without a renderer it only generates shaders; with
one it also compiles (``createProgram``) and renders.

The backend ``id`` -- not the MaterialX target -- names test outputs,
since several generators share a target (``VkShaderGenerator`` and
``WgslShaderGenerator`` both report ``genglsl``).
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path

import MaterialX as mx
import MaterialX.PyMaterialXGenGlsl as mx_gen_glsl
import MaterialX.PyMaterialXGenOsl as mx_gen_osl
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render
import MaterialX.PyMaterialXRenderGlsl as mx_render_glsl

from rendertest import codegen
from rendertest.scene_setup import SceneOptions, setup_raster_scene


@dataclass
class RenderResult:
    """Result of processing a single renderable element."""
    success: bool
    material_name: str
    output_path: Path | None = None
    error: str | None = None
    shader_errors: str | None = None
    shader_dump_paths: dict = field(default_factory=dict)


class Backend:
    """A MaterialX shader generator with an optional renderer.

    Subclasses declare the generator class and file naming, and
    optionally override :meth:`_create_renderer`.
    """

    id: str
    generator_class: type
    file_extension: str
    has_vertex_stage: bool

    def __init__(
        self,
        generator: mx_gen_shader.ShaderGenerator,
        context: mx_gen_shader.GenContext,
        renderer: mx_render.ShaderRenderer | None = None,
    ):
        # GenContext doesn't keep the generator's Python object alive, and
        # once it's collected generate() silently returns None.
        self.generator = generator
        self.context = context
        self.renderer = renderer
        self._registered_search_paths: set[str] = set()

    @classmethod
    def create(
        cls,
        stdlib: mx.Document,
        search_path: mx.FileSearchPath,
        scene_options: SceneOptions | None = None,
    ) -> Backend:
        """Create a backend; pass *scene_options* to enable rendering."""
        generator = cls.generator_class.create()
        context = codegen.create_gen_context(generator, stdlib, search_path)
        renderer = None
        if scene_options is not None:
            renderer = cls._create_renderer(search_path, scene_options)
        return cls(generator, context, renderer)

    @classmethod
    def _create_renderer(
        cls, search_path: mx.FileSearchPath, scene_options: SceneOptions,
    ) -> mx_render.ShaderRenderer | None:
        return None

    @property
    def target(self) -> str:
        return self.generator.getTarget()

    def process(
        self,
        node: mx.Element,
        output_path: Path | None = None,
        search_path: mx.FileSearchPath | None = None,
        target_color_space: str = "lin_rec709",
        target_distance_unit: str = "centimeter",
    ) -> RenderResult:
        """Generate, dump, and -- if there is a renderer -- render *node*."""
        name = node.getNamePath()

        if search_path is not None:
            # GenContext appends on every call, and lookups take the first
            # match, so re-registering an identical path only grows the list.
            key = search_path.asString()
            if key not in self._registered_search_paths:
                self._registered_search_paths.add(key)
                self.context.registerSourceCodeSearchPath(search_path)
            if self.renderer is not None:
                self.renderer.getImageHandler().setSearchPath(search_path)

        if (isinstance(node, mx.Node) and node.getType() == "material"
                and not mx.getShaderNodes(node)):
            return RenderResult(
                success=False, material_name=name,
                error=f"No surface shader found in material: {name}",
            )

        shader, errors = codegen.generate_shader(
            self.context, node, target_color_space, target_distance_unit,
        )
        if not shader:
            return RenderResult(
                success=False, material_name=name, shader_errors=errors,
            )

        dump_paths = {}
        if output_path:
            dump_paths = self.dump_stages(shader, output_path, name)

        if self.renderer is None:
            return RenderResult(
                success=True, material_name=name, shader_dump_paths=dump_paths,
            )

        try:
            self.renderer.createProgram(shader)
        except LookupError as err:
            return RenderResult(
                success=False, material_name=name,
                error=f"Program creation failed: {err}",
                shader_dump_paths=dump_paths,
            )

        try:
            self.renderer.render()
        except (LookupError, mx.Exception) as err:
            return RenderResult(
                success=False, material_name=name, error=str(err),
                shader_dump_paths=dump_paths,
            )

        result = RenderResult(
            success=True, material_name=name, shader_dump_paths=dump_paths,
        )
        if output_path:
            image_path = (
                output_path / f"{mx.createValidName(name)}_{self.id}.png"
            )
            self.renderer.getImageHandler().saveImage(
                str(image_path), self.renderer.captureImage(None), True,
            )
            result.output_path = image_path
        return result

    def dump_stages(
        self, shader: mx_gen_shader.Shader, output_path: Path, name: str,
    ) -> dict:
        """Write shader source next to the test output.

        Raster backends write ``_vs`` / ``_ps`` stage files; single-stage
        backends write one file named after the element, matching
        MaterialXTest's conventions.  Returns ``{stage: path}``.
        """
        base = output_path / mx.createValidName(name)
        if self.has_vertex_stage:
            stages = [
                (mx_gen_shader.VERTEX_STAGE, f"{base}_vs"),
                (mx_gen_shader.PIXEL_STAGE, f"{base}_ps"),
            ]
        else:
            stages = [(mx_gen_shader.PIXEL_STAGE, str(base))]

        paths = {}
        for stage, stem in stages:
            try:
                source = shader.getSourceCode(stage)
            except LookupError:
                continue
            if source:
                path = Path(f"{stem}.{self.file_extension}")
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source, encoding="utf-8")
                paths[stage] = path
        return paths


class GlslBackend(Backend):
    """GLSL generation, rendered with MaterialX's OpenGL ``GlslRenderer``."""

    id = "glsl"
    generator_class = mx_gen_glsl.GlslShaderGenerator
    file_extension = "glsl"
    has_vertex_stage = True

    @classmethod
    def _create_renderer(cls, search_path, scene_options):
        renderer = mx_render_glsl.GlslRenderer.create(
            scene_options.width, scene_options.height,
            mx_render.BaseType.UINT8,
        )
        renderer.initialize()
        image_handler = mx_render_glsl.GLTextureHandler.create(
            mx_render.StbImageLoader.create(),
        )
        setup_raster_scene(renderer, image_handler, search_path, scene_options)
        return renderer


class OslBackend(Backend):
    """OSL generation only; ``OslRenderer`` support is not wired up yet."""

    id = "osl"
    generator_class = mx_gen_osl.OslShaderGenerator
    file_extension = "osl"
    has_vertex_stage = False


BACKENDS: dict[str, type[Backend]] = {
    backend.id: backend for backend in (GlslBackend, OslBackend)
}
