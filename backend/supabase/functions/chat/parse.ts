import { weekdayNumber } from "./dates.ts";

export type TaskDraft = {
  title: string;
  when: "today" | "tomorrow" | "in_days" | "weekday" | "date" | "month_day";
  weekday?: string;
  week?: "upcoming" | "next";
  date?: string;
  month?: number;
  day?: number;
  days?: number;
  remind_time?: string | null;
};

export type TaskPlan = {
  intent: "create" | "list" | "chat";
  reply: string;
  tasks: TaskDraft[];
};

const weekdayPattern =
  "понедельник|вторник|сред[уа]|четверг|пятниц[ау]|суббот[уа]|воскресенье";

export function fallbackPlan(text: string): TaskPlan | null {
  const raw = text.trim();
  const lower = raw.toLowerCase();
  if (isListRequest(lower)) {
    return { intent: "list", reply: "", tasks: [] };
  }
  if (!/(запиши|поставь|добавь|создай|напомни)/.test(lower)) return null;

  const weekday = matchWeekday(lower);
  const remind = matchClock(raw);
  const title = cleanupTitle(raw);
  if (!title) return null;

  if (weekday) {
    return {
      intent: "create",
      reply: "",
      tasks: [{
        title,
        when: "weekday",
        weekday: weekday.name,
        week: weekday.week,
        remind_time: remind,
      }],
    };
  }

  if (hasWord(lower, "послезавтра")) {
    return {
      intent: "create",
      reply: "",
      tasks: [{ title, when: "in_days", days: 2, remind_time: remind }],
    };
  }

  if (hasWord(lower, "завтра")) {
    return {
      intent: "create",
      reply: "",
      tasks: [{ title, when: "tomorrow", remind_time: remind }],
    };
  }

  const monthDay = matchMonthDay(lower);
  if (monthDay) {
    return {
      intent: "create",
      reply: "",
      tasks: [{
        title,
        when: "month_day",
        month: monthDay.month,
        day: monthDay.day,
        remind_time: remind,
      }],
    };
  }

  return {
    intent: "create",
    reply: "",
    tasks: [{ title, when: "today", remind_time: remind }],
  };
}

export function readPlan(data: unknown): TaskPlan | null {
  if (!data || typeof data !== "object") return null;
  const record = data as {
    intent?: unknown;
    reply?: unknown;
    tasks?: unknown;
  };
  const intent = record.intent === "create" || record.intent === "list" || record.intent === "chat"
    ? record.intent
    : null;
  if (!intent) return null;
  const tasks = Array.isArray(record.tasks)
    ? record.tasks.map(readDraft).filter((item): item is TaskDraft => item !== null).slice(0, 5)
    : [];
  return {
    intent,
    reply: typeof record.reply === "string" ? record.reply.trim() : "",
    tasks,
  };
}

export function reconcilePlan(text: string, plan: TaskPlan | null): TaskPlan | null {
  const local = fallbackPlan(text);
  if (!plan) return local;
  if (plan.intent === "list" || local?.intent === "list") {
    return { intent: "list", reply: "", tasks: [] };
  }
  if (!local || local.intent !== "create") return plan;
  const localTask = local.tasks[0];
  if (plan.intent !== "create" || plan.tasks.length === 0) {
    return local;
  }

  const task = { ...plan.tasks[0] };
  if (!task.title) task.title = localTask.title;
  if (localTask.when === "today") {
    task.when = "today";
  } else if (localTask.when === "weekday") {
    task.when = "weekday";
    task.weekday = localTask.weekday;
    task.week = localTask.week;
  } else if (localTask.when === "tomorrow" || localTask.when === "in_days" || localTask.when === "month_day") {
    task.when = localTask.when;
    task.days = localTask.days;
    task.month = localTask.month;
    task.day = localTask.day;
  }
  if (localTask.remind_time && !task.remind_time) {
    task.remind_time = localTask.remind_time;
  }
  return { intent: "create", reply: plan.reply, tasks: [task, ...plan.tasks.slice(1)] };
}

export function extractJson(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/);
  const source = fenced ? fenced[1] : trimmed;
  const start = source.indexOf("{");
  const end = source.lastIndexOf("}");
  if (start < 0 || end <= start) {
    throw new Error("json");
  }
  return JSON.parse(source.slice(start, end + 1));
}

