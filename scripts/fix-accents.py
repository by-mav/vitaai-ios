#!/usr/bin/env python3
"""Fix missing Portuguese accents in Swift UI strings only.
Only modifies text inside double-quoted strings and // comments."""
import os, sys, re

REPLACEMENTS = {
    "voce": "você", "Voce": "Você",
    "tambem": "também", "Tambem": "Também",
    "codigo": "código", "Codigo": "Código",
    "saude": "saúde", "Saude": "Saúde", "SAUDE": "SAÚDE",
    "medica": "médica", "Medica": "Médica", "MEDICA": "MÉDICA",
    "medico": "médico", "Medico": "Médico", "MEDICO": "MÉDICO",
    "clinica": "clínica", "Clinica": "Clínica", "CLINICA": "CLÍNICA",
    "clinico": "clínico", "Clinico": "Clínico",
    "academico": "acadêmico", "Academico": "Acadêmico",
    "academica": "acadêmica", "Academica": "Acadêmica",
    "academicos": "acadêmicos",
    "questoes": "questões", "Questoes": "Questões",
    "questao": "questão", "Questao": "Questão",
    "sessao": "sessão", "Sessao": "Sessão",
    "transcricao": "transcrição", "Transcricao": "Transcrição",
    "horarios": "horários", "Horarios": "Horários",
    "paginas": "páginas", "Paginas": "Páginas",
    "conteudo": "conteúdo", "Conteudo": "Conteúdo",
    "disponivel": "disponível", "Disponivel": "Disponível",
    "indisponivel": "indisponível", "Indisponivel": "Indisponível",
    "disponiveis": "disponíveis", "Disponiveis": "Disponíveis",
    "nivel": "nível", "Nivel": "Nível", "NIVEL": "NÍVEL",
    "niveis": "níveis",
    "periodo": "período", "Periodo": "Período",
    "avaliacao": "avaliação", "Avaliacao": "Avaliação",
    "avaliacoes": "avaliações", "Avaliacoes": "Avaliações",
    "conexao": "conexão", "Conexao": "Conexão",
    "notificacao": "notificação", "Notificacao": "Notificação",
    "notificacoes": "notificações", "Notificacoes": "Notificações",
    "diagnostico": "diagnóstico", "Diagnostico": "Diagnóstico",
    "inicio": "início", "Inicio": "Início",
    "historico": "histórico", "Historico": "Histórico",
    "basica": "básica", "Basica": "Básica",
    "basico": "básico", "Basico": "Básico",
    "maximo": "máximo", "Maximo": "Máximo",
    "minimo": "mínimo", "Minimo": "Mínimo",
    "possivel": "possível", "Possivel": "Possível",
    "rapido": "rápido", "Rapido": "Rápido",
    "rapida": "rápida", "Rapida": "Rápida",
    "topico": "tópico", "Topico": "Tópico",
    "topicos": "tópicos", "Topicos": "Tópicos",
    "funcao": "função", "Funcao": "Função",
    "atencao": "atenção", "Atencao": "Atenção",
    "preparacao": "preparação", "Preparacao": "Preparação",
    "descricao": "descrição", "Descricao": "Descrição",
    "informacao": "informação", "Informacao": "Informação",
    "informacoes": "informações", "Informacoes": "Informações",
    "educacao": "educação", "Educacao": "Educação",
    "materias": "matérias", "Materias": "Matérias",
    "opcoes": "opções", "Opcoes": "Opções", "OPCOES": "OPÇÕES",
    "pratica": "prática", "Pratica": "Prática",
    "pratico": "prático", "Pratico": "Prático",
    "titulo": "título", "Titulo": "Título",
    "numero": "número", "Numero": "Número", "NUMERO": "NÚMERO",
    "secao": "seção", "Secao": "Seção",
    "aplicacao": "aplicação", "Aplicacao": "Aplicação",
    "protecao": "proteção", "Protecao": "Proteção",
    "resolucao": "resolução", "Resolucao": "Resolução",
    "classificacao": "classificação", "Classificacao": "Classificação",
    "apresentacao": "apresentação", "Apresentacao": "Apresentação",
    "instrucao": "instrução", "Instrucao": "Instrução",
    "selecao": "seleção", "Selecao": "Seleção",
    "configuracoes": "configurações", "Configuracoes": "Configurações",
    "configuracao": "configuração", "Configuracao": "Configuração",
    "aparencia": "aparência", "Aparencia": "Aparência",
    "simulacoes": "simulações", "Simulacoes": "Simulações",
    "simulacao": "simulação", "Simulacao": "Simulação",
    "proximo": "próximo", "Proximo": "Próximo",
    "proxima": "próxima", "Proxima": "Próxima",
    "alcancado": "alcançado",
    "necessario": "necessário",
    "avancada": "avançada",
    "residencia": "residência", "Residencia": "Residência",
    "nao": "não", "Nao": "Não",
    "sera": "será", "Sera": "Será",
    "ja": "já",
    "ate": "até",
    "etica": "ética",
    "comecar": "começar", "Comecar": "Começar",
    "comecando": "começando",
    "comecou": "começou",
    "comeco": "começo",
    "facil": "fácil", "Facil": "Fácil",
    "dificil": "difícil", "Dificil": "Difícil",
    "revisao": "revisão", "Revisao": "Revisão",
    "diaria": "diária", "Diaria": "Diária",
    "diario": "diário", "Diario": "Diário",
    "calendario": "calendário", "Calendario": "Calendário",
    "pagamento": "pagamento",
    "incluido": "incluído", "Incluido": "Incluído",
    "analise": "análise", "Analise": "Análise",
    "relatorio": "relatório", "Relatorio": "Relatório",
    "servico": "serviço", "Servico": "Serviço",
    "exercicio": "exercício", "Exercicio": "Exercício",
    "horario": "horário", "Horario": "Horário",
    "unico": "único", "Unico": "Único",
    "unica": "única", "Unica": "Única",
    "ultimo": "último", "Ultimo": "Último",
    "ultimos": "últimos", "Ultimos": "Últimos",
    "ultima": "última", "Ultima": "Última",
    "publico": "público", "Publico": "Público",
    "tecnico": "técnico", "Tecnico": "Técnico",
    "especifico": "específico", "Especifico": "Específico",
    "condicao": "condição", "Condicao": "Condição",
    "solucao": "solução", "Solucao": "Solução",
    "geracao": "geração", "Geracao": "Geração",
    "operacao": "operação", "Operacao": "Operação",
    "comunicacao": "comunicação", "Comunicacao": "Comunicação",
    "organizacao": "organização", "Organizacao": "Organização",
    "obrigatorio": "obrigatório", "Obrigatorio": "Obrigatório",
    "responsavel": "responsável", "Responsavel": "Responsável",
    "compativel": "compatível", "Compativel": "Compatível",
    "variavel": "variável", "Variavel": "Variável",
    "acessivel": "acessível", "Acessivel": "Acessível",
    "flexivel": "flexível", "Flexivel": "Flexível",
    "impossivel": "impossível", "Impossivel": "Impossível",
    "beneficio": "benefício", "Beneficio": "Benefício",
    "pagina": "página", "Pagina": "Página",
    "orgao": "órgão", "Orgao": "Órgão",
    "entao": "então", "Entao": "Então",
    "situacao": "situação", "Situacao": "Situação",
    "populacao": "população", "Populacao": "População",
    "musica": "música", "Musica": "Música",
    "saida": "saída", "Saida": "Saída",
    "relacao": "relação", "Relacao": "Relação",
    "comercio": "comércio", "Comercio": "Comércio",
    "cientifico": "científico", "Cientifico": "Científico",
    "eletronico": "eletrônico", "Eletronico": "Eletrônico",
    "organico": "orgânico", "Organico": "Orgânico",
    "economico": "econômico", "Economico": "Econômico",
    "mes": "mês",
    "meses": "meses",
    "basicos": "básicos", "Basicos": "Básicos",
    "basicas": "básicas", "Basicas": "Básicas",
    "serao": "serão", "Serao": "Serão",
    "apos": "após", "Apos": "Após",
    "autorizacao": "autorização", "Autorizacao": "Autorização",
    "praticas": "práticas", "Praticas": "Práticas",
    "praticos": "práticos",
    "medicas": "médicas", "Medicas": "Médicas",
    "medicos": "médicos", "Medicos": "Médicos",
    "clinicas": "clínicas", "Clinicas": "Clínicas",
    "clinicos": "clínicos",
    "academicas": "acadêmicas",
    "especificos": "específicos",
    "tecnicos": "técnicos",
    "atraves": "através", "Atraves": "Através",
    "alem": "além", "Alem": "Além",
    "porem": "porém", "Porem": "Porém",
    "tambem": "também",
    "entao": "então", "Entao": "Então",
    "voces": "vocês", "Voces": "Vocês",
    "sincronizacao": "sincronização", "Sincronizacao": "Sincronização",
}

