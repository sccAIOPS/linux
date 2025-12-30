#!/usr/bin/env python3
"""
extract_structures.py - Extract and document C structures from kernel source

This script parses kernel header files to extract structure definitions
and generates documentation in various formats.

Usage:
    ./extract_structures.py [OPTIONS] <path>

SPDX-License-Identifier: GPL-2.0
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field, asdict

# Add lib directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
from parser_utils import CParser, StructDefinition, StructField, PlantUMLGenerator, RSTGenerator


@dataclass
class StructRelationship:
    """Represents a relationship between two structures."""
    from_struct: str
    to_struct: str
    field_name: str
    relationship_type: str  # 'pointer', 'embedded', 'array'
    cardinality: str  # '1:1', '1:n', 'n:1'


class StructureExtractor:
    """Extract and analyze structure definitions from kernel source."""
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.parser = CParser(project_root)
        self.structs: Dict[str, StructDefinition] = {}
        self.relationships: List[StructRelationship] = []
    
    def extract_from_file(self, relative_path: str) -> List[StructDefinition]:
        """Extract structures from a single file."""
        full_path = self.project_root / relative_path
        
        if not full_path.exists():
            raise FileNotFoundError(f"File not found: {relative_path}")
        
        with open(full_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        # Enhanced struct pattern to capture more details
        pattern = re.compile(
            r'(?:/\*\*([^*]*(?:\*(?!/)[^*]*)*)\*/\s*)?'  # Optional kernel-doc
            r'struct\s+(\w+)\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}',
            re.MULTILINE | re.DOTALL
        )
        
        structs = []
        
        for match in pattern.finditer(content):
            doc_comment = match.group(1)
            struct_name = match.group(2)
            body = match.group(3)
            
            # Find line number
            line_num = content[:match.start()].count('\n') + 1
            
            struct_def = StructDefinition(
                name=struct_name,
                file_path=relative_path,
                line_number=line_num,
                comment=self._parse_doc_comment(doc_comment) if doc_comment else None
            )
            
            # Parse fields
            struct_def.fields = self._parse_fields(body)
            
            structs.append(struct_def)
            self.structs[struct_name] = struct_def
        
        return structs
    
    def extract_from_directory(self, relative_path: str, recursive: bool = True) -> List[StructDefinition]:
        """Extract structures from all files in a directory."""
        full_path = self.project_root / relative_path
        
        if not full_path.exists():
            raise FileNotFoundError(f"Directory not found: {relative_path}")
        
        all_structs = []
        
        pattern = '**/*.h' if recursive else '*.h'
        for header in full_path.glob(pattern):
            try:
                rel_path = str(header.relative_to(self.project_root))
                structs = self.extract_from_file(rel_path)
                all_structs.extend(structs)
            except Exception as e:
                print(f"Warning: Error parsing {header}: {e}", file=sys.stderr)
        
        # Also check .c files for internal structs
        pattern = '**/*.c' if recursive else '*.c'
        for source in full_path.glob(pattern):
            try:
                rel_path = str(source.relative_to(self.project_root))
                structs = self.extract_from_file(rel_path)
                all_structs.extend(structs)
            except Exception as e:
                print(f"Warning: Error parsing {source}: {e}", file=sys.stderr)
        
        return all_structs
    
    def _parse_doc_comment(self, comment: str) -> str:
        """Parse kernel-doc style comment."""
        if not comment:
            return ""
        
        # Clean up comment
        lines = []
        for line in comment.split('\n'):
            line = re.sub(r'^\s*\*\s?', '', line)
            if line.strip():
                lines.append(line.strip())
        
        return ' '.join(lines)
    
    def _parse_fields(self, body: str) -> List[StructField]:
        """Parse structure fields from body."""
        fields = []
        
        # Field pattern - handles complex types
        field_pattern = re.compile(
            r'^\s*'
            r'(?:(?:const|volatile|unsigned|signed|static|__rcu|__user|__kernel)\s+)*'
            r'((?:struct|union|enum)\s+\w+|\w+(?:\s*\*)*)\s+'
            r'(\**)(\w+)'
            r'(?:\[([^\]]*)\])?'
            r'(?:\s*:\s*\d+)?'  # Bit fields
            r'\s*;'
            r'(?:\s*/\*([^*]*)\*/)?',
            re.MULTILINE
        )
        
        for match in field_pattern.finditer(body):
            type_str = match.group(1).strip()
            ptr_str = match.group(2)
            name = match.group(3)
            array_size = match.group(4)
            comment = match.group(5)
            
            is_pointer = '*' in type_str or ptr_str
            
            fields.append(StructField(
                name=name,
                type=type_str.replace('*', '').strip(),
                is_pointer=is_pointer,
                array_size=array_size,
                comment=comment.strip() if comment else None
            ))
        
        return fields
    
    def analyze_relationships(self) -> List[StructRelationship]:
        """Analyze relationships between extracted structures."""
        self.relationships = []
        known_structs = set(self.structs.keys())
        
        for struct_name, struct_def in self.structs.items():
            for field in struct_def.fields:
                # Check if field type references another known struct
                target_type = field.type.replace('struct ', '').replace('union ', '')
                
                if target_type in known_structs and target_type != struct_name:
                    if field.is_pointer:
                        rel_type = 'pointer'
                        cardinality = '1:n' if field.array_size else '1:1'
                    elif field.array_size:
                        rel_type = 'array'
                        cardinality = '1:n'
                    else:
                        rel_type = 'embedded'
                        cardinality = '1:1'
                    
                    self.relationships.append(StructRelationship(
                        from_struct=struct_name,
                        to_struct=target_type,
                        field_name=field.name,
                        relationship_type=rel_type,
                        cardinality=cardinality
                    ))
        
        return self.relationships
    
    def to_plantuml(self, title: str = "Kernel Data Structures") -> str:
        """Generate PlantUML class diagram."""
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
            "skinparam stereotypeCBackgroundColor #E0FFE0",
            ""
        ]
        
        # Add struct definitions
        for struct_name, struct_def in self.structs.items():
            lines.append(f'class "struct {struct_name}" as {struct_name} <<struct>> {{')
            
            for field in struct_def.fields[:20]:  # Limit fields for readability
                visibility = "+" if not field.name.startswith('_') else "-"
                type_str = field.type
                if field.is_pointer:
                    type_str += " *"
                if field.array_size:
                    type_str += f"[{field.array_size}]"
                
                lines.append(f"    {visibility}{type_str} {field.name}")
            
            if len(struct_def.fields) > 20:
                lines.append(f"    .. {len(struct_def.fields) - 20} more fields ..")
            
            if struct_def.comment:
                lines.append("    --")
                # Truncate long comments
                comment = struct_def.comment[:50] + "..." if len(struct_def.comment) > 50 else struct_def.comment
                lines.append(f"    {comment}")
            
            lines.append("}")
            lines.append("")
        
        # Add relationships
        for rel in self.relationships:
            arrow = "-->" if rel.relationship_type == 'pointer' else "*--"
            if rel.cardinality == '1:n':
                arrow = '"1" ' + arrow + ' "*"'
            lines.append(f'{rel.from_struct} {arrow} {rel.to_struct} : {rel.field_name}')
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    def to_rst(self) -> str:
        """Generate RST documentation."""
        rst = RSTGenerator()
        lines = [rst.header("Kernel Data Structures", 1)]
        
        lines.append("\n.. contents:: Table of Contents\n   :depth: 2\n   :local:\n")
        
        # Group by file
        by_file: Dict[str, List[StructDefinition]] = {}
        for struct in self.structs.values():
            file_path = struct.file_path
            if file_path not in by_file:
                by_file[file_path] = []
            by_file[file_path].append(struct)
        
        for file_path, structs in sorted(by_file.items()):
            lines.append(rst.header(f"File: {file_path}", 2))
            
            for struct in structs:
                lines.append(rst.header(f"struct {struct.name}", 3))
                
                if struct.comment:
                    lines.append(f"\n{struct.comment}\n")
                
                lines.append(f"\n:Location: ``{struct.file_path}:{struct.line_number}``\n")
                
                # Fields table
                if struct.fields:
                    headers = ["Type", "Name", "Description"]
                    rows = []
                    for field in struct.fields:
                        type_str = field.type
                        if field.is_pointer:
                            type_str += " *"
                        if field.array_size:
                            type_str += f"[{field.array_size}]"
                        rows.append([type_str, field.name, field.comment or ""])
                    
                    lines.append("\n**Fields:**\n")
                    lines.append(rst.table(headers, rows))
                
                lines.append("")
        
        return "\n".join(lines)
    
    def to_json(self) -> str:
        """Generate JSON output."""
        output = {
            'structures': [],
            'relationships': []
        }
        
        for struct in self.structs.values():
            struct_dict = {
                'name': struct.name,
                'file_path': struct.file_path,
                'line_number': struct.line_number,
                'comment': struct.comment,
                'fields': [
                    {
                        'name': f.name,
                        'type': f.type,
                        'is_pointer': f.is_pointer,
                        'array_size': f.array_size,
                        'comment': f.comment
                    }
                    for f in struct.fields
                ]
            }
            output['structures'].append(struct_dict)
        
        for rel in self.relationships:
            output['relationships'].append({
                'from': rel.from_struct,
                'to': rel.to_struct,
                'field': rel.field_name,
                'type': rel.relationship_type,
                'cardinality': rel.cardinality
            })
        
        return json.dumps(output, indent=2)


def main():
    parser = argparse.ArgumentParser(
        description='Extract and document C structures from kernel source',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    %(prog)s include/linux/sched.h
    %(prog)s -f plantuml -o sched.puml include/linux/sched.h
    %(prog)s --filter "task*" include/linux/
    %(prog)s -f rst --recursive mm/
        """
    )
    
    parser.add_argument('path', help='Path to file or directory to analyze')
    parser.add_argument('-o', '--output', help='Output file (default: stdout)')
    parser.add_argument('-f', '--format', choices=['text', 'json', 'rst', 'plantuml'],
                        default='text', help='Output format')
    parser.add_argument('--filter', help='Filter structures by name pattern')
    parser.add_argument('--recursive', '-r', action='store_true',
                        help='Recursively search directories')
    parser.add_argument('--no-relationships', action='store_true',
                        help='Skip relationship analysis')
    parser.add_argument('--title', default='Kernel Data Structures',
                        help='Title for diagrams')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Determine project root (go up from script location)
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent.parent
    
    extractor = StructureExtractor(str(project_root))
    
    target_path = Path(project_root) / args.path
    
    try:
        if target_path.is_file():
            if args.verbose:
                print(f"Extracting from file: {args.path}", file=sys.stderr)
            extractor.extract_from_file(args.path)
        elif target_path.is_dir():
            if args.verbose:
                print(f"Extracting from directory: {args.path}", file=sys.stderr)
            extractor.extract_from_directory(args.path, recursive=args.recursive)
        else:
            print(f"Error: Path not found: {args.path}", file=sys.stderr)
            sys.exit(1)
        
        # Apply filter if specified
        if args.filter:
            import fnmatch
            filtered = {k: v for k, v in extractor.structs.items()
                       if fnmatch.fnmatch(k, args.filter)}
            extractor.structs = filtered
        
        # Analyze relationships
        if not args.no_relationships:
            extractor.analyze_relationships()
        
        if args.verbose:
            print(f"Found {len(extractor.structs)} structures", file=sys.stderr)
            print(f"Found {len(extractor.relationships)} relationships", file=sys.stderr)
        
        # Generate output
        if args.format == 'json':
            output = extractor.to_json()
        elif args.format == 'rst':
            output = extractor.to_rst()
        elif args.format == 'plantuml':
            output = extractor.to_plantuml(args.title)
        else:  # text
            output = []
            for struct in extractor.structs.values():
                output.append(f"struct {struct.name} ({struct.file_path}:{struct.line_number})")
                for field in struct.fields:
                    type_str = field.type
                    if field.is_pointer:
                        type_str += " *"
                    output.append(f"    {type_str:30} {field.name}")
                output.append("")
            output = "\n".join(output)
        
        # Write output
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
            if args.verbose:
                print(f"Output written to: {args.output}", file=sys.stderr)
        else:
            print(output)
    
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
