from setuptools import setup, find_packages

setup(
    name="helioscta-backend",
    version="0.1.0",
    package_dir={"backend": "."},
    packages=["backend"] + ["backend." + p for p in find_packages(exclude=["tests*"])],
)
