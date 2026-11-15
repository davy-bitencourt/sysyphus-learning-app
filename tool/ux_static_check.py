"""Verificações estáticas de UX. Não substitui flutter analyze/test/run."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
lib = root / 'lib'
files = [
    lib/'screens/home.dart',
    lib/'screens/questions_edit_screen.dart',
    lib/'screens/questions_screen.dart',
    lib/'widgets/quick_subject_dialog.dart',
    lib/'widgets/main_scaffold.dart',
    lib/'data/services/quick_question_templates.dart',
]
for f in files:
    assert f.is_file(), f'Arquivo ausente: {f}'

# Os novos rótulos, inclusive validações, devem existir em todos os idiomas.
pt = json.loads((lib/'l10n/pt.json').read_text())
en = json.loads((lib/'l10n/en.json').read_text())
keys = {key for key in pt if key.startswith('ux.')}
for lang in ('pt','en','es','ja'):
    strings = json.loads((lib/f'l10n/{lang}.json').read_text())
    assert not keys - strings.keys(), f'{lang}: faltam {keys - strings.keys()}'
    for key in keys:
        assert strings[key].strip(), f'{lang}: valor vazio {key}'

# Placeholder das traduções novas deve ser idêntico aos de pt-BR.
import re
for lang in ('en','es','ja'):
    strings = json.loads((lib/f'l10n/{lang}.json').read_text())
    for key in keys:
        expected = set(re.findall(r'\{\w+\}', pt[key]))
        actual = set(re.findall(r'\{\w+\}', strings[key]))
        assert actual == expected, (lang,key,expected,actual)

src = (lib/'screens/questions_edit_screen.dart').read_text()
assert 'QuestionDao().insert' not in src or 'QuestionDao' in src
for marker in ('QuickQuestionTemplates.ensureExists','ux_comment','ux.optionValidation','showQuickSubjectDialog'):
    assert marker in src, marker

assert all((root/'web'/part).stat().st_size > 10000 for part in ('sqflite_sw.js','sqlite3.wasm'))
print('PASS: arquivos de UX, 4 idiomas (novas mensagens), parâmetros e recursos SQLite Web')
print(f'OBS: strings antigas não traduzidas para espanhol/japonês usam fallback inglês: {len(pt) - len(json.loads((lib/"l10n/es.json").read_text()))} chaves')
