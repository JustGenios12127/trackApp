export type DueInput = {
  when: "today" | "tomorrow" | "in_days" | "weekday" | "date" | "month_day";
  weekday?: string;
  week?: "upcoming" | "next";
  date?: string;
  month?: number;
  day?: number;
  days?: number;
};

const weekdayNumbers: Record<string, number> = {
  monday: 1,
  понедельник: 1,
  пн: 1,
  tuesday: 2,
  вторник: 2,
  вт: 2,
  wednesday: 3,
  среда: 3,
  среду: 3,
  ср: 3,
  thursday: 4,
  четверг: 4,
  чт: 4,
  friday: 5,
  пятница: 5,
  пятницу: 5,
  пт: 5,
  saturday: 6,
  суббота: 6,
  субботу: 6,
  сб: 6,
  sunday: 7,
  воскресенье: 7,
  вс: 7,
};

const longWeekdays = [
  "",
  "понедельник",
  "вторник",
  "среду",
  "четверг",
  "пятницу",
  "субботу",
  "воскресенье",
];

const shortWeekdays = ["", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

const longMonths = [
  "",
  "января",
  "февраля",
  "марта",
  "апреля",
  "мая",
  "июня",
  "июля",
  "августа",
  "сентября",
  "октября",
  "ноября",
  "декабря",
];

const shortMonths = [
  "",
  "янв",
  "фев",
  "мар",
  "апр",
  "мая",
  "июн",
  "июл",
  "авг",
  "сен",
  "окт",
  "ноя",
  "дек",
];

export function isIsoDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

export function addDays(iso: string, days: number): string {
  const [year, month, day] = iso.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

export function isoWeekday(iso: string): number {
  const [year, month, day] = iso.split("-").map(Number);
  const jsDay = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return jsDay === 0 ? 7 : jsDay;
}

export function weekdayNumber(name: string): number | null {
  return weekdayNumbers[name.trim().toLowerCase()] ?? null;
}

export function resolveDueDate(today: string, input: DueInput): string | null {
  if (!isIsoDate(today)) return null;

  if (input.when === "today") return today;
  if (input.when === "tomorrow") return addDays(today, 1);
  if (input.when === "in_days") {
    const days = input.days ?? 0;
    if (days < 1 || days > 366) return null;
    return addDays(today, days);
  }

  if (input.when === "date") {
    return input.date && isIsoDate(input.date) ? input.date : null;
  }

  if (input.when === "month_day") {
    const month = input.month;
    const day = input.day;
    if (!month || !day) return null;
    const year = Number(today.slice(0, 4));
    const thisYear = isoFromParts(year, month, day);
    if (!thisYear) return null;
    if (thisYear >= today) return thisYear;
    return isoFromParts(year + 1, month, day);
  }

  const target = weekdayNumber(input.weekday ?? "");
  if (!target) return null;
  const current = isoWeekday(today);
  let delta = (target - current + 7) % 7;
  if (input.week === "next") {
    delta = delta === 0 ? 7 : delta + 7;
  }
  return addDays(today, delta);
}

export function remindInstant(
  dueOn: string,
  time: string,
  offsetMinutes: number,
): string | null {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(time);
  if (!match || !isIsoDate(dueOn)) return null;
  if (offsetMinutes < -840 || offsetMinutes > 840) return null;
  const [year, month, day] = dueOn.split("-").map(Number);
  const utc = Date.UTC(year, month - 1, day, Number(match[1]), Number(match[2]));
  return new Date(utc - offsetMinutes * 60_000).toISOString();
}

export function localClock(iso: string | null, offsetMinutes: number): string | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  if (Number.isNaN(ms)) return null;
  const local = new Date(ms + offsetMinutes * 60_000);
  const hour = String(local.getUTCHours()).padStart(2, "0");
  const minute = String(local.getUTCMinutes()).padStart(2, "0");
  return `${hour}:${minute}`;
}

export function taskSubtitle(
  today: string,
  dueOn: string,
  remind: string | null,
): string {
  const when = shortWhen(today, dueOn);
  return remind ? `${when} · ${remind}` : when;
}

export function spokenWhen(today: string, dueOn: string): string {
  return longWhen(today, dueOn);
}

export type CalendarPoint = {
  month: number;
  day: number;
  year?: number;
};

export type DateMatch = "due" | "created" | "either";

export function closestMonthDay(
  today: string,
  month: number,
  day: number,
  year?: number,
): string | null {
  if (!isIsoDate(today)) return null;
  if (year) return isoFromParts(year, month, day);
  const current = Number(today.slice(0, 4));
  let best: string | null = null;
  let bestDistance = Number.POSITIVE_INFINITY;
  for (const candidate of [current - 1, current, current + 1]) {
    const iso = isoFromParts(candidate, month, day);
    if (!iso) continue;
    const distance = Math.abs(dayDistance(today, iso));
    const past = iso <= today;
    const bestPast = best !== null && best <= today;
    if (distance < bestDistance || (distance === bestDistance && past && !bestPast)) {
      best = iso;
      bestDistance = distance;
    }
  }
  return best;
}

export function resolveCalendarPoints(today: string, points: CalendarPoint[]): string[] {
  const resolved: string[] = [];
  const open = new Map<number, CalendarPoint[]>();
  for (const point of points) {
    if (point.year) {
      const iso = isoFromParts(point.year, point.month, point.day);
      if (iso) resolved.push(iso);
      continue;
    }
    const group = open.get(point.month) ?? [];
    group.push(point);
    open.set(point.month, group);
  }
  for (const [month, group] of open) {
    const anchor = closestMonthDay(today, month, group[0].day);
    if (!anchor) continue;
    const year = Number(anchor.slice(0, 4));
    for (const point of group) {
      const iso = isoFromParts(year, month, point.day);
      if (iso) resolved.push(iso);
    }
  }
  return [...new Set(resolved)].sort();
}

export function localIsoDate(iso: string | null | undefined, offsetMinutes: number): string | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  if (Number.isNaN(ms) || offsetMinutes < -840 || offsetMinutes > 840) return null;
  return new Date(ms + offsetMinutes * 60_000).toISOString().slice(0, 10);
}

