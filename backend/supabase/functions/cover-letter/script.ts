export type LetterScript = {
  template: string;
  memorySystem: string;
  memory: string;
  letterSystem: string;
  prompt: string;
};

const sectionNames = [
  "template",
  "memory_system",
  "memory",
  "letter_system",
  "prompt",
] as const;

export function readLetterScript(source: string): LetterScript {
  const sections = parseSections(source.replace(/^\uFEFF/, ""));
  const template = need(sections, "template");
  const memorySystem = need(sections, "memory_system");
  const memory = need(sections, "memory");
  const letterSystem = need(sections, "letter_system");
  const prompt = need(sections, "prompt");
  if (!memory.includes("{{resume_text}}")) throw new Error("placeholder");
  for (const token of ["template", "vacancy_description", "candidate_profile"]) {
    if (!prompt.includes(`{{${token}}}`)) throw new Error("placeholder");
  }
  for (const name of sectionNames) {
    if (name === "memory" || name === "prompt") continue;
    if ((sections.get(name) ?? "").includes("{{")) throw new Error("placeholder");
  }
  return { template, memorySystem, memory, letterSystem, prompt };
}

export function fillScript(source: string, values: Record<string, string>): string {
  return source.replace(/\{\{([a-z0-9_]+)\}\}/g, (_token, key: string) => {
    const value = values[key];
    if (value === undefined) throw new Error("placeholder");
    return value;
  });
}

function parseSections(source: string): Map<string, string> {
  const buffers = new Map<string, string[]>();
  let current: string | null = null;
  for (const line of source.split(/\r?\n/)) {
    const heading = /^\[([a-z_]+)\]$/.exec(line.trim());
    if (heading) {
      current = heading[1];
      buffers.set(current, []);
      continue;
    }
    if (!current) continue;
    buffers.get(current)?.push(line);
  }
  const sections = new Map<string, string>();
  for (const [name, lines] of buffers) {
    sections.set(name, lines.join("\n").trim());
  }
  return sections;
}

function need(sections: Map<string, string>, name: string): string {
  const value = sections.get(name)?.trim();
  if (!value) throw new Error(`section ${name}`);
  return value;
}
