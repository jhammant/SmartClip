import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('install_codex',ROOT/'scripts/install-codex.py')
installer=importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class CodexInstallTests(unittest.TestCase):
    def test_install_and_repeat_keep_content_and_executable(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            files=installer.install(ROOT,root/'skills',root/'bin')
            before={p:p.read_bytes() for p in files}
            installer.install(ROOT,root/'skills',root/'bin')
            self.assertEqual(before,{p:p.read_bytes() for p in files})
            self.assertTrue((root/'bin/smartclip').stat().st_mode & 0o111)
            for name in ('clp','cpy','pst','clh'):
                text=(root/'skills'/name/'SKILL.md').read_text()
                self.assertIn('name: '+name+'\n',text)
                original=(ROOT/'commands'/f'{name}.md').read_text().split('\n---',1)[1].lstrip()
                self.assertTrue(text.endswith(original))

    def test_conflict_leaves_everything_untouched(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            target=root/'skills/pst/SKILL.md'
            target.parent.mkdir(parents=True)
            target.write_text('personal changes')
            with self.assertRaises(FileExistsError):
                installer.install(ROOT,root/'skills',root/'bin')
            self.assertEqual(target.read_text(),'personal changes')
            self.assertFalse((root/'bin').exists())

    def test_symlinked_skill_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'other').mkdir()
            (root/'skills').mkdir()
            (root/'skills/clp').symlink_to(root/'other',target_is_directory=True)
            with self.assertRaises(FileExistsError):
                installer.install(ROOT,root/'skills',root/'bin')
            self.assertEqual(list((root/'other').iterdir()),[])


if __name__=='__main__': unittest.main()