export function fitsDates(
  dueOn: string,
  createdAt: string | null | undefined,
  dates: string[],
  match: DateMatch,
  offsetMinutes: number,
): boolean {
  const due = dueOn.slice(0, 10);
  const created = localIsoDate(createdAt, offsetMinutes);
  if (match === "created") return created !== null && dates.includes(created);
  if (match === "either") {
    return dates.includes(due) || (created !== null && dates.includes(created));
  }
  return dates.includes(due);
}

export function spokenDateList(dates: string[], today?: string): string {
  const unique = [...new Set(dates)].filter(isIsoDate).sort();
  if (unique.length === 0) return "";
  const groups = new Map<string, number[]>();
  for (const iso of unique) {
    const key = iso.slice(0, 7);
    const days = groups.get(key) ?? [];
    days.push(Number(iso.slice(8, 10)));
    groups.set(key, days);
  }
  const parts: string[] = [];
  for (const [key, days] of groups) {
    const month = longMonths[Number(key.slice(5, 7))] ?? "";
    const year = key.slice(0, 4);
    const tail = today && year !== today.slice(0, 4) ? ` ${year}` : "";
    parts.push(`${joinWords(days.map(String))} ${month}${tail}`);
  }
  return joinWords(parts);
}

export function confirmationLine(
  title: string,
  today: string,
  dueOn: string,
  remind: string | null,
): string {
  const when = longWhen(today, dueOn);
  const reminder = remind ? ` Напомню в ${remind}.` : "";
  return `Записал «${title}» на ${when}.${reminder}`;
}

function shortWhen(today: string, dueOn: string): string {
  if (dueOn === today) return "Сегодня";
  if (dueOn === addDays(today, 1)) return "Завтра";
  const day = Number(dueOn.slice(8, 10));
  const month = shortMonths[Number(dueOn.slice(5, 7))] ?? "";
  return `${shortWeekdays[isoWeekday(dueOn)]}, ${day} ${month}`;
}

function longWhen(today: string, dueOn: string): string {
  if (dueOn === today) return "сегодня";
  if (dueOn === addDays(today, 1)) return "завтра";
  const day = Number(dueOn.slice(8, 10));
  const month = longMonths[Number(dueOn.slice(5, 7))] ?? "";
  return `${longWeekdays[isoWeekday(dueOn)]}, ${day} ${month}`;
}

function dayDistance(from: string, to: string): number {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  return Math.round((end - start) / 86_400_000);
}

function joinWords(words: string[]): string {
  if (words.length <= 1) return words[0] ?? "";
  if (words.length === 2) return `${words[0]} и ${words[1]}`;
  return `${words.slice(0, -1).join(", ")} и ${words[words.length - 1]}`;
}

function isoFromParts(year: number, month: number, day: number): string | null {
  const iso = `${String(year).padStart(4, "0")}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
  return isIsoDate(iso) ? iso : null;
}
