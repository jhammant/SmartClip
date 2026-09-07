#!/usr/bin/env python3
"""Install SmartClip as Codex skills from the maintained command sources.

Stdlib only; no network, clipboard access, or credential changes. Existing files
are left alone if identical and refused if different. Use --skills-dir/--bin-dir
to install into a custom location.
"""
import argparse
import json
import os
from pathlib import Path


def skill_text(name, command):
    if not command.startswith('---\n'):
        raise ValueError('Command is missing frontmatter: '+name)
    front, body=command[4:].split('\n---',1)
    description=next(line.split(':',1)[1].strip() for line in front.splitlines()
                     if line.startswith('description:'))
    note='''Interpret `$ARGUMENTS` as the user's text following this skill invocation,
not as a shell variable. Use Codex's shell and file tools for generic tool
names in the original workflow. Resolve `smartclip` from PATH or the installed
helper's absolute path. Preserve the original clipboard and history behavior.
'''
    return '---\nname: '+name+'\ndescription: '+json.dumps(description)+'\n---\n\n'+note+'\n'+body.lstrip()


def install(source, skills_dir, bin_dir):
    plans=[(bin_dir/'smartclip',(source/'bin/smartclip').read_bytes(),0o755)]
    for name in ('clp','cpy','pst','clh'):
        content=skill_text(name,(source/'commands'/f'{name}.md').read_text())
        plans.append((skills_dir/name/'SKILL.md',content.encode(),0o644))
    # Check the complete installation before creating or changing anything.
    for target,content,_ in plans:
        if target.is_symlink() or target.parent.is_symlink():
            raise FileExistsError('Inspect the existing symlink before installing: '+str(target))
        if target.exists() and (not target.is_file() or target.read_bytes()!=content):
            raise FileExistsError('Existing file differs; move it aside first: '+str(target))
    for target,content,mode in plans:
        if target.exists():
            continue
        target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('xb') as output:
            output.write(content)
        target.chmod(mode)
    return [p for p,_,_ in plans]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skills-dir',type=Path,default=Path.home()/'.agents/skills')
    parser.add_argument('--bin-dir',type=Path,default=Path(os.environ.get('SMARTCLIP_BIN_DIR',str(Path.home()/'.local/bin'))))
    args=parser.parse_args()
    source=Path(__file__).resolve().parents[1]
    try:
        files=install(source,args.skills_dir.expanduser(),args.bin_dir.expanduser())
    except (OSError,ValueError) as exc:
        parser.exit(1,f'SmartClip: {exc}\n')
    print('Installed '+str(len(files))+' files. Add '+str(args.bin_dir)+' to PATH if needed.')
    print('Start a new Codex conversation and use $clp, $cpy, $pst or $clh.')
    print('Clipboard history stays opt-in through SMARTCLIP_HISTORY=1.')


if __name__=='__main__':
    main()
