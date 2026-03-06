from setuptools import setup, find_packages

setup(
    name="jobcelis",
    version="1.0.0",
    description="Official Python SDK for the Jobcelis Event Infrastructure Platform",
    packages=find_packages(),
    python_requires=">=3.9",
    install_requires=["requests>=2.28.0"],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
    ],
)
