#!/usr/bin/env python3
"""
Linux Kernel Architecture Extraction - Parser Utilities

This module provides utility functions for parsing C source code,
extracting structures, and generating documentation elements.

SPDX-License-Identifier: GPL-2.0
"""

import re
import os
import json
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from pathlib import Path


@dataclass
class StructField:
    """Represents a field within a C structure."""
    name: str
    type: str
    comment: Optional[str] = None
    is_pointer: bool = False
    array_size: Optional[str] = None


@dataclass
class StructDefinition:
    """Represents a C structure definition."""
    name: str
    fields: List[StructField] = field(default_factory=list)
    file_path: str = ""
    line_number: int = 0
    comment: Optional[str] = None
    nested_structs: List['StructDefinition'] = field(default_factory=list)


@dataclass
class FunctionDefinition:
    """Represents a C function definition."""
    name: str
    return_type: str
    parameters: List[Tuple[str, str]]  # (type, name) pairs
    file_path: str = ""
    line_number: int = 0
    is_static: bool = False
    is_inline: bool = False
    is_exported: bool = False
    doc_comment: Optional[str] = None
    attributes: List[str] = field(default_factory=list)


class CParser:
    """Parser for C source code extraction."""
    
    # Regex patterns for C constructs
    STRUCT_PATTERN = re.compile(
        r'struct\s+(\w+)\s*\{([^}]*)\}',
        re.MULTILINE | re.DOTALL
    )
    
    FIELD_PATTERN = re.compile(
        r'^\s*(?:(?:const|volatile|unsigned|signed|static|struct|enum|union)\s+)*'
        r'(\w+(?:\s*\*)*)\s+'
        r'(\w+)'
        r'(?:\[([^\]]*)\])?'
        r'\s*;'
        r'(?:\s*/\*([^*]*)\*/)?',
        re.MULTILINE
    )
    
    FUNCTION_PATTERN = re.compile(
        r'^(?:(static|inline|__init|__exit|__always_inline)\s+)*'
        r'(\w+(?:\s*\*)*)\s+'
        r'(\w+)\s*'
        r'\(([^)]*)\)',
        re.MULTILINE
    )
    
    EXPORT_SYMBOL_PATTERN = re.compile(
        r'EXPORT_SYMBOL(?:_GPL)?\s*\(\s*(\w+)\s*\)'
    )
    
    KERNEL_DOC_PATTERN = re.compile(
        r'/\*\*\s*\n'
        r'\s*\*\s*(\w+)\s*-\s*([^\n]*)\n'
        r'((?:\s*\*[^\n]*\n)*?)'
        r'\s*\*/',
        re.MULTILINE
    )
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
    
    def parse_struct(self, content: str) -> List[StructDefinition]:
        """Extract all structure definitions from C code."""
        structs = []
        
        for match in self.STRUCT_PATTERN.finditer(content):
            struct_name = match.group(1)
            body = match.group(2)
            
            struct_def = StructDefinition(name=struct_name)
            
            # Parse fields
            for field_match in self.FIELD_PATTERN.finditer(body):
                field_type = field_match.group(1).strip()
                field_name = field_match.group(2)
                array_size = field_match.group(3)
                comment = field_match.group(4)
                
                is_pointer = '*' in field_type
                
                struct_def.fields.append(StructField(
                    name=field_name,
                    type=field_type.replace('*', '').strip(),
                    is_pointer=is_pointer,
                    array_size=array_size,
                    comment=comment.strip() if comment else None
                ))
            
            structs.append(struct_def)
        
        return structs
    
    def parse_functions(self, content: str, file_path: str = "") -> List[FunctionDefinition]:
        """Extract all function definitions from C code."""
        functions = []
        
        # Find exported symbols
        exported = set(self.EXPORT_SYMBOL_PATTERN.findall(content))
        
        # Find kernel-doc comments
        doc_comments = {}
        for doc_match in self.KERNEL_DOC_PATTERN.finditer(content):
            func_name = doc_match.group(1)
            brief = doc_match.group(2).strip()
            doc_comments[func_name] = brief
        
        for match in self.FUNCTION_PATTERN.finditer(content):
            modifiers = match.group(1) or ""
            return_type = match.group(2).strip()
            func_name = match.group(3)
            params_str = match.group(4)
            
            # Parse parameters
            params = []
            if params_str.strip() and params_str.strip() != 'void':
                for param in params_str.split(','):
                    param = param.strip()
                    if param:
                        # Split into type and name
                        parts = param.rsplit(' ', 1)
                        if len(parts) == 2:
                            params.append((parts[0].strip(), parts[1].strip()))
                        else:
                            params.append((param, ''))
            
            func_def = FunctionDefinition(
                name=func_name,
                return_type=return_type,
                parameters=params,
                file_path=file_path,
                is_static='static' in modifiers,
                is_inline='inline' in modifiers or '__always_inline' in modifiers,
                is_exported=func_name in exported,
                doc_comment=doc_comments.get(func_name)
            )
            
            # Check for __init/__exit attributes
            if '__init' in modifiers:
                func_def.attributes.append('__init')
            if '__exit' in modifiers:
                func_def.attributes.append('__exit')
            
            functions.append(func_def)
        
        return functions
    
    def parse_file(self, relative_path: str) -> Dict:
        """Parse a C file and extract all relevant information."""
        full_path = self.project_root / relative_path
        
        if not full_path.exists():
            raise FileNotFoundError(f"File not found: {relative_path}")
        
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        return {
            'file': relative_path,
            'structs': self.parse_struct(content),
            'functions': self.parse_functions(content, relative_path),
            'lines': len(content.splitlines())
        }
    
    def extract_includes(self, content: str) -> List[str]:
        """Extract all #include statements."""
        pattern = re.compile(r'#include\s*[<"]([^>"]+)[>"]')
        return pattern.findall(content)
    
    def extract_macros(self, content: str) -> List[Tuple[str, str]]:
        """Extract macro definitions."""
        pattern = re.compile(r'#define\s+(\w+)(?:\([^)]*\))?\s+(.+?)(?:\n|$)')
        return pattern.findall(content)


