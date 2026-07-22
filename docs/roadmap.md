# Fivetech - OpenCode Custom Build Roadmap

## Objetivo

Personalizar OpenCode como una herramienta interna de Fivetech con identidad propia.

## Cambios realizados

### 1. Sufijo de versión `-fivetech`
**Archivo:** `packages/core/src/installation/version.ts`

```ts
// Antes
export const InstallationVersion = typeof OPENCODE_VERSION === "string" ? OPENCODE_VERSION : "local"

// Ahora
export const InstallationVersion = typeof OPENCODE_VERSION === "string" ? `${OPENCODE_VERSION}-fivetech` : "local"
```

**Resultado:** La versión ahora se muestra como `OpenCode 0.0.0-dev-202607222006-fivetech`

### 2. Límite de pasos del agente: 1000 → 5000
**Archivo:** `packages/opencode/src/session/prompt.ts`

```ts
// Antes
const maxSteps = agent.steps ?? 1000

// Ahora
const maxSteps = agent.steps ?? 5000
```

**Resultado:** Los agentes pueden ejecutar hasta 5000 pasos de herramientas antes de detenerse. Esto permite tareas más complejas sin interrupciones.

### 3. Primer commit: límite Infinity → 1000
**Archivo:** `packages/opencode/src/session/prompt.ts`

```ts
// Antes
const maxSteps = agent.steps ?? Infinity

// Ahora (posteriormente cambiado a 5000)
const maxSteps = agent.steps ?? 1000
```

## Arquitectura de OpenCode (lo que descubrimos)

### Versión
- La versión se genera en `packages/script/src/index.ts` para builds de preview
- Se inyecta como constante global `OPENCODE_VERSION` durante el build
- Se expone via `packages/core/src/installation/version.ts`

### Límite de pasos (MAX_STEPS)
- Cada "turno" del agente = 1 paso
- OpenCode cuenta los pasos en `prompt.ts` con `step++`
- Cuando `step >= maxSteps`, inyecta `MAX_STEPS_PROMPT` como mensaje del sistema
- El LLM obedece y responde solo con texto
- El prompt está en `packages/core/src/session/runner/max-steps.ts`
- **No es un límite de Vercel/AI SDK** — es 100% lógica de OpenCode

### Proveedores de IA
OpenCode usa el **Vercel AI SDK** para conectarse a múltiples proveedores:
- OpenAI, Anthropic, Google, xAI, Groq, Mistral, etc.
- Cada proveedor tiene su paquete SDK (ej: `@ai-sdk/openai`)
- Los proveedores se cargan dinámicamente en `packages/opencode/src/provider/provider.ts`
- Los modelos se definen en la configuración del usuario

### Agentes built-in
| Agente | Modo | Descripción |
|--------|------|-------------|
| `build` | primary | Agente por defecto, ejecuta herramientas |
| `plan` | primary | Modo plan, solo lectura |
| `general` | subagent | Tareas generales multi-paso |
| `explore` | subagent | Exploración rápida de código |
| `compaction` | subagent | Compactación de contexto |

Ninguno tiene `steps` configurado explícitamente, todos usan el default (5000).

## Commits realizados

1. `fix(session): limit max steps to 1000 instead of Infinity`
2. `chore: add fivetech suffix and increase max steps to 5000`

## Próximos pasos potenciales

- [ ] Configurar un proveedor de IA personalizado (ej: un modelo local o privado)
- [ ] Personalizar el system prompt por defecto de los agentes
- [ ] Agregar un agente personalizado para Fivetech
- [ ] Configurar permisos por defecto para los agentes
- [ ] Personalizar la UI (colores, branding)
- [ ] Configurar MCP servers específicos para Fivetech
- [ ] Investigar cómo configurar el agente default en `.opencode/config.json`

## Comandos útiles

```bash
# Desarrollo local
bun dev

# Build
bun run --cwd packages/opencode script/build.ts

# Typecheck
bun typecheck

# Reemplazar binario en PC
Copy-Item "packages\opencode\dist\opencode-windows-x64\bin\opencode.exe" "$env:APPDATA\npm\node_modules\opencode-ai\bin\opencode.exe" -Force
```
