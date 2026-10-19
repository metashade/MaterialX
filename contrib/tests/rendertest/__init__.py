"""Support code for the MaterialX contrib pytest suite.

- :mod:`rendertest.codegen` -- shader generation on top of ``GenContext``.
- :mod:`rendertest.scene_setup` -- camera, geometry, lighting and image
  handling for MaterialX's C++ ``ShaderRenderer`` classes.
- :mod:`rendertest.backends` -- one :class:`~rendertest.backends.Backend`
  per MaterialX shader generator, pairing it with an optional renderer.
"""