class PlantUMLGenerator:
    """Generate PlantUML diagrams from parsed C code."""
    
    @staticmethod
    def generate_class_diagram(structs: List[StructDefinition], title: str = "Data Structures") -> str:
        """Generate a PlantUML class diagram from struct definitions."""
        lines = [
            "@startuml",
            f"title {title}",
            "",
            "skinparam classAttributeIconSize 0",
            "skinparam class {",
            "    BackgroundColor #FEFECE",
            "    BorderColor #A80036",
            "    ArrowColor #A80036",
            "}",
            ""
        ]
        
        for struct in structs:
            lines.append(f'class "struct {struct.name}" as {struct.name} {{')
            
            for field in struct.fields:
                prefix = "+" if not field.name.startswith('_') else "-"
                type_str = field.type
                if field.is_pointer:
                    type_str += " *"
                if field.array_size:
                    type_str += f"[{field.array_size}]"
                
                lines.append(f"    {prefix}{type_str} {field.name}")
            
            if struct.comment:
                lines.append("    --")
                lines.append(f"    {struct.comment}")
            
            lines.append("}")
            lines.append("")
        
        # Add relationships based on pointer fields
        for struct in structs:
            for field in struct.fields:
                if field.is_pointer and field.type in [s.name for s in structs]:
                    lines.append(f'{struct.name} --> {field.type} : {field.name}')
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    @staticmethod
    def generate_sequence_diagram(
        title: str,
        participants: List[Tuple[str, str]],  # (alias, display_name)
        messages: List[Tuple[str, str, str]]  # (from, to, message)
    ) -> str:
        """Generate a PlantUML sequence diagram."""
        lines = [
            "@startuml",
            f"title {title}",
            "",
            "skinparam sequenceArrowThickness 2",
            "skinparam roundcorner 20",
            ""
        ]
        
        # Add participants
        colors = ["#LightBlue", "#LightGreen", "#LightYellow", "#LightPink", "#LightGray"]
        for i, (alias, name) in enumerate(participants):
            color = colors[i % len(colors)]
            lines.append(f'participant "{name}" as {alias} {color}')
        
        lines.append("")
        
        # Add messages
        for from_p, to_p, msg in messages:
            lines.append(f"{from_p} -> {to_p}: {msg}")
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    @staticmethod
    def generate_state_diagram(
        title: str,
        states: List[str],
        transitions: List[Tuple[str, str, str]]  # (from, to, event)
    ) -> str:
        """Generate a PlantUML state diagram."""
        lines = [
            "@startuml",
            f"title {title}",
            "",
            "skinparam state {",
            "    BackgroundColor #FEFECE",
            "    BorderColor #A80036",
            "}",
            ""
        ]
        
        # Add initial state
        if states:
            lines.append(f"[*] --> {states[0]}")
        
        # Add transitions
        for from_s, to_s, event in transitions:
            lines.append(f"{from_s} --> {to_s} : {event}")
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    @staticmethod
    def generate_c4_container(
        title: str,
        system_name: str,
        containers: List[Dict],  # [{name, description, technology}]
        external_systems: List[Dict] = None,
        relationships: List[Tuple[str, str, str]] = None  # (from, to, description)
    ) -> str:
        """Generate a C4 Container diagram."""
        lines = [
            "@startuml",
            "!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml",
            "",
            f"title {title}",
            "",
            "LAYOUT_WITH_LEGEND()",
            "",
            f'System_Boundary({system_name.lower().replace(" ", "_")}, "{system_name}") {{'
        ]
        
        for container in containers:
            name = container['name']
            alias = name.lower().replace(' ', '_').replace('-', '_')
            desc = container.get('description', '')
            tech = container.get('technology', 'C')
            lines.append(f'    Container({alias}, "{name}", "{tech}", "{desc}")')
        
        lines.append("}")
        lines.append("")
        
        if external_systems:
            for ext in external_systems:
                name = ext['name']
                alias = name.lower().replace(' ', '_').replace('-', '_')
                desc = ext.get('description', '')
                lines.append(f'System_Ext({alias}, "{name}", "{desc}")')
        
        lines.append("")
        
        if relationships:
            for from_c, to_c, desc in relationships:
                from_alias = from_c.lower().replace(' ', '_').replace('-', '_')
                to_alias = to_c.lower().replace(' ', '_').replace('-', '_')
                lines.append(f'Rel({from_alias}, {to_alias}, "{desc}")')
        
        lines.append("@enduml")
        return "\n".join(lines)


