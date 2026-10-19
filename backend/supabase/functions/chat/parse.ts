import { isIsoDate, weekdayNumber, type CalendarPoint, type DateMatch } from "./dates.ts";

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

export type DeleteScope = "title" | "day" | "days" | "all" | "unclear";

export type DeleteTarget = {
  scope: DeleteScope;
  title: string;
  dated: boolean;
  when: TaskDraft["when"];
  weekday?: string;
  week?: "upcoming" | "next";
  date?: string;
  month?: number;
  day?: number;
  days?: number;
  points?: CalendarPoint[];
  match?: DateMatch;
};

export type TaskPlan = {
  intent: "create" | "list" | "chat" | "delete";
  reply: string;
  tasks: TaskDraft[];
  remove?: DeleteTarget;
};

const weekdayPattern =
  "понедельник|вторник|сред[уа]|четверг|пятниц[ау]|суббот[уа]|воскресенье";

const deleteVerb =
  "удал(?:ите|ить|и)|убер(?:ите|и|ать)|сотр(?:ите|и)|стереть|отмен(?:ите|ить|и)";
const createVerb = "запиши|поставь|добавь|создай|напомни(?:ть)?";

export function fallbackPlan(text: string): TaskPlan | null {
  const raw = text.trim();
  const lower = raw.toLowerCase();
  if (isListRequest(lower)) {
    return { intent: "list", reply: "", tasks: [] };
  }
  if (asksToDelete(lower)) {
    return deletePlan(lower);
  }
  if (!wordPattern(createVerb).test(lower)) return null;

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
    scope?: unknown;
    match?: unknown;
  };
  const intent = record.intent === "create" || record.intent === "list" ||
      record.intent === "chat" || record.intent === "delete"
    ? record.intent
    : null;
  if (!intent) return null;
  const tasks = Array.isArray(record.tasks)
    ? record.tasks.map(readDraft).filter((item): item is TaskDraft => item !== null).slice(0, 5)
    : [];
  if (intent === "delete") return readDelete(record, tasks);
  return {
    intent,
    reply: typeof record.reply === "string" ? record.reply.trim() : "",
    tasks,
  };
}

