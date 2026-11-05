const resumeIdPattern =
  /^(?:resume_id:\s*)?([0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})$/i;

export type RememberedProfile = {
  fullName: string;
  direction: string;
  profile: string;
};

export type KnownResume = {
  id: string;
  fileName: string;
  fullName: string;
  direction: string;
  profile: string;
};

export type WrittenLetter = {
  resumeId: string;
  vacancyTitle: string;
  letter: string;
};

export function rememberedProfile(args: Record<string, unknown>): RememberedProfile | null {
  const fullName = oneLine(args.full_name, 120);
  const direction = oneLine(args.direction, 160);
  const profile = paragraphs(args.profile, 4000);
  if (!fullName || !direction || !profile) return null;
  if (fullName.length < 2 || direction.length < 2 || profile.length < 20) return null;
  if (!/\p{L}/u.test(fullName) || !/\p{L}/u.test(direction)) return null;
  return { fullName, direction, profile };
}

export function vacancyText(value: unknown): string | null {
  const text = paragraphs(value, 8000);
  if (!text || text.length < 10) return null;
  return text;
}

export function candidateProfile(resumes: KnownResume[]): string {
  return resumes.map((resume) =>
    [
      `resume_id: ${resume.id}`,
      `Файл: ${resume.fileName}`,
      `Имя: ${resume.fullName}`,
      `Направление: ${resume.direction}`,
      "Профиль:",
      resume.profile,
    ].join("\n")
  ).join("\n\n");
}

export function coverLetterFromTool(
  args: Record<string, unknown>,
  resumes: KnownResume[],
): WrittenLetter | null {
  const matched = resumeId(args.resume_id);
  const vacancyTitle = oneLine(args.vacancy_title, 160);
  const raw = paragraphs(args.letter, 4000);
  if (!matched || !vacancyTitle || !raw || vacancyTitle.length < 2) return null;
  const resume = resumes.find((item) => item.id.toLowerCase() === matched);
  if (!resume) return null;
  const letter = raw.replaceAll("[Ваше имя]", resume.fullName).trim();
  if (letter.length < 80 || letter.length > 4000) return null;
  return { resumeId: resume.id, vacancyTitle, letter };
}

export function resumeFileName(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const base = value.split(/[/\\]/).pop()?.trim() ?? "";
  if (!base.toLowerCase().endsWith(".docx")) return null;
  if (base.length < 6 || base.length > 180) return null;
  if (/[\u0000-\u001f]/.test(base)) return null;
  return base;
}

function resumeId(value: unknown): string | null {
  const text = oneLine(value, 80);
  if (!text) return null;
  const match = resumeIdPattern.exec(text);
  return match ? match[1].toLowerCase() : null;
}

function oneLine(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const text = clean(value).replace(/\s+/g, " ").trim();
  if (!text || text.length > max) return null;
  return text;
}

function paragraphs(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const text = clean(value)
    .replace(/[ \t]+\n/g, "\n")
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  if (!text || text.length > max) return null;
  return text;
}

function clean(value: string): string {
  return value
    .replace(/\r\n/g, "\n")
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "");
}
