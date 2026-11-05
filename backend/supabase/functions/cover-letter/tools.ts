export type ToolDefinition = {
  type: "function";
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
};

export const rememberTool: ToolDefinition = {
  type: "function",
  function: {
    name: "remember_resume",
    description: "Запоминает профиль кандидата после чтения резюме.",
    parameters: {
      type: "object",
      properties: {
        full_name: {
          type: "string",
          description: "Имя и фамилия из резюме.",
        },
        direction: {
          type: "string",
          description: "Короткое направление работы без перечисления технологий.",
        },
        profile: {
          type: "string",
          description: "Краткий профиль: имя и реальные направления опыта.",
        },
      },
      required: ["full_name", "direction", "profile"],
    },
  },
};

export const letterTool: ToolDefinition = {
  type: "function",
  function: {
    name: "submit_cover_letter",
    description: "Передаёт готовое сопроводительное письмо и выбранное резюме.",
    parameters: {
      type: "object",
      properties: {
        resume_id: {
          type: "string",
          description: "Идентификатор одного резюме из задания.",
        },
        vacancy_title: {
          type: "string",
          description: "Короткое название роли из описания вакансии.",
        },
        letter: {
          type: "string",
          description: "Готовое сопроводительное письмо целиком.",
        },
      },
      required: ["resume_id", "vacancy_title", "letter"],
    },
  },
};

export function readToolArguments(data: unknown, name: string): Record<string, unknown> {
  if (!data || typeof data !== "object") throw new Error("tool");
  const choices = (data as { choices?: unknown }).choices;
  if (!Array.isArray(choices) || choices.length === 0) throw new Error("tool");
  const choice = choices[0];
  if (!choice || typeof choice !== "object") throw new Error("tool");
  if ((choice as { finish_reason?: unknown }).finish_reason === "length") {
    throw new Error("tool");
  }
  const message = (choice as { message?: unknown }).message;
  if (!message || typeof message !== "object") throw new Error("tool");
  for (const call of callsOf(message)) {
    if (call.name !== name) continue;
    const parsed = parseArgs(call.arguments);
    if (parsed) return parsed;
  }
  throw new Error("tool");
}

function callsOf(message: object): Array<{ name: string; arguments: unknown }> {
  const modern = (message as { tool_calls?: unknown }).tool_calls;
  const found: Array<{ name: string; arguments: unknown }> = [];
  if (Array.isArray(modern)) {
    for (const call of modern) {
      if (!call || typeof call !== "object") continue;
      const fn = (call as { function?: unknown }).function;
      if (!fn || typeof fn !== "object") continue;
      const name = (fn as { name?: unknown }).name;
      if (typeof name !== "string") continue;
      found.push({ name, arguments: (fn as { arguments?: unknown }).arguments });
    }
  }
  const legacy = (message as { function_call?: unknown }).function_call;
  if (legacy && typeof legacy === "object") {
    const name = (legacy as { name?: unknown }).name;
    if (typeof name === "string") {
      found.push({ name, arguments: (legacy as { arguments?: unknown }).arguments });
    }
  }
  return found;
}

function parseArgs(value: unknown): Record<string, unknown> | null {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (!text) return null;
  const direct = objectFromJson(text);
  if (direct) return direct;
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  return objectFromJson(text.slice(start, end + 1));
}

function objectFromJson(text: string): Record<string, unknown> | null {
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
    return parsed as Record<string, unknown>;
  } catch {
    return null;
  }
}
