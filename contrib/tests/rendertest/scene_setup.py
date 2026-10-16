"""Scene setup for MaterialX's C++ ``ShaderRenderer`` classes.

The renderer owns the camera and the geometry, light and image handlers;
these functions only configure them for the render tests.
"""
from __future__ import annotations

import math
import struct
from dataclasses import dataclass
from pathlib import Path

import MaterialX as mx
import MaterialX.PyMaterialXRender as mx_render


@dataclass(frozen=True)
class SceneOptions:
    """Inputs shared by every rendered test scene."""
    geometry_path: Path
    radiance_path: Path
    irradiance_path: Path
    env_sample_count: int
    width: int = 512
    height: int = 512

    @classmethod
    def from_repo(cls, repo_root: Path, env_sample_count: int) -> SceneOptions:
        """Sphere lit by the San Giuseppe Bridge IBL, as in MaterialXTest."""
        lights = repo_root / "resources" / "Lights"
        return cls(
            geometry_path=repo_root / "resources" / "Geometry" / "sphere.obj",
            radiance_path=lights / "san_giuseppe_bridge.hdr",
            irradiance_path=lights / "irradiance" / "san_giuseppe_bridge.hdr",
            env_sample_count=env_sample_count,
        )


def setup_raster_scene(
    renderer: mx_render.ShaderRenderer,
    image_handler: mx_render.ImageHandler,
    search_path: mx.FileSearchPath,
    options: SceneOptions,
) -> None:
    """Load geometry, fit the camera, and set up image-based lighting."""
    _load_geometry(renderer, options.geometry_path)
    _fit_camera(renderer)

    if hasattr(mx_render, "OiioImageLoader"):
        image_handler.addLoader(mx_render.OiioImageLoader.create())
    image_handler.setSearchPath(mx.FileSearchPath(search_path.asString()))
    renderer.setImageHandler(image_handler)

    light_handler = mx_render.LightHandler.create()
    light_handler.setEnvRadianceMap(
        image_handler.acquireImage(str(options.radiance_path)),
    )
    light_handler.setEnvIrradianceMap(
        image_handler.acquireImage(str(options.irradiance_path)),
    )
    light_handler.setEnvSampleCount(options.env_sample_count)
    light_handler.setRefractionTwoSided(True)
    renderer.setLightHandler(light_handler)


def _load_geometry(renderer: mx_render.ShaderRenderer, path: Path) -> None:
    geometry_handler = renderer.getGeometryHandler()
    if hasattr(mx_render, "CgltfLoader"):
        geometry_handler.addLoader(mx_render.CgltfLoader.create())
    if not geometry_handler.hasGeometry(str(path)):
        geometry_handler.loadGeometry(str(path), False)
    for mesh in geometry_handler.getMeshes():
        add_additional_test_streams(mesh)


def _fit_camera(renderer: mx_render.ShaderRenderer) -> None:
    """Frame the loaded geometry, mirroring MaterialXView's defaults."""
    eye = mx.Vector3(0.0, 0.0, 3.0)
    target = mx.Vector3(0.0, 0.0, 0.0)
    up = mx.Vector3(0.0, 1.0, 0.0)
    fov = 45.0
    near, far = 0.05, 100.0

    geometry_handler = renderer.getGeometryHandler()
    box_max = geometry_handler.getMaximumBounds()
    box_min = geometry_handler.getMinimumBounds()
    center = (box_max + box_min) * 0.5

    extent = max(box_max[i] - box_min[i] for i in range(3))
    if extent < 0.0001:
        extent = 1.0
    scale = 2.0 / extent

    rotation = mx.Matrix44.createRotationY(0)
    translation = rotation.transformPoint(center)
    for i in range(3):
        translation[i] = -translation[i]

    camera = renderer.getCamera()
    camera.setWorldMatrix(
        rotation
        * mx.Matrix44.createTranslation(translation)
        * mx.Matrix44.createScale(mx.Vector3(scale, scale, scale))
    )
    half_height = math.tan(fov / 360.0 * math.pi) * near
    half_width = half_height
    camera.setViewMatrix(mx_render.Camera.createViewMatrix(eye, target, up))
    camera.setProjectionMatrix(mx_render.Camera.createPerspectiveMatrix(
        -half_width, half_width, -half_height, half_height, near, far,
    ))
    renderer.setCamera(camera)


