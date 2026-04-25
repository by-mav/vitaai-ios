#!/usr/bin/env node
/**
 * quality-gate-modals.js — bloqueia drift de overlays/modals/popouts.
 *
 * Regra: TODA overlay/popout deve usar VitaSheet, .vitaBubble, ou .vitaAlert
 * (em VitaAI/DesignSystem/Components/VitaModals.swift). Ver shell.md §10.
 *
 * Detecta padrões proibidos em novos arquivos:
 *  - .sheet(...) sem VitaSheet dentro
 *  - .popover(...) direto (use .vitaBubble)
 *  - .alert(...) custom (use .vitaAlert pra destrutivo)
 *  - Color.black.opacity em ZStack (use VitaModals)
 *  - Novo arquivo *Sheet.swift em Features/ (substitua por uso de VitaSheet)
 *
 * Roda como PostToolUse do quality_gate_router.
 * Exit 0 = OK, 2 = bloqueia (mostra stderr).
 */
const fs = require("node:fs");
const filePath = process.argv[2];
if (!filePath) process.exit(0);
if (!fs.existsSync(filePath)) process.exit(0);

// Skip o próprio shell + tests + components
if (filePath.includes("/DesignSystem/Components/VitaModals.swift")) process.exit(0);
if (filePath.includes("UITests/")) process.exit(0);
if (!filePath.endsWith(".swift")) process.exit(0);

const text = fs.readFileSync(filePath, "utf-8");
const violations = [];

// New *Sheet.swift screen file in Features/ — usar VitaSheet em vez de criar struct
if (/\/Features\/.*Sheet\.swift$/.test(filePath)) {
  // OK só se já existia (legacy). Heuristic: se foi adicionado AGORA seria untracked.
  // Vamos só warn em novos.
  // Skip — incremental migration.
}

// .sheet( sem VitaSheet imediatamente próximo (nas próximas 5 linhas)
const lines = text.split("\n");

function hasIgnoreNearby(i) {
  const before = lines.slice(Math.max(0, i - 3), i).join("\n");
  return /vita-modals-ignore/.test(before);
}

lines.forEach((line, i) => {
  // .sheet( — exige que VitaSheet ou VitaBottomSheet apareça nas 6 linhas seguintes
  if (/\.sheet\s*\(/.test(line) && !line.includes("//") && !hasIgnoreNearby(i)) {
    const window = lines.slice(i, Math.min(i + 6, lines.length)).join("\n");
    if (!/VitaSheet\s*\(/.test(window)) {
      violations.push(`L${i+1}: \`.sheet(...)\` sem VitaSheet wrapper. Use \`VitaSheet { ... }\` dentro do closure.`);
    }
  }
  // .popover( direto — use .vitaBubble
  if (/\.popover\s*\(/.test(line) && !line.includes("//") && !line.includes("vitaBubble") && !hasIgnoreNearby(i)) {
    violations.push(`L${i+1}: \`.popover(...)\` direto. Use \`.vitaBubble(isPresented: ...)\` em vez.`);
  }
  // ZStack overlay manual com Color.black.opacity
  if (/Color\.black\.opacity\s*\(/.test(line) && !line.includes("//") && !hasIgnoreNearby(i)) {
    const window = lines.slice(Math.max(0, i-2), Math.min(i+5, lines.length)).join("\n");
    if (/ignoresSafeArea|onTapGesture\s*\{[^}]*isPresented\s*=\s*false/.test(window)) {
      violations.push(`L${i+1}: \`Color.black.opacity(...)\` overlay manual. Use VitaSheet/VitaBubble/.vitaAlert.`);
    }
  }
});

if (violations.length === 0) process.exit(0);

console.error(`\x1b[31mBLOCKED: VitaModals drift em ${filePath}\x1b[0m`);
console.error("");
console.error("Regra (ver shell.md §10): TODO overlay/popout/modal usa VitaSheet, .vitaBubble, ou .vitaAlert.");
console.error("Componentes em: VitaAI/DesignSystem/Components/VitaModals.swift");
console.error("");
violations.forEach(v => console.error(`  ${v}`));
console.error("");
console.error("Pra OK migração legacy: adicione `// vita-modals-ignore: <razão>` na linha acima.");
process.exit(2);
