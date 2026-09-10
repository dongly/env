from setuptools import setup
import sys
import os

# Add current directory to path for version module discovery
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from version import get_rt_env_version, get_rt_env_description
    _, env_ver = get_rt_env_version()
    env_desc = get_rt_env_description()
except Exception:
    env_ver = '2.0.2'
    env_desc = 'A command-line toolkit for RT-Thread development.'

setup(
    version=env_ver,
    description=env_desc,
)