# ---------------------------------------------------------------------------
# Additional geometry streams
# ---------------------------------------------------------------------------

def _add_stream_if_missing(mesh, name, attr_type, index, stride, fill_func):
    if mesh.getStream(name):
        return
    stream = mx_render.MeshStream.create(name, attr_type, index)
    stream.setStride(stride)
    stream.resize(mesh.getVertexCount() * stride)
    fill_func(stream.getData())
    mesh.addStream(stream)


def add_additional_test_streams(mesh):
    """
    Add additional test streams required by MaterialX test suite.

    This is a Python equivalent of the C++ addAdditionalTestStreams() in
    RenderUtil.cpp, adding geometry attributes needed by geompropvalue,
    streams, and struct_texcoord tests. Note that the generated patterns
    may not have exact bit-for-bit parity with the C++ implementation.
    """
    n = mesh.getVertexCount()
    if n < 1:
        return

    # Get existing UV data for generating test data
    uv_stream = mesh.getStream(f"i_{mx_render.MeshStream.TEXCOORD_ATTRIBUTE}_0")
    if not uv_stream:
        return
    uv = uv_stream.getData()

    TEXCOORD = mx_render.MeshStream.TEXCOORD_ATTRIBUTE
    COLOR = mx_render.MeshStream.COLOR_ATTRIBUTE
    GEOMPROP = mx_render.MeshStream.GEOMETRY_PROPERTY_ATTRIBUTE

    # Second UV set - copy from texcoord0
    _add_stream_if_missing(mesh, f"i_{TEXCOORD}_1", TEXCOORD, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])

    # Vertex colors - RGBA from UV
    def fill_color0(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 1.0, 1.0
    _add_stream_if_missing(mesh, f"i_{COLOR}_0", COLOR, 0, 4, fill_color0)

    def fill_color1(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = 1.0-uv[i*2], 1.0-uv[i*2+1], 0.0, 1.0
    _add_stream_if_missing(mesh, f"i_{COLOR}_1", COLOR, 1, 4, fill_color1)

    # Geometry properties for geompropvalue tests
    def fill_int(d):
        for i in range(n):
            d[i] = struct.unpack('f', struct.pack('i', i % 10))[0]
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_integer", GEOMPROP, 0, 1, fill_int)

    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_float", GEOMPROP, 1, 1,
        lambda d: [d.__setitem__(i, uv[i*2]) for i in range(n)])

    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector2", GEOMPROP, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])

    def fill_vec3(d):
        for i in range(n):
            d[i*3], d[i*3+1], d[i*3+2] = uv[i*2], uv[i*2+1], 0.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector3", GEOMPROP, 1, 3, fill_vec3)

    def fill_vec4(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 0.0, 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_vector4", GEOMPROP, 1, 4, fill_vec4)

    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color2", GEOMPROP, 1, 2,
        lambda d: [d.__setitem__(i, uv[i]) for i in range(len(uv))])

    def fill_color3(d):
        for i in range(n):
            d[i*3], d[i*3+1], d[i*3+2] = uv[i*2], uv[i*2+1], 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color3", GEOMPROP, 1, 3, fill_color3)

    def fill_color4(d):
        for i in range(n):
            d[i*4], d[i*4+1], d[i*4+2], d[i*4+3] = uv[i*2], uv[i*2+1], 1.0, 1.0
    _add_stream_if_missing(mesh, f"i_{GEOMPROP}_geompropvalue_color4", GEOMPROP, 1, 4, fill_color4)
