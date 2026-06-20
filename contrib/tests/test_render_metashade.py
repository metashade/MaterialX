"""
Render tests for MaterialX materials with Metashade overrides.

This test file runs standard library materials against a MaterialX standard library
where Metashade implementations are loaded first, forcing them to take priority
by document insertion order.
"""
from pathlib import Path
import pytest
import MaterialX as mx
from render_test_utils import (
    get_repo_root,
    should_skip_element,
    get_element_skip_reason,
    add_additional_test_streams,
)
from test_render import find_renderable_elements, render_element


def get_schlick_test_files():
    """Get list of .mtlx files that directly or transitively test Schlick BSDF."""
    repo_root = get_repo_root()
    materials_root = repo_root / "resources" / "Materials"
    
    # Targeted files for direct / transitive Schlick BSDF testing
    targeted = [
        "TestSuite/pbrlib/bsdf/generalized_schlick.mtlx",
        "TestSuite/pbrlib/edf/generalized_schlick_edf.mtlx",
        "TestSuite/pbrlib/surfaceshader/lama/lama_generalized_schlick.mtlx",
        "TestSuite/pbrlib/bsdf/thin_film_bsdf.mtlx",
        "TestSuite/pbrlib/surfaceshader/surface_ops.mtlx",
        "Examples/StandardSurface/standard_surface_default.mtlx",
        "Examples/StandardSurface/standard_surface_gold.mtlx",
        "Examples/StandardSurface/standard_surface_plastic.mtlx",
    ]
    
    files = []
    for rel_path_str in targeted:
        mtlx_file = materials_root / rel_path_str
        if mtlx_file.exists():
            files.append(pytest.param(mtlx_file, id=rel_path_str))
            
    return files


class TestRenderMetashadeSchlickOverride:
    """
    Test rendering of standard MaterialX library materials with Metashade Schlick override.
    """
    
    @pytest.fixture(scope="class")
    def schlick_stdlib(self, search_path, repo_root):
        """Create a custom stdlib document with Metashade Schlick override loaded first."""
        lib = mx.createDocument()
        
        # 1. Load Metashade Schlick override first
        override_mtlx = repo_root / "contrib" / "tests" / "metashade_ref" / "mx_generalized_schlick_bsdf_metashade_genglsl_impl.mtlx"
        if override_mtlx.exists():
            mx.readFromXmlFile(lib, override_mtlx.as_posix())
            
        # 2. Load standard libraries second
        library_folders = mx.getDefaultDataLibraryFolders()
        mx.loadLibraries(library_folders, search_path, lib)
        return lib
        
    @pytest.fixture(scope="class")
    def schlick_renderer(self, schlick_stdlib, search_path, repo_root):
        """Create a custom renderer initialized with the overridden stdlib."""
        # IBL paths
        lights_path = repo_root / "resources" / "Lights"
        radiance_path = lights_path / "san_giuseppe_bridge.hdr"
        irradiance_path = lights_path / "irradiance" / "san_giuseppe_bridge.hdr"
        
        # Geometry
        geometry_path = repo_root / "resources" / "Geometry" / "sphere.obj"
        
        # Render size
        width = height = 512
        
        from rendertest.mtlxutils import mxrenderer
        
        renderer = mxrenderer.initializeRenderer(
            schlick_stdlib,
            search_path,
            str(radiance_path),
            str(irradiance_path),
            width,
            height,
            str(geometry_path)
        )
        
        # Add test geometry streams
        geom_handler = renderer.renderer.getGeometryHandler()
        for mesh in geom_handler.getMeshes():
            add_additional_test_streams(mesh)
            
        return renderer

    @pytest.mark.parametrize("mtlx_file", get_schlick_test_files())
    def test_render_file(
        self,
        mtlx_file: Path,
        subtests,
        schlick_renderer,
        schlick_stdlib,
        search_path,
        output_dir,
        baseline_dir,
        flip_threshold
    ):
        """Test all renderable elements in a stdlib material file using the Schlick override."""
        doc = mx.createDocument()
        mx.readFromXmlFile(doc, str(mtlx_file))
        doc.setDataLibrary(schlick_stdlib)
        
        valid, msg = doc.validate()
        assert valid, f"Document validation failed: {msg}"
        
        # Set up search path
        file_search_path = mx.FileSearchPath(search_path.asString())
        file_search_path.append(str(mtlx_file.parent.resolve()))
        
        # Test each renderable element as a subtest
        elements = find_renderable_elements(doc)
        if not elements:
            pytest.skip("No renderable elements in file")
        
        repo_root = get_repo_root()
        materials_root = repo_root / "resources" / "Materials"
        rel_path = mtlx_file.relative_to(materials_root)
        
        # Construct output directory for this material file to match MaterialXTest layout
        output_path = output_dir / "metashade_schlick" / rel_path.parent / mtlx_file.stem
        output_path.mkdir(parents=True, exist_ok=True)
        
        for elem, elem_name in elements:
            with subtests.test(msg=elem_name):
                if should_skip_element(rel_path, elem_name):
                    pytest.skip(get_element_skip_reason(rel_path, elem_name))
                
                success, error, rendered_file = render_element(
                    schlick_renderer, doc, elem, file_search_path, output_path=output_path
                )
                assert success, f"Render failed: {error}"
                
                if baseline_dir and rendered_file:
                    rel_rendered = rendered_file.relative_to(output_dir)
                    # Baselines are stored without the "metashade_schlick" prefix, compare against standard renders
                    clean_rel_path = Path(*rel_rendered.parts[1:])
                    baseline_file = baseline_dir / clean_rel_path
                    
                    # Generate heatmap in the same directory as rendered file
                    heatmap_file = rendered_file.parent / f"{rendered_file.stem}_diff.png"
                    
                    from render_test_utils import compare_rendered_image
                    res = compare_rendered_image(rendered_file, baseline_file, heatmap_path=heatmap_file)
                    if not res['success']:
                        assert False, f"Image comparison failed: {res['error']}"
                    else:
                        mean_flip = res['mean_flip']
                        max_flip = res['max_flip']
                        pct_diff = res['pct_diff_pixels']
                        
                        assert mean_flip < flip_threshold, (
                            f"Image comparison failed! Mean FLIP: {mean_flip:.4f} "
                            f"(threshold: {flip_threshold}), Max FLIP: {max_flip:.4f}, "
                            f"{pct_diff:.1f}% pixels differ. Heatmap saved to {heatmap_file.name}"
                        )
