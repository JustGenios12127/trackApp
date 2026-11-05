import { resumeText } from "./docx.ts";
import {
  candidateProfile,
  coverLetterFromTool,
  rememberedProfile,
  resumeFileName,
  vacancyText,
  type KnownResume,
} from "./flow.ts";
import { letterSource } from "./letter_text.ts";
import { fillScript, readLetterScript, type LetterScript } from "./script.ts";
import {
  letterTool,
  readToolArguments,
  rememberTool,
  type ToolDefinition,
} from "./tools.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const groqUrl = "https://api.groq.com/openai/v1/chat/completions";
const maxResumes = 5;
const maxFileBytes = 10 * 1024 * 1024;
const maxBase64Length = Math.ceil(maxFileBytes / 3) * 4;

const userIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

class RequestError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

type ResumeRow = {
  id: string;
  file_name: string;
  full_name: string;
  direction: string;
  profile: string;
};

let scriptCache: LetterScript | null = null;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Нужен POST-запрос." }, 405);
  }

  const authorization = req.headers.get("Authorization") ?? "";
  let userId: string;
  try {
    userId = await requireUser(authorization);
  } catch (error) {
    if (error instanceof RequestError) return json({ error: error.message }, error.status);
    return json({ error: "Нужно войти в аккаунт." }, 401);
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Нужен JSON." }, 400);
  }

  const action = readAction(payload);
  if (!action) return json({ error: "Неизвестное действие." }, 400);

  try {
    if (action === "list") return json({ resumes: await listResumes(userId, authorization) });
    if (action === "save") return json({ resume: await saveResume(payload, userId, authorization) });
    if (action === "delete") {
      await deleteResume(payload, userId, authorization);
      return json({ ok: true });
    }
    return json(await writeLetter(payload, userId, authorization));
  } catch (error) {
    return failure(error);
  }
});

async function saveResume(payload: unknown, userId: string, authorization: string) {
  const record = payload as { file_name?: unknown; file_base64?: unknown };
  const fileName = resumeFileName(record.file_name);
  if (!fileName) {
    throw new RequestError("Нужен файл Word с расширением .docx.", 400);
  }
  const bytes = decodeFile(record.file_base64);
  let text: string;
  try {
    text = await resumeText(bytes);
  } catch {
    throw new RequestError(
      "Не удалось прочитать резюме. Нужен обычный документ Word .docx.",
      400,
    );
  }

  const existing = await listResumes(userId, authorization);
  if (existing.length >= maxResumes) {
    throw new RequestError("Можно сохранить не больше 5 резюме. Удали лишнее.", 400);
  }

  const script = loadScript();
  const args = await askTool(
    [
      { role: "system", content: script.memorySystem },
      { role: "user", content: fillScript(script.memory, { resume_text: text }) },
    ],
    rememberTool,
    0.1,
  );
  const memory = rememberedProfile(args);
  if (!memory) {
    throw new RequestError(
      "В резюме не нашлось имени и направления. Проверь файл и загрузи ещё раз.",
      400,
    );
  }

  const inserted = await rest<ResumeRow[]>("resumes", authorization, {
    method: "POST",
    prefer: "return=representation",
    body: {
      user_id: userId,
      file_name: fileName,
      full_name: memory.fullName,
      direction: memory.direction,
      profile: memory.profile,
      source_text: text,
    },
  });
  const row = inserted[0];
  if (!row?.id) throw new Error("db");
  return toClient(row);
}

async function writeLetter(payload: unknown, userId: string, authorization: string) {
  const vacancy = vacancyText((payload as { vacancy?: unknown }).vacancy);
  if (!vacancy) {
    throw new RequestError("Опиши вакансию: роль и чем предстоит заниматься.", 400);
  }
  const resumes = await loadProfiles(userId, authorization);
  if (resumes.length === 0) {
    throw new RequestError("Сначала загрузи резюме в формате Word.", 400);
  }

  const script = loadScript();
  const args = await askTool(
    [
      { role: "system", content: script.letterSystem },
      {
        role: "user",
        content: fillScript(script.prompt, {
          template: script.template,
          vacancy_description: vacancy,
          candidate_profile: candidateProfile(resumes),
        }),
      },
    ],
    letterTool,
    0.4,
  );
  const written = coverLetterFromTool(args, resumes);
  if (!written) {
    throw new RequestError("Ассистент не составил письмо. Попробуй ещё раз.", 502);
  }
  const resume = resumes.find((item) => item.id === written.resumeId);
  if (!resume) throw new RequestError("Ассистент не составил письмо. Попробуй ещё раз.", 502);
  return {
    letter: written.letter,
    vacancy_title: written.vacancyTitle,
    resume: {
      id: resume.id,
      file_name: resume.fileName,
      full_name: resume.fullName,
      direction: resume.direction,
    },
  };
}

async function listResumes(userId: string, authorization: string) {
  const rows = await rest<ResumeRow[]>(
    `resumes?user_id=eq.${userId}&select=id,file_name,full_name,direction&order=created_at.asc&limit=${maxResumes}`,
    authorization,
  );
  return rows.filter(isResumeRow).map(toClient);
}

async function loadProfiles(userId: string, authorization: string): Promise<KnownResume[]> {
  const rows = await rest<ResumeRow[]>(
    `resumes?user_id=eq.${userId}&select=id,file_name,full_name,direction,profile&order=created_at.asc&limit=${maxResumes}`,
    authorization,
  );
  return rows.filter(isProfileRow).map((row) => ({
    id: row.id,
    fileName: row.file_name,
    fullName: row.full_name,
    direction: row.direction,
    profile: row.profile,
  }));
}