SORTED_KEYS = sorted(REPLACEMENTS.keys(), key=len, reverse=True)
WORD_PATTERN = re.compile(r'\b(' + '|'.join(re.escape(k) for k in SORTED_KEYS) + r')\b')

# "esta" only when followed by verb forms (gerund/participle/adjective)
ESTA_PATTERN = re.compile(r'\b(esta)\b(?=\s+(?:falando|pronta|pronto|incluido|incluida|incluído|incluída|aqui|disponivel|disponível|usando|fazendo|sendo|indo|vindo|aberto|aberta|ativo|ativa|ativado|correto|correta|errado|errada|vazio|vazia|cheio|cheia|conectado|conectada|funcionando|rodando|carregando|processando|salvo|salva|travado|travada|bloqueado|bloqueada|quebrado|quebrada|habilitado|habilitada|desabilitado|desabilitada))')
ESTA_CAP_PATTERN = re.compile(r'\b(Esta)\b(?=\s+(?:falando|pronta|pronto|incluido|incluída|incluído|incluida|aqui|disponivel|disponível|usando|fazendo|sendo|indo|vindo|aberto|aberta|ativo|ativa|ativado|correto|correta|errado|errada|vazio|vazia|cheio|cheia|conectado|conectada|funcionando|rodando|carregando|processando|salvo|salva|travado|travada|bloqueado|bloqueada|quebrado|quebrada|habilitado|habilitada|desabilitado|desabilitada))')

