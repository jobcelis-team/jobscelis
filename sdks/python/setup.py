from setuptools import setup, find_packages
import os

here = os.path.abspath(os.path.dirname(__file__))
with open(os.path.join(here, "README.md"), encoding="utf-8") as f:
    long_description = f.read()

setup(
    name="jobcelis",
    version="1.4.1",
    description="Official Python SDK for the Jobcelis Event Infrastructure Platform",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/vladimirCeli/jobscelis",
    author="Jobcelis",
    author_email="support@jobcelis.com",
    packages=find_packages(),
    python_requires=">=3.9",
    install_requires=["requests>=2.28.0"],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    project_urls={
        "Documentation": "https://jobcelis.com/docs",
        "Source": "https://github.com/vladimirCeli/jobscelis/tree/main/sdks/python",
    },
)