export function reconcilePlan(text: string, plan: TaskPlan | null): TaskPlan | null {
  const local = fallbackPlan(text);
  if (asksToDelete(text)) {
    if (local?.intent === "delete" && local.remove?.scope !== "unclear") return local;
    if (plan?.intent === "delete" && plan.remove && plan.remove.scope !== "unclear") return plan;
    return local ?? unclearDelete();
  }
  if (!plan) return local;
  if (plan.intent === "delete") {
    return local ?? {
      intent: "chat",
      reply: "Могу записать задачу, показать список командой /task или удалить задачу по названию.",
      tasks: [],
    };
  }
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

export function matchingTitles<T extends { title: string }>(rows: T[], query: string): T[] {
  const needle = fold(query);
  if (needle.length < 2) return [];
  const exact = rows.filter((row) => fold(row.title) === needle);
  if (exact.length > 0) return exact;
  return rows.filter((row) => fold(row.title).includes(needle) || wordsFit(fold(row.title), needle));
}

function asksToDelete(text: string): boolean {
  const lower = text.trim().toLowerCase();
  const deleting = wordIndex(lower, deleteVerb);
  if (deleting < 0) return false;
  const creating = wordIndex(lower, createVerb);
  return creating < 0 || deleting < creating;
}

function deletePlan(lower: string): TaskPlan {
  const rest = lower.replace(wordPattern(deleteVerb), " ").replace(/\s+/g, " ").trim();
  const taken = takeDates(rest);
  const points = taken.points;
  const weekday = points.length === 0 ? matchWeekday(rest) : null;
  const afterTomorrow = points.length === 0 && hasWord(rest, "послезавтра");
  const tomorrow = points.length === 0 && !afterTomorrow && hasWord(rest, "завтра");
  const todayWord = points.length === 0 && hasWord(rest, "сегодня");
  const dated = points.length > 0 || Boolean(weekday || afterTomorrow || tomorrow || todayWord);
  const title = cleanupDeleteTitle(taken.rest);
  const wholeList = /^(?:все(?:\s+задачи)?|мои(?:\s+задачи)?|задачи|задача|задачу)$/u.test(rest);

  let scope: DeleteScope = "unclear";
  if (points.length > 1 && !title) {
    scope = "days";
  } else if (dated && (!title || wholeList || /^(?:все|мои)(?![\p{L}\p{N}_])/u.test(rest))) {
    scope = "day";
  } else if (title) {
    scope = "title";
  } else if (wholeList) {
    scope = "all";
  }

  const first = points[0];
  return {
    intent: "delete",
    reply: "",
    tasks: [],
    remove: {
      scope,
      title,
      dated: scope === "day" || scope === "days" || (scope === "title" && dated),
      when: points.length > 0
        ? "month_day"
        : weekday
        ? "weekday"
        : afterTomorrow
        ? "in_days"
        : tomorrow
        ? "tomorrow"
        : "today",
      weekday: weekday?.name,
      week: weekday?.week,
      month: first?.month,
      day: first?.day,
      days: afterTomorrow ? 2 : undefined,
      points: points.length > 0 ? points : undefined,
      match: dateMatch(rest, points.length > 0),
    },
  };
}

function unclearDelete(): TaskPlan {
  return {
    intent: "delete",
    reply: "",
    tasks: [],
    remove: { scope: "unclear", title: "", dated: false, when: "today" },
  };
}

function readDelete(
  record: { scope?: unknown; match?: unknown },
  tasks: TaskDraft[],
): TaskPlan {
  const draft = tasks[0];
  const points = pointsOf(tasks);
  let scope: DeleteScope = record.scope === "title" || record.scope === "day" ||
      record.scope === "days" || record.scope === "all"
    ? record.scope
    : draft?.title
    ? "title"
    : "unclear";
  if (scope !== "title" && scope !== "all" && points.length > 1) scope = "days";
  const dated = scope === "day" || scope === "days" || (draft != null && draft.when !== "today");
  return {
    intent: "delete",
    reply: "",
    tasks: [],
    remove: {
      scope,
      title: scope === "title" ? draft?.title ?? "" : "",
      dated,
      when: draft?.when ?? (points.length > 0 ? "month_day" : "today"),
      weekday: draft?.weekday,
      week: draft?.week,
      date: draft?.date,
      month: draft?.month ?? points[0]?.month,
      day: draft?.day ?? points[0]?.day,
      days: draft?.days,
      points: points.length > 0 ? points : undefined,
      match: readMatch(record.match),
    },
  };
}

function readMatch(value: unknown): DateMatch {
  if (value === "created" || value === "either" || value === "due") return value;
  return "due";
}

function pointsOf(tasks: TaskDraft[]): CalendarPoint[] {
  const points: CalendarPoint[] = [];
  for (const task of tasks) {
    if (task.when === "month_day" && task.month && task.day) {
      points.push({ month: task.month, day: task.day });
    } else if (task.when === "date" && task.date && isIsoDate(task.date)) {
      points.push({
        year: Number(task.date.slice(0, 4)),
        month: Number(task.date.slice(5, 7)),
        day: Number(task.date.slice(8, 10)),
      });
    }
  }
  return dedupePoints(points);
}

function cleanupDeleteTitle(rest: string): string {
  let title = rest.replace(/^(?:все\s+)?(?:мои\s+)?(?:задачи|задача|задачу)\s+/i, "");
  title = title.replace(/^все\s+/i, "");
  title = title.replace(
    wordPattern(`(?:на|во|в|про)\\s+(?:следующ(?:ий|ую|ее)\\s+)?(?:${weekdayPattern})`),
    " ",
  );
  title = title.replace(wordPattern(weekdayPattern), " ");
  title = title.replace(wordPattern("на\\s+\\d{1,2}(?:\\s*-?\\s*го)?\\s+[а-яё]+"), " ");
  title = title.replace(wordPattern("сегодня|завтра|послезавтра"), " ");
  title = title.replace(wordPattern("\\d{4}-\\d{2}-\\d{2}"), " ");
  title = title.replace(
    wordPattern(
      "которые|который|которая|которое|были|была|был|было|что|это|именно|только|мне|мной",
    ),
    " ",
  );
  title = title.replace(
    wordPattern(`${placedWords}|${createdWords}`),
    " ",
  );
  title = title.replace(wordPattern("все|мои|задач[ауи]"), " ");
  const cleaned = cleanTitle(title);
  if (/^(?:про|на|во|в|к|ко|по|за|от|до|из|и|а)$/i.test(cleaned)) return "";
  return cleaned;
}

const placedWords = "поставлен\\p{L}*|поставил\\p{L}*|ставил\\p{L}*|запланирован\\p{L}*|назначен\\p{L}*";
const createdWords = "создан\\p{L}*|создал\\p{L}*|добавлен\\p{L}*|добавил\\p{L}*|записан\\p{L}*|записал\\p{L}*";

function dateMatch(text: string, hasPoints: boolean): DateMatch {
  const created = hasWord(text, createdWords);
  const placed = hasWord(text, placedWords);
  if (!hasPoints && !created && !placed) return "due";
  if (created && !placed) return "created";
  if (placed && !hasWord(text, "на")) return "either";
  return "due";
}

const monthNames: Record<string, number> = {
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

function takeDates(text: string): { points: CalendarPoint[]; rest: string } {
  const points: CalendarPoint[] = [];
  const months = Object.keys(monthNames).join("|");
  const day = "\\d{1,2}(?:\\s*-?\\s*го)?";
  let source = text;

  source = source.replace(
    new RegExp(
      `(?:с\\s+)?(${day})\\s*(?:-|–|—|по)\\s*(${day})\\s+(${months})(?:\\s+(\\d{4}))?(?:\\s+года)?`,
      "giu",
    ),
    (_full, fromRaw: string, toRaw: string, monthName: string, year?: string) => {
      const month = monthNames[monthName.toLowerCase()];
      const from = dayNumber(fromRaw);
      const to = dayNumber(toRaw);
      const namedYear = year ? Number(year) : undefined;
      if (month && from && to && from <= to && to - from <= 30) {
        for (let item = from; item <= to; item++) {
          points.push(namedYear ? { month, day: item, year: namedYear } : { month, day: item });
        }
      }
      return " ";
    },
  );

  source = source.replace(
    new RegExp(
      `((?:${day}\\s*(?:,|и)\\s*)+${day})\\s+(${months})(?:\\s+(\\d{4}))?(?:\\s+года)?`,
      "giu",
    ),
    (_full, rawList: string, monthName: string, year?: string) => {
      const month = monthNames[monthName.toLowerCase()];
      const namedYear = year ? Number(year) : undefined;
      if (month) {
        for (const part of rawList.split(/\s*(?:,|и)\s*/)) {
          const value = dayNumber(part);
          if (value) {
            points.push(namedYear ? { month, day: value, year: namedYear } : { month, day: value });
          }
        }
      }
      return " ";
    },
  );

  source = source.replace(
    new RegExp(`(${day})\\s+(${months})(?:\\s+(\\d{4}))?(?:\\s+года)?`, "giu"),
    (_full, rawDay: string, monthName: string, year?: string) => {
      const month = monthNames[monthName.toLowerCase()];
      const value = dayNumber(rawDay);
      if (month && value) {
        const namedYear = year ? Number(year) : undefined;
        points.push(namedYear ? { month, day: value, year: namedYear } : { month, day: value });
      }
      return " ";
    },
  );

  source = source.replace(/\d{4}-\d{2}-\d{2}/g, (value) => {
    if (!isIsoDate(value)) return value;
    points.push({
      year: Number(value.slice(0, 4)),
      month: Number(value.slice(5, 7)),
      day: Number(value.slice(8, 10)),
    });
    return " ";
  });

  return {
    points: dedupePoints(points),
    rest: source.replace(/\s+/g, " ").trim(),
  };
}

function dayNumber(raw: string): number | null {
  const match = /(\d{1,2})/.exec(raw);
  if (!match) return null;
  const value = Number(match[1]);
  if (value < 1 || value > 31) return null;
  return value;
}

function dedupePoints(points: CalendarPoint[]): CalendarPoint[] {
  const seen = new Set<string>();
  const result: CalendarPoint[] = [];
  for (const point of points) {
    const key = `${point.year ?? ""}-${point.month}-${point.day}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(point);
    if (result.length >= 31) break;
  }
  return result;
}

function wordsFit(task: string, needle: string): boolean {
  const words = needle.split(" ").filter((word) => word.length > 2);
  return words.length > 0 && words.every((word) => task.includes(word));
}

function fold(value: string): string {
  return value
    .toLowerCase()
    .replace(/ё/g, "е")
    .replace(/[^a-zа-я0-9\s]/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function wordIndex(text: string, pattern: string): number {
  const match = wordPattern(pattern).exec(text);
  return match?.index ?? -1;
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