class RSTGenerator:
    """Generate reStructuredText documentation."""
    
    @staticmethod
    def header(title: str, level: int = 1) -> str:
        """Generate RST header with appropriate underline."""
        chars = "=-~^\"'"
        char = chars[min(level - 1, len(chars) - 1)]
        underline = char * len(title)
        
        if level == 1:
            return f"{underline}\n{title}\n{underline}\n"
        return f"{title}\n{underline}\n"
    
    @staticmethod
    def table(headers: List[str], rows: List[List[str]]) -> str:
        """Generate RST table."""
        # Calculate column widths
        widths = [len(h) for h in headers]
        for row in rows:
            for i, cell in enumerate(row):
                if i < len(widths):
                    widths[i] = max(widths[i], len(str(cell)))
        
        # Generate table
        lines = []
        separator = "+" + "+".join("-" * (w + 2) for w in widths) + "+"
        
        lines.append(separator)
        
        # Header row
        header_line = "|"
        for i, h in enumerate(headers):
            header_line += f" {h:{widths[i]}} |"
        lines.append(header_line)
        lines.append(separator.replace("-", "="))
        
        # Data rows
        for row in rows:
            row_line = "|"
            for i, cell in enumerate(row):
                if i < len(widths):
                    row_line += f" {str(cell):{widths[i]}} |"
            lines.append(row_line)
            lines.append(separator)
        
        return "\n".join(lines)
    
    @staticmethod
    def code_block(code: str, language: str = "c") -> str:
        """Generate RST code block."""
        return f".. code-block:: {language}\n\n" + \
               "\n".join("    " + line for line in code.splitlines())
    
    @staticmethod
    def toctree(entries: List[str], maxdepth: int = 2) -> str:
        """Generate RST toctree directive."""
        lines = [
            ".. toctree::",
            f"   :maxdepth: {maxdepth}",
            ""
        ]
        for entry in entries:
            lines.append(f"   {entry}")
        return "\n".join(lines)
    
    @staticmethod
    def uml_diagram(puml_content: str) -> str:
        """Embed PlantUML diagram in RST."""
        return f".. uml::\n\n" + \
               "\n".join("    " + line for line in puml_content.splitlines())


def to_json(obj) -> str:
    """Convert dataclass objects to JSON."""
    def default(o):
        if hasattr(o, '__dataclass_fields__'):
            return {k: getattr(o, k) for k in o.__dataclass_fields__}
        return str(o)
    
    return json.dumps(obj, default=default, indent=2)


if __name__ == "__main__":
    # Self-test / example usage
    import sys
    
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        project_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.dirname(os.path.abspath(__file__)))))
    
    parser = CParser(project_root)
    
    # Example: parse a kernel file
    test_files = ["kernel/fork.c", "mm/page_alloc.c"]
    
    for test_file in test_files:
        try:
            result = parser.parse_file(test_file)
            print(f"\n=== {test_file} ===")
            print(f"Structs found: {len(result['structs'])}")
            print(f"Functions found: {len(result['functions'])}")
            
            exported = [f for f in result['functions'] if f.is_exported]
            print(f"Exported symbols: {len(exported)}")
            
            if result['structs']:
                print("\nGenerating class diagram...")
                puml = PlantUMLGenerator.generate_class_diagram(
                    result['structs'][:5],  # Limit to first 5
                    f"Data Structures in {test_file}"
                )
                print(puml[:500] + "..." if len(puml) > 500 else puml)
                
        except FileNotFoundError:
            print(f"File not found: {test_file}")
        except Exception as e:
            print(f"Error parsing {test_file}: {e}")
