import {
  confirmationLine,
  localClock,
  remindInstant,
  resolveDueDate,
  taskSubtitle,
  type DueInput,
} from "./dates.ts";
import {
  extractJson,
  fallbackPlan,
  readPlan,
  reconcilePlan,
  type TaskDraft,
  type TaskPlan,
} from "./parse.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const groqUrl = "https://api.groq.com/openai/v1/chat/completions";
const maxMessages = 20;
const maxContentLength = 4000;

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

type ClientContext = {
  today: string;
  offsetMinutes: number;
};

type StoredTask = {
  id: string;
  title: string;
  subtitle: string;
  remind: boolean;
  remind_at: string | null;
  due_on: string;
};

class RequestError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

const userIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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
    if (error instanceof RequestError) {
      return json({ error: error.message }, error.status);
    }
    return json({ error: "Нужно войти в аккаунт." }, 401);
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Нужен JSON." }, 400);
  }

  const context = readContext(payload);
  if (!context) {
    return json({ error: "Нужна сегодняшняя дата с телефона." }, 400);
  }

  const command = readCommand(payload);
  if (command === "list_tasks") {
    return await safeList(context, userId, authorization);
  }

  const messages = parseMessages(payload);
  if (typeof messages === "string") {
    return json({ error: messages }, 400);
  }

  const last = messages[messages.length - 1].content;
  if (isSlashList(last)) {
    return await safeList(context, userId, authorization);
  }

  try {
    const plan = await understand(messages, context);
    if (!plan || plan.intent === "chat") {
      const reply = plan?.reply || (await chatReply(messages));
      if (!reply) {
        return json({ error: "Ассистент прислал пустой ответ." }, 502);
      }
      return json({ reply, tasks: [], kind: "chat" });
    }

    if (plan.intent === "list") {
      return await safeList(context, userId, authorization);
    }

    const saved = await createTasks(plan.tasks, context, userId, authorization);
    if (saved.length === 0) {
      return json({
        reply: "Не понял, какую задачу записать. Напиши действие, например: запиши задачу сделать уборку.",
        tasks: [],
        kind: "chat",
      });
    }

    const reply = saved.length === 1
      ? confirmationLine(saved[0].title, context.today, saved[0].dueOn, saved[0].remindLabel)
      : `Записал ${saved.length} задачи.`;

    return json({
      reply,
      tasks: saved.map((item) => item.view),
      kind: "created",
    });
  } catch (error) {
    return failure(error, "Не получилось сохранить задачу. Попробуй ещё раз.");
  }
});

async function safeList(
  context: ClientContext,
  userId: string,
  authorization: string,
): Promise<Response> {
  try {
    return json(await listResponse(context, userId, authorization));
  } catch (error) {
    return failure(error, "Не получилось показать задачи. Попробуй ещё раз.");
  }
}

function failure(error: unknown, fallback: string): Response {
  if (error instanceof RequestError) {
    return json({ error: error.message }, error.status);
  }
  console.error("chat failed", error instanceof Error ? error.name : "unknown");
  return json({ error: fallback }, 502);
}

async function understand(messages: ChatMessage[], context: ClientContext): Promise<TaskPlan | null> {
  const last = messages[messages.length - 1].content;
  const local = fallbackPlan(last);
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) {
    return local;
  }

  const model = Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-20b";
  try {
    const content = await askGroq(apiKey, model, [
      { role: "system", content: plannerPrompt(context.today) },
      ...messages,
    ]);
    if (!content) return local;
    return reconcilePlan(last, readPlan(extractJson(content))) ?? local;
  } catch {
    return local;
  }
}

async function chatReply(messages: ChatMessage[]): Promise<string | null> {
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) return "Могу записать задачу или показать список командой /task.";
  const model = Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-20b";
  return askGroq(apiKey, model, [
    {
      role: "system",
      content: "Ты ассистент TrackApp. Отвечай по-русски, коротко. Задачи уже сохраняются отдельно, не проси дату, если её нет.",
    },
    ...messages,
  ]);
}

async function askGroq(
  apiKey: string,
  model: string,
  messages: ChatMessage[],
): Promise<string | null> {
  const response = await fetch(groqUrl, {
    method: "POST",
    signal: AbortSignal.timeout(25_000),
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.1,
      max_tokens: 700,
      reasoning_effort: model.startsWith("openai/gpt-oss") ? "low" : undefined,
      messages,
    }),
  });
  if (!response.ok) {
    console.error("groq status", response.status);
    return null;
  }
  const data = await response.json();
  return readReply(data);
}

async function requireUser(authorization: string): Promise<string> {
  if (!authorization.startsWith("Bearer ")) {
    throw new RequestError("Нужно войти в аккаунт.", 401);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) throw new Error("supabase");

  const response = await fetch(`${url}/auth/v1/user`, {
    headers: {
      apikey: key,
      Authorization: authorization,
    },
  });
  if (!response.ok) {
    throw new RequestError("Сессия истекла. Войди снова.", 401);
  }
  const body = await response.json();
  const id = body?.id;
  if (typeof id !== "string" || !userIdPattern.test(id)) {
    throw new RequestError("Сессия истекла. Войди снова.", 401);
  }
  return id;
}

