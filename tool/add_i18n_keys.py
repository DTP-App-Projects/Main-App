"""Merge translation keys into lib/core/language/{en,ar}.json.

Usage: python tool/add_i18n_keys.py keys.json
where keys.json is {"en": {"section": {"key": "..."}}, "ar": {...}}.

Existing keys are never overwritten; the files keep 2-space indentation and
key order, with new keys appended to their section.
"""
import json
import sys


def merge(target, extra, path=''):
    for key, value in extra.items():
        if isinstance(value, dict):
            node = target.setdefault(key, {})
            if not isinstance(node, dict):
                raise SystemExit(f'conflict at {path}{key}: not a section')
            merge(node, value, f'{path}{key}.')
        elif key not in target:
            target[key] = value


def main():
    extra = json.load(open(sys.argv[1], encoding='utf-8'))
    en = set(json.dumps(extra.get('en', {}), sort_keys=True))
    for lang in ('en', 'ar'):
        path = f'lib/core/language/{lang}.json'
        data = json.load(open(path, encoding='utf-8'))
        merge(data, extra.get(lang, {}))
        with open(path, 'w', encoding='utf-8', newline='\n') as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2)
            handle.write('\n')

    def flat(d, prefix=''):
        out = set()
        for k, v in d.items():
            out |= flat(v, f'{prefix}{k}.') if isinstance(v, dict) else {prefix + k}
        return out

    en_keys = flat(json.load(open('lib/core/language/en.json', encoding='utf-8')))
    ar_keys = flat(json.load(open('lib/core/language/ar.json', encoding='utf-8')))
    missing = (en_keys ^ ar_keys)
    print('ok; keys only in one language:', sorted(missing) if missing else 'none')


if __name__ == '__main__':
    main()