async function deleteResume(payload: unknown, userId: string, authorization: string) {
  const id = (payload as { id?: unknown }).id;
  if (typeof id !== "string" || !userIdPattern.test(id)) {
    throw new RequestError("Не нашёл это резюме.", 404);
  }
  const rows = await rest<Array<{ id: string }>>(
    `resumes?id=eq.${id}&user_id=eq.${userId}`,
    authorization,
    { method: "DELETE", prefer: "return=representation" },
  );
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new RequestError("Не нашёл это резюме.", 404);
  }
}

async function askTool(
  messages: Array<{ role: string; content: string }>,
  tool: ToolDefinition,
  temperature: number,
): Promise<Record<string, unknown>> {
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) throw new RequestError("Ассистент сейчас недоступен.", 503);
  const model = Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-20b";
  const body: Record<string, unknown> = {
    model,
    temperature,
    max_tokens: 4096,
    messages,
    tools: [tool],
    tool_choice: { type: "function", function: { name: tool.function.name } },
    parallel_tool_calls: false,
  };
  if (model.startsWith("openai/gpt-oss")) body.reasoning_effort = "low";

  let response: Response;
  try {
    response = await fetch(groqUrl, {
      method: "POST",
      signal: AbortSignal.timeout(50_000),
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch {
    throw new RequestError("Ассистент сейчас недоступен. Попробуй ещё раз.", 502);
  }
  if (!response.ok) {
    console.error("groq status", response.status);
    throw new RequestError("Ассистент сейчас недоступен. Попробуй ещё раз.", 502);
  }
  let data: unknown;
  try {
    data = await response.json();
  } catch {
    throw new RequestError("Ассистент сейчас недоступен. Попробуй ещё раз.", 502);
  }
  try {
    return readToolArguments(data, tool.function.name);
  } catch {
    throw new RequestError("Ассистент прислал непонятный ответ. Попробуй ещё раз.", 502);
  }
}

function loadScript(): LetterScript {
  if (scriptCache) return scriptCache;
  try {
    scriptCache = readLetterScript(letterSource);
  } catch {
    throw new RequestError("Текст письма на сервере настроен неверно.", 500);
  }
  return scriptCache;
}

function decodeFile(value: unknown): Uint8Array {
  if (typeof value !== "string") {
    throw new RequestError("Файл резюме повреждён.", 400);
  }
  const clean = value.replace(/\s/g, "");
  if (!clean || clean.length > maxBase64Length || !/^[A-Za-z0-9+/]+={0,2}$/.test(clean)) {
    throw new RequestError("Файл резюме повреждён.", 400);
  }
  let binary: string;
  try {
    binary = atob(clean);
  } catch {
    throw new RequestError("Файл резюме повреждён.", 400);
  }
  if (binary.length > maxFileBytes) {
    throw new RequestError("Файл слишком большой. Нужен документ до 10 МБ.", 400);
  }
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

async function requireUser(authorization: string): Promise<string> {
  if (!authorization.startsWith("Bearer ")) {
    throw new RequestError("Нужно войти в аккаунт.", 401);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) throw new Error("supabase");
  const response = await fetch(`${url}/auth/v1/user`, {
    headers: { apikey: key, Authorization: authorization },
  });
  if (!response.ok) throw new RequestError("Сессия истекла. Войди снова.", 401);
  const body = await response.json();
  const id = body?.id;
  if (typeof id !== "string" || !userIdPattern.test(id)) {
    throw new RequestError("Сессия истекла. Войди снова.", 401);
  }
  return id;
}

async function rest<T>(
  path: string,
  authorization: string,
  options?: { method?: string; body?: unknown; prefer?: string },
): Promise<T> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) throw new Error("supabase");
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method: options?.method ?? "GET",
    headers: {
      apikey: key,
      Authorization: authorization,
      "Content-Type": "application/json",
      Prefer: options?.prefer ?? "return=minimal",
    },
    body: options?.body === undefined ? undefined : JSON.stringify(options.body),
  });
  if (response.status === 401 || response.status === 403) {
    throw new RequestError("Нет доступа. Войди снова.", 401);
  }
  if (!response.ok) {
    console.error("db status", response.status);
    throw new Error("db");
  }
  if (response.status === 204) return [] as T;
  return await response.json() as T;
}

function readAction(payload: unknown): "list" | "save" | "delete" | "write" | null {
  if (!payload || typeof payload !== "object") return null;
  const action = (payload as { action?: unknown }).action;
  if (action === "list" || action === "save" || action === "delete" || action === "write") {
    return action;
  }
  return null;
}

function isResumeRow(row: ResumeRow): boolean {
  return userIdPattern.test(row.id) &&
    typeof row.file_name === "string" &&
    typeof row.full_name === "string" &&
    typeof row.direction === "string";
}

function isProfileRow(row: ResumeRow): boolean {
  return isResumeRow(row) && typeof row.profile === "string" && row.profile.trim().length > 0;
}

function toClient(row: ResumeRow) {
  return {
    id: row.id,
    file_name: row.file_name,
    full_name: row.full_name,
    direction: row.direction,
  };
}

function failure(error: unknown): Response {
  if (error instanceof RequestError) return json({ error: error.message }, error.status);
  console.error("cover letter failed", error instanceof Error ? error.name : "unknown");
  return json({ error: "Не получилось выполнить запрос. Попробуй ещё раз." }, 502);
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
