# Configuration file for the Sphinx documentation builder.
# Linux Kernel Architecture Documentation

import os
import sys

# -- Project information -----------------------------------------------------

project = 'Linux Kernel Architecture'
copyright = '2025, Linux Kernel Community'
author = 'Architecture Extraction Agent'
release = '6.19-rc3'
version = '6.19'

# -- General configuration ---------------------------------------------------

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.todo',
    'sphinx.ext.graphviz',
]

# Try to enable PlantUML support
try:
    import sphinxcontrib.plantuml
    extensions.append('sphinxcontrib.plantuml')
    
    # Configure PlantUML
    plantuml = 'java -jar /usr/share/plantuml/plantuml.jar'
    plantuml_output_format = 'svg'
except ImportError:
    pass

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', 'scripts']

# The master toctree document
master_doc = 'index'

# -- Options for HTML output -------------------------------------------------

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

# Theme options
html_theme_options = {
    'collapse_navigation': False,
    'sticky_navigation': True,
    'navigation_depth': 4,
    'includehidden': True,
    'titles_only': False
}

# -- Options for LaTeX output ------------------------------------------------

latex_elements = {
    'papersize': 'a4paper',
    'pointsize': '11pt',
    'preamble': r'''
\usepackage{charter}
\usepackage[defaultsans]{lato}
\usepackage{inconsolata}
''',
}

latex_documents = [
    (master_doc, 'LinuxKernelArchitecture.tex',
     'Linux Kernel Architecture Documentation',
     'Linux Kernel Community', 'manual'),
]

# -- Extension configuration -------------------------------------------------

todo_include_todos = True

# Graphviz configuration
graphviz_output_format = 'svg'