function readDraft(value: unknown): TaskDraft | null {
  if (!value || typeof value !== "object") return null;
  const item = value as Record<string, unknown>;
  const title = typeof item.title === "string" ? cleanTitle(item.title) : "";
  const when = item.when;
  if (
    when !== "today" && when !== "tomorrow" && when !== "in_days" && when !== "weekday" &&
    when !== "date" && when !== "month_day"
  ) {
    return title ? { title, when: "today", remind_time: normalizeClock(item.remind_time) } : null;
  }
  return {
    title,
    when,
    weekday: typeof item.weekday === "string" ? item.weekday : undefined,
    week: item.week === "next" ? "next" : "upcoming",
    date: typeof item.date === "string" ? item.date : undefined,
    month: typeof item.month === "number" ? item.month : undefined,
    day: typeof item.day === "number" ? item.day : undefined,
    days: typeof item.days === "number" ? item.days : undefined,
    remind_time: normalizeClock(item.remind_time),
  };
}

function isListRequest(lower: string): boolean {
  return /^(?:\/tasks?|покажи(?:те)?(?:\s+все)?(?:\s+мои)?\s+задачи?|все(?:\s+мои)?\s+задачи?|список\s+задач|мои\s+задачи)(?![\p{L}\p{N}_])/u.test(
    lower,
  );
}

function matchWeekday(lower: string): { name: string; week: "upcoming" | "next" } | null {
  const match = new RegExp(
    `(следующ(?:ий|ую|ее)\\s+)?(${weekdayPattern})`,
    "i",
  ).exec(lower);
  if (!match) return null;
  const name = match[2].toLowerCase();
  if (!weekdayNumber(name)) return null;
  return { name, week: match[1] ? "next" : "upcoming" };
}

function matchClock(text: string): string | null {
  const match = /(?:напомни(?:ть)?(?:\s+мне)?(?:\s+в)?|(?:^|\s)в)\s*(\d{1,2})[:.](\d{2})/i.exec(text);
  if (!match) return null;
  return padClock(Number(match[1]), Number(match[2]));
}

function matchMonthDay(lower: string): { month: number; day: number } | null {
  const months: Record<string, number> = {
    января: 1,
    февраля: 2,
    марта: 3,
    апреля: 4,
    мая: 5,
    июня: 6,
    июля: 7,
    августа: 8,
    сентября: 9,
    октября: 10,
    ноября: 11,
    декабря: 12,
  };
  const match = /(\d{1,2})\s+(января|февраля|марта|апреля|мая|июня|июля|августа|сентября|октября|ноября|декабря)/.exec(
    lower,
  );
  if (!match) return null;
  return { day: Number(match[1]), month: months[match[2]] };
}

function cleanupTitle(raw: string): string {
  let title = raw.replace(/^(запиши|поставь|добавь|создай)\s+(?:задачу\s+)?/i, "");
  title = title.replace(wordPattern("напомни(?:ть)?(?:\\s+мне)?(?:\\s+в)?\\s*\\d{1,2}[:.]\\d{2}"), " ");
  title = title.replace(wordPattern("в\\s*\\d{1,2}[:.]\\d{2}"), " ");
  title = title.replace(
    wordPattern(`(?:на|во|в)\\s+(?:следующ(?:ий|ую|ее)\\s+)?(?:${weekdayPattern})`),
    " ",
  );
  title = title.replace(wordPattern("на\\s+\\d{1,2}\\s+[а-яё]+"), " ");
  title = title.replace(wordPattern("сегодня|завтра|послезавтра"), " ");
  title = title.replace(wordPattern("задачу"), " ");
  title = title.replace(wordPattern("напомни(?:ть)?(?:\\s+мне)?"), " ");
  title = title.replace(/\s+и\s+/gi, " ");
  return cleanTitle(title);
}

function cleanTitle(value: string): string {
  const compact = value.replace(/[«»"]/g, "").replace(/\s+/g, " ").replace(/^[\s,.\-—:]+|[\s,.\-—:]+$/g, "").trim();
  if (!compact) return "";
  const sliced = compact.slice(0, 200);
  return sliced.charAt(0).toUpperCase() + sliced.slice(1);
}

function normalizeClock(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return null;
  return padClock(Number(match[1]), Number(match[2]));
}

function hasWord(text: string, pattern: string): boolean {
  return wordPattern(pattern).test(text);
}

function wordPattern(pattern: string): RegExp {
  return new RegExp(`(?<![\\p{L}\\p{N}_])(?:${pattern})(?![\\p{L}\\p{N}_])`, "giu");
}

function padClock(hour: number, minute: number): string | null {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}