def fix_text(s):
    def replacer(m):
        return REPLACEMENTS.get(m.group(0), m.group(0))
    result = WORD_PATTERN.sub(replacer, s)
    result = ESTA_PATTERN.sub("está", result)
    result = ESTA_CAP_PATTERN.sub("Está", result)
    return result

BACKSLASH = chr(92)

def extract_strings_and_comments(line):
    """Return list of (start, end, kind) for string literals and comments."""
    spans = []
    i = 0
    n = len(line)
    while i < n:
        if line[i:i+2] == '//':
            spans.append((i, n, 'comment'))
            break
        if line[i] == '"':
            j = i + 1
            while j < n:
                if line[j] == BACKSLASH and j + 1 < n:
                    j += 2
                    continue
                if line[j] == '"':
                    spans.append((i, j + 1, 'string'))
                    i = j + 1
                    break
                j += 1
            else:
                i = j
                continue
            continue
        i += 1
    return spans

def is_api_or_asset(chunk):
    """Return True if string looks like an API path, asset name, or identifier."""
    inner = chunk.strip('"')
    if inner.startswith(("study/", "api/", "portal/", "cron/", "screen/")):
        return True
    if inner.startswith(("tool-", "btn-", "disc-", "icon-", "bg-", "img-")):
        return True
    if inner.startswith("GET ") or inner.startswith("POST "):
        return True
    return False

def is_code_match_context(line, span_start):
    """Return True if string is inside .contains(), .replacingOccurrences(), etc."""
    before = line[:span_start]
    if '.contains(' in before[-20:]:
        return True
    if '.replacingOccurrences(' in before[-40:]:
        return True
    if '.hasPrefix(' in before[-20:]:
        return True
    if '.hasSuffix(' in before[-20:]:
        return True
    if 'lower ==' in before[-15:] or 'lower.contains' in before[-25:]:
        return True
    # difficulty enum values
    if 'difficulty:' in before[-20:] or 'difficulty ==' in before[-25:]:
        return True
    if 'setDifficulty(' in before[-25:]:
        return True
    return False

def is_enum_or_key_value(line, span_start, chunk):
    """Return True if string is used as a key/enum value, not displayed text."""
    inner = chunk.strip('"')
    before = line[:span_start]
    # "facil"/"dificil" as difficulty values (not labels)
    if inner in ("facil", "medio", "dificil"):
        # If preceded by label:, Text(, title: → it's UI text, allow fix
        if 'label:' in before[-15:] or 'Text(' in before[-10:] or 'title:' in before[-15:]:
            return False
        return True  # otherwise it's a key/value
    # "esta" is almost always demonstrative "esta" not verb "está" in code context
    # Only fix when it's clearly a verb: "esta falando", "esta pronta", "esta incluido"
    if inner == "esta":
        return True  # too ambiguous as standalone
    return False

def process_line(line):
    spans = extract_strings_and_comments(line)
    if not spans:
        return line
    result = list(line)
    offset = 0
    for start, end, kind in spans:
        s = start + offset
        e = end + offset
        chunk = ''.join(result[s:e])
        if kind == 'string' and is_api_or_asset(chunk):
            continue
        if kind == 'string' and is_code_match_context(line, start):
            continue
        if kind == 'string' and is_enum_or_key_value(line, start, chunk):
            continue
        fixed = fix_text(chunk)
        if fixed != chunk:
            result[s:e] = list(fixed)
            offset += len(fixed) - len(chunk)
    return ''.join(result)

dry_run = "--dry-run" in sys.argv
base = "/Users/mav/vitaai-ios/VitaAI"
total_fixes = 0
files_fixed = 0

for root, dirs, files in os.walk(base):
    for fname in files:
        if not fname.endswith(".swift"):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, "r", encoding="utf-8") as f:
            lines = f.readlines()
        new_lines = []
        file_fixes = 0
        for i, line in enumerate(lines):
            new_line = process_line(line)
            if new_line != line:
                file_fixes += 1
                if dry_run:
                    print(f"  L{i+1}: {line.rstrip()}")
                    print(f"     -> {new_line.rstrip()}")
            new_lines.append(new_line)
        if file_fixes > 0:
            files_fixed += 1
            total_fixes += file_fixes
            rel = fpath.replace(base + "/", "")
            if dry_run:
                print(f"[DRY] {rel}: {file_fixes} fixes")
            else:
                print(f"OK {rel}: {file_fixes} fixes")
                with open(fpath, "w", encoding="utf-8") as f:
                    f.writelines(new_lines)

print(f"\nTotal: {total_fixes} fixes in {files_fixed} files")
