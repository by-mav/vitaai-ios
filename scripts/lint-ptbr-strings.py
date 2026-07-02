#!/usr/bin/env python3
"""Block visible PT-BR UI strings that lost accents/cedilha.

This is intentionally conservative: it scans user-facing Swift contexts,
pt-BR Localizable values, and iOS permission strings. It does not scan asset
names, route ids, enum raw values, API paths, analytics names, or localization
keys.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REPLACEMENTS: dict[str, str] = {
    "Transcricao": "Transcrição",
    "transcricao": "transcrição",
    "Questoes": "Questões",
    "questoes": "questões",
    "Questao": "Questão",
    "questao": "questão",
    "Sessao": "Sessão",
    "sessao": "sessão",
    "Configuracoes": "Configurações",
    "configuracoes": "configurações",
    "Configuracao": "Configuração",
    "configuracao": "configuração",
    "Secao": "Seção",
    "secao": "seção",
    "Nivel": "Nível",
    "nivel": "nível",
    "Niveis": "Níveis",
    "niveis": "níveis",
    "Inicio": "Início",
    "inicio": "início",
    "Voce": "Você",
    "voce": "você",
    "Voces": "Vocês",
    "voces": "vocês",
    "Nao": "Não",
    "nao": "não",
    "Codigo": "Código",
    "codigo": "código",
    "Notificacoes": "Notificações",
    "notificacoes": "notificações",
    "Notificacao": "Notificação",
    "notificacao": "notificação",
    "Academico": "Acadêmico",
    "academico": "acadêmico",
    "Academicos": "Acadêmicos",
    "academicos": "acadêmicos",
    "Academica": "Acadêmica",
    "academica": "acadêmica",
    "Automaticas": "Automáticas",
    "automaticas": "automáticas",
    "Materias": "Matérias",
    "materias": "matérias",
    "Materia": "Matéria",
    "materia": "matéria",
    "Possivel": "Possível",
    "possivel": "possível",
    "Disponivel": "Disponível",
    "disponivel": "disponível",
    "Disponiveis": "Disponíveis",
    "disponiveis": "disponíveis",
    "Indisponivel": "Indisponível",
    "indisponivel": "indisponível",
    "Invalido": "Inválido",
    "invalido": "inválido",
    "Proxima": "Próxima",
    "proxima": "próxima",
    "Proximo": "Próximo",
    "proximo": "próximo",
    "Rapida": "Rápida",
    "rapida": "rápida",
    "Rapido": "Rápido",
    "rapido": "rápido",
    "Conteudo": "Conteúdo",
    "conteudo": "conteúdo",
    "Conteudos": "Conteúdos",
    "conteudos": "conteúdos",
    "Descricao": "Descrição",
    "descricao": "descrição",
    "Informacao": "Informação",
    "informacao": "informação",
    "Informacoes": "Informações",
    "informacoes": "informações",
    "Opcao": "Opção",
    "opcao": "opção",
    "Opcoes": "Opções",
    "opcoes": "opções",
    "Avaliacao": "Avaliação",
    "avaliacao": "avaliação",
    "Simulacao": "Simulação",
    "simulacao": "simulação",
    "Conexao": "Conexão",
    "conexao": "conexão",
    "Diagnostico": "Diagnóstico",
    "diagnostico": "diagnóstico",
    "Medica": "Médica",
    "medica": "médica",
    "Medico": "Médico",
    "medico": "médico",
    "Clinica": "Clínica",
    "clinica": "clínica",
    "Saude": "Saúde",
    "saude": "saúde",
    "Historico": "Histórico",
    "historico": "histórico",
    "Pratica": "Prática",
    "pratica": "prática",
    "Titulo": "Título",
    "titulo": "título",
    "Numero": "Número",
    "numero": "número",
    "Permissao": "Permissão",
    "permissao": "permissão",
    "Necessaria": "Necessária",
    "necessaria": "necessária",
    "Necessario": "Necessário",
    "necessario": "necessário",
    "Gravacao": "Gravação",
    "gravacao": "gravação",
    "Gravacoes": "Gravações",
    "gravacoes": "gravações",
    "Revisao": "Revisão",
    "revisao": "revisão",
    "Horarios": "Horários",
    "horarios": "horários",
}

WORD_RE = re.compile(
    r"\b(" + "|".join(re.escape(word) for word in sorted(REPLACEMENTS, key=len, reverse=True)) + r")\b"
)

SWIFT_VISIBLE_HINTS = (
    "Text(",
    "Button(",
    "Label(",
    "Menu(",
    "Alert(",
    "VitaButton(",
    "title:",
    "subtitle:",
    "message:",
    "description:",
    "placeholder:",
    "prompt:",
    "emptyTitle:",
    "emptyMessage:",
    "accessibilityLabel(",
    "NSLocalizedDescriptionKey:",
    "showStudyPackError(",
    "showError(",
    "showToast(",
    "errorMessage =",
    "deleteErrorMessage =",
    "waError =",
    "loadError =",
)

SWIFT_SKIP_HINTS = (
    "String(localized:",
    "LocalizedStringKey(",
    "NSLog(",
    "print(",
    "trackScreen(",
    "accessibilityIdentifier(",
    "identifier:",
    "imageName:",
    "imageAsset:",
    "iconAsset:",
    "systemName:",
    "domain:",
    "id:",
    "route:",
    "source:",
    "GET ",
    "POST ",
    ".get(",
    ".post(",
    ".put(",
    ".delete(",
)


def list_files(staged: bool) -> list[Path]:
    if staged:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        return [
            ROOT / line
            for line in result.stdout.splitlines()
            if line.endswith((".swift", ".plist", ".yml", ".yaml", ".strings"))
        ]

    files: list[Path] = []
    for pattern in (
        "VitaAI/**/*.swift",
        "VitaAI/Info.plist",
        "project.yml",
        "VitaAI/Resources/pt-BR.lproj/Localizable.strings",
    ):
        files.extend(ROOT.glob(pattern))
    return sorted(
        {
            path
            for path in files
            if path.is_file()
            and "/Generated/" not in path.as_posix()
            and ".xcassets" not in path.as_posix()
        }
    )


def string_literals(line: str) -> list[tuple[int, int, str]]:
    spans: list[tuple[int, int, str]] = []
    i = 0
    while i < len(line):
        if line[i] == '"':
            start = i
            i += 1
            escaped = False
            while i < len(line):
                char = line[i]
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    spans.append((start, i + 1, line[start + 1 : i]))
                    break
                i += 1
        i += 1
    return spans


def is_swift_visible_context(line: str, start: int) -> bool:
    before = line[:start]
    if any(hint in before for hint in SWIFT_SKIP_HINTS):
        return False
    if any(hint in before for hint in SWIFT_VISIBLE_HINTS):
        return True
    return False


def localizable_value(line: str) -> str | None:
    match = re.match(r'\s*"[^"]*"\s*=\s*"((?:\\"|[^"])*)";', line)
    if not match:
        return None
    return match.group(1)


def quoted_values(line: str) -> list[str]:
    return [value for _, _, value in string_literals(line)]


def find_bad_words(text: str) -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    for match in WORD_RE.finditer(text):
        wrong = match.group(1)
        found.append((wrong, REPLACEMENTS[wrong]))
    return found


def check_file(path: Path) -> list[str]:
    rel = path.relative_to(ROOT)
    lines = path.read_text(encoding="utf-8").splitlines()
    violations: list[str] = []
    ignore_next = False
    previous_line = ""

    for index, line in enumerate(lines, start=1):
        if "quality-gate-ignore" in previous_line:
            ignore_next = True

        candidates: list[str] = []
        suffix = path.suffix

        if suffix == ".swift":
            for start, _, value in string_literals(line):
                if is_swift_visible_context(line, start):
                    candidates.append(value)
        elif rel.as_posix() == "VitaAI/Resources/pt-BR.lproj/Localizable.strings":
            value = localizable_value(line)
            if value is not None:
                candidates.append(value)
        elif rel.as_posix() == "project.yml":
            if "UsageDescription:" in line:
                candidates.extend(quoted_values(line))
        elif rel.as_posix() == "VitaAI/Info.plist":
            if "UsageDescription" in previous_line:
                candidates.extend(quoted_values(line))

        if ignore_next:
            ignore_next = False
            previous_line = line
            continue

        for value in candidates:
            for wrong, right in find_bad_words(value):
                violations.append(
                    f"{rel}:{index}: '{wrong}' deve ser '{right}' em texto visível: {value}"
                )

        previous_line = line

    return violations


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--staged", action="store_true", help="scan only staged files")
    args = parser.parse_args()

    violations: list[str] = []
    for path in list_files(args.staged):
        if path.exists():
            violations.extend(check_file(path))

    if violations:
        print("PT-BR accent gate failed:\n")
        for violation in violations:
            print(f"  - {violation}")
        print("\nUse acentos/cedilha em texto visível ou adicione quality-gate-ignore com motivo real.")
        return 1

    print("PT-BR accent gate passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
