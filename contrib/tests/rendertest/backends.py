"""Test backends: one per MaterialX shader generator.

A :class:`Backend` pairs a configured ``GenContext`` with an optional C++
``ShaderRenderer``.  Without a renderer it only generates shaders; with
one it also compiles (``createProgram``) and renders.

The backend ``id`` -- not the MaterialX target -- names test outputs,
since several generators share a target (``VkShaderGenerator`` and
``WgslShaderGenerator`` both report ``genglsl``).
"""
from __future__ import annotations

import atexit
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

import MaterialX as mx
import MaterialX.PyMaterialXGenGlsl as mx_gen_glsl
import MaterialX.PyMaterialXGenOsl as mx_gen_osl
import MaterialX.PyMaterialXGenShader as mx_gen_shader
import MaterialX.PyMaterialXRender as mx_render
import MaterialX.PyMaterialXRenderGlsl as mx_render_glsl
import MaterialX.PyMaterialXRenderOsl as mx_render_osl

from rendertest import codegen
from rendertest.scene_setup import SceneOptions, setup_raster_scene

_REPO_ROOT = Path(__file__).resolve().parents[3]
# Utility shaders and scene template that MaterialXTest uses with testrender.
_OSL_UTILITIES = (
    _REPO_ROOT / "source" / "MaterialXTest" / "MaterialXRenderOsl" / "Utilities"
)


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
    # OpenGL readbacks are bottom-up; images read from disk are not.
    flip_saved_image: bool = True

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
            self._prepare_program(shader, name, search_path)
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
                str(image_path), self.renderer.captureImage(None),
                self.flip_saved_image,
            )
            result.output_path = image_path
        return result

    def _prepare_program(
        self,
        shader: mx_gen_shader.Shader,
        name: str,
        search_path: mx.FileSearchPath | None,
    ) -> None:
        """Per-shader renderer setup before ``createProgram``."""

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
    """OSL generation, rendered with OSL's ``testrender`` via ``OslRenderer``.

    Rendering requires the ``OSL_ROOT`` environment variable to point at
    an OSL install containing ``bin/oslc`` and ``bin/testrender``; without
    it, this backend only generates shaders.
    """

    id = "osl"
    generator_class = mx_gen_osl.OslShaderGenerator
    file_extension = "osl"
    has_vertex_stage = False
    flip_saved_image = False

    # MaterialX type -> OSL type of the scene template's output shader input.
    _OSL_TYPES = {
        "float": "float",
        "color3": "color",
        "color4": "color4",
        "vector2": "vector2",
        "vector3": "vector",
        "vector4": "vector4",
        "surfaceshader": "closure color",
        "material": "closure color",
    }

    @classmethod
    def _create_renderer(cls, search_path, scene_options):
        osl_root = os.environ.get("OSL_ROOT")
        if not osl_root:
            return None
        osl_bin = Path(osl_root) / "bin"
        exe_suffix = ".exe" if sys.platform == "win32" else ""

        renderer = mx_render_osl.OslRenderer.create(
            scene_options.width, scene_options.height,
            mx_render.BaseType.UINT8,
        )
        renderer.setOslCompilerExecutable(str(osl_bin / f"oslc{exe_suffix}"))
        renderer.setOslTestRenderExecutable(
            str(osl_bin / f"testrender{exe_suffix}"),
        )
        renderer.setOslIncludePath(mx.FileSearchPath(
            str(_REPO_ROOT / "libraries" / "stdlib" / "genosl" / "include"),
        ))
        renderer.initialize()

        image_handler = mx_render.ImageHandler.create(
            mx_render.StbImageLoader.create(),
        )
        image_handler.setSearchPath(mx.FileSearchPath(search_path.asString()))
        renderer.setImageHandler(image_handler)
        renderer.setLightHandler(None)

        # testrender's intermediate files go to a scratch directory rather
        # than next to the committed baselines.
        work_dir = Path(tempfile.mkdtemp(prefix="mx_osl_"))
        atexit.register(shutil.rmtree, work_dir, ignore_errors=True)
        utilities = work_dir / "Utilities"
        shutil.copytree(_OSL_UTILITIES, utilities)

        # TODO: OslRenderer.setEnvShaderParameterOverrides has no Python
        # binding yet, so bake the radiance map into the defaults of the
        # utility shaders that sample it.  testrender crashes on an empty
        # environment map filename.
        for env_shader in ("envmap.osl", "raytype_background.osl"):
            path = utilities / env_shader
            path.write_text(path.read_text().replace(
                'envmap_filename = ""',
                f'envmap_filename = "{scene_options.radiance_path.as_posix()}"',
            ))

        renderer.setOslOutputFilePath(mx.FilePath(str(utilities)))
        for osl_file in sorted(utilities.glob("*.osl")):
            renderer.compileOSL(mx.FilePath(str(osl_file)))
        renderer.setOslUtilityOSOPath(mx.FilePath(str(utilities)))
        renderer.setOslTestRenderSceneTemplateFile(
            str(utilities / "scene_template.xml"),
        )
        renderer.setOslOutputFilePath(mx.FilePath(str(work_dir)))
        return renderer

    def _prepare_program(self, shader, name, search_path):
        # testrender writes <shader name>_osl.png into the output path, which
        # captureImage() then reads back.  Different materials can share a
        # shader name, so drop the image cached from an earlier render.
        self.renderer.setOslShaderName(shader.getName())
        self.renderer.getImageHandler().clearImageCache()
        self.renderer.setShaderParameterOverrides(
            self._texture_overrides(shader, search_path),
        )

        outputs = shader.getStage(mx_gen_shader.PIXEL_STAGE).getOutputBlock(
            mx_gen_osl.OSL_OUTPUTS,
        )
        if not len(outputs):
            raise LookupError(f"Shader has no output to render: {name}")
        output_port = outputs[0]

        output_type_name = output_port.getType().getName()
        if output_type_name not in self._OSL_TYPES:
            raise LookupError(
                f"Unsupported OSL output type {output_type_name}: {name}"
            )

        self.renderer.setOslShaderOutput(
            output_port.getVariable(), self._OSL_TYPES[output_type_name],
        )

    @staticmethod
    def _texture_overrides(
        shader: mx_gen_shader.Shader, search_path: mx.FileSearchPath | None,
    ) -> list[str]:
        """Absolute texture paths for testrender, as parameter overrides.

        Filenames in the generated shader stay as authored (often relative
        to the document) so the dumped baselines are portable, but
        testrender resolves them from its working directory.
        """
        if search_path is None:
            return []
        uniforms = shader.getStage(mx_gen_shader.PIXEL_STAGE).getUniformBlock(
            mx_gen_osl.OSL_UNIFORMS,
        )
        overrides = []
        for i in range(len(uniforms)):
            port = uniforms[i]
            if port.getType().getName() != "filename":
                continue
            resolved = search_path.find(mx.FilePath(port.getValueString()))
            if not resolved.exists():
                continue
            # The generator emits a filename input as a string parameter,
            # then appends "_" to the variable for the textureresource it
            # builds from that parameter.
            param = port.getVariable().removesuffix("_")
            overrides.append(
                f'string {param} "{Path(resolved.asString()).as_posix()}";\n'
            )
        return overrides


BACKENDS: dict[str, type[Backend]] = {
    backend.id: backend for backend in (GlslBackend, OslBackend)
}