async function createTasks(
  drafts: TaskDraft[],
  context: ClientContext,
  userId: string,
  authorization: string,
) {
  const rows = [];
  for (const draft of drafts) {
    const dueOn = resolveDueDate(context.today, draft as DueInput);
    const title = draft.title.trim();
    if (!dueOn || !title) continue;
    const remindAt = draft.remind_time
      ? remindInstant(dueOn, draft.remind_time, context.offsetMinutes)
      : null;
    rows.push({
      title,
      due_on: dueOn,
      remind_at: remindAt,
      dueOn,
      remindLabel: draft.remind_time,
    });
  }
  if (rows.length === 0) return [];

  const inserted = await rest<Array<{ id: string; title: string; due_on: string; remind_at: string | null }>>(
    "tasks",
    authorization,
    {
      method: "POST",
      prefer: "return=representation",
      body: rows.map((row) => ({
        user_id: userId,
        title: row.title,
        due_on: row.due_on,
        remind_at: row.remind_at,
      })),
    },
  );

  return inserted.map((row, index) => {
    const remindLabel = localClock(row.remind_at, context.offsetMinutes) ?? rows[index].remindLabel;
    return {
      title: row.title,
      dueOn: row.due_on,
      remindLabel,
      view: toView(row, context),
    };
  });
}

async function listResponse(context: ClientContext, userId: string, authorization: string) {
  const rows = await rest<Array<{ id: string; title: string; due_on: string; remind_at: string | null }>>(
    `tasks?user_id=eq.${userId}&status=eq.open&select=id,title,due_on,remind_at&order=due_on.asc,created_at.asc&limit=100`,
    authorization,
  );
  const tasks = rows.map((row) => toView(row, context));
  return {
    reply: tasks.length === 0 ? "Пока задач нет." : "Все задачи",
    tasks,
    kind: "listed",
  };
}

function toView(
  row: { id: string; title: string; due_on: string; remind_at: string | null },
  context: ClientContext,
): StoredTask {
  const remind = localClock(row.remind_at, context.offsetMinutes);
  return {
    id: row.id,
    title: row.title,
    subtitle: taskSubtitle(context.today, row.due_on, remind),
    remind: remind !== null,
    remind_at: row.remind_at,
    due_on: row.due_on,
  };
}

async function rest<T>(
  path: string,
  authorization: string,
  options?: { method?: string; body?: unknown; prefer?: string },
): Promise<T> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !key) {
    throw new Error("supabase");
  }
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
    throw new RequestError("Нет доступа к задачам. Войди снова.", 401);
  }
  if (!response.ok) {
    console.error("db status", response.status);
    throw new Error("db");
  }
  if (response.status === 204) return [] as T;
  return await response.json() as T;
}

function plannerPrompt(today: string): string {
  return [
    "Ты разбираешь последнюю фразу пользователя для приложения задач TrackApp.",
    `Сегодня по календарю телефона: ${today}. Не выдумывай другую сегодняшнюю дату.`,
    "Верни только JSON без пояснений:",
    '{"intent":"create|list|chat","reply":"","tasks":[{"title":"","when":"today|tomorrow|weekday|date|month_day","weekday":"","week":"upcoming|next","date":"","month":0,"day":0,"remind_time":null}]}',
    "intent=create, если человек просит записать, поставить, добавить или напомнить задачу.",
    "Если дата не названа, when=today. Не спрашивай дату.",
    "День недели: when=weekday, weekday на английском, week=upcoming. Если сказано «следующий вторник», week=next.",
    "«15 октября» — when=month_day. Точная дата YYYY-MM-DD — when=date.",
    "remind_time только если названо время, формат HH:MM. Иначе null.",
    "title — только действие, без даты и без слова «задача».",
    "intent=list, если просит показать задачи.",
    "intent=chat для обычного разговора, reply — короткий ответ по-русски, tasks пустой.",
    "Разбирай только последнее сообщение.",
  ].join(" ");
}

function readContext(payload: unknown): ClientContext | null {
  if (!payload || typeof payload !== "object") return null;
  const today = (payload as { today?: unknown }).today;
  const offset = (payload as { timezone_offset_minutes?: unknown }).timezone_offset_minutes;
  if (typeof today !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(today)) return null;
  if (typeof offset !== "number" || offset < -840 || offset > 840) return null;
  return { today, offsetMinutes: offset };
}

function readCommand(payload: unknown): string | null {
  if (!payload || typeof payload !== "object") return null;
  const command = (payload as { command?: unknown }).command;
  return command === "list_tasks" ? command : null;
}

function parseMessages(payload: unknown): ChatMessage[] | string {
  if (!payload || typeof payload !== "object") return "Нужен JSON с полем messages.";
  const raw = (payload as { messages?: unknown }).messages;
  if (!Array.isArray(raw) || raw.length === 0) return "Напиши сообщение.";
  if (raw.length > maxMessages) return "История сообщений слишком длинная.";

  const messages: ChatMessage[] = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") return "Некорректное сообщение.";
    const role = (item as { role?: unknown }).role;
    const content = (item as { content?: unknown }).content;
    if (role !== "user" && role !== "assistant") return "Некорректная роль сообщения.";
    if (typeof content !== "string" || content.trim().length === 0) return "Пустое сообщение.";
    const text = content.trim();
    if (text.length > maxContentLength) return "Сообщение слишком длинное.";
    messages.push({ role, content: text });
  }
  if (messages[messages.length - 1]?.role !== "user") {
    return "Последнее сообщение должно быть от пользователя.";
  }
  return messages;
}

function isSlashList(text: string): boolean {
  return /^\/tasks?$/.test(text.trim().toLowerCase());
}

function readReply(data: unknown): string | null {
  if (!data || typeof data !== "object") return null;
  const choices = (data as { choices?: unknown }).choices;
  if (!Array.isArray(choices) || choices.length === 0) return null;
  const message = (choices[0] as { message?: unknown }).message;
  if (!message || typeof message !== "object") return null;
  const content = (message as { content?: unknown }).content;
  if (typeof content !== "string") return null;
  const reply = content.trim();
  return reply.length > 0 ? reply : null;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
