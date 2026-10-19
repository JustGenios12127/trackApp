import assert from "node:assert/strict";

import {
  closestMonthDay,
  fitsDates,
  remindInstant,
  resolveCalendarPoints,
  resolveDueDate,
  spokenDateList,
} from "../functions/chat/dates.ts";
import { fallbackPlan, matchingTitles, reconcilePlan } from "../functions/chat/parse.ts";

const today = "2026-10-13";

function due(text: string) {
  const plan = fallbackPlan(text);
  assert.equal(plan?.intent, "create");
  const task = plan!.tasks[0];
  return {
    title: task.title,
    due: resolveDueDate(today, task),
    remind: task.remind_time ?? null,
  };
}

assert.deepEqual(due("запиши задачу сделать уборку"), {
  title: "Сделать уборку",
  due: "2026-10-13",
  remind: null,
});

assert.deepEqual(due("Запиши задачу на вторник постирать вещи"), {
  title: "Постирать вещи",
  due: "2026-10-13",
  remind: null,
});

assert.deepEqual(due("Поставь задачу постирать вещи на пятницу и напомни в 14:00"), {
  title: "Постирать вещи",
  due: "2026-10-16",
  remind: "14:00",
});

assert.equal(
  resolveDueDate(today, { when: "weekday", weekday: "monday", week: "upcoming" }),
  "2026-10-19",
);

assert.equal(
  resolveDueDate(today, { when: "weekday", weekday: "tuesday", week: "next" }),
  "2026-10-20",
);

assert.equal(
  remindInstant("2026-10-16", "14:00", 300),
  "2026-10-16T09:00:00.000Z",
);

assert.equal(fallbackPlan("/task")?.intent, "list");
assert.equal(fallbackPlan("покажи все мои задачи")?.intent, "list");
assert.equal(fallbackPlan("привет"), null);

const byTitle = fallbackPlan("удали задачу сходить в магазин");
assert.equal(byTitle?.intent, "delete");
assert.equal(byTitle?.remove?.scope, "title");
assert.equal(byTitle?.remove?.title, "Сходить в магазин");
assert.equal(byTitle?.remove?.dated, false);

const byDay = fallbackPlan("удали все задачи на пятницу");
assert.equal(byDay?.intent, "delete");
assert.equal(byDay?.remove?.scope, "day");
assert.equal(resolveDueDate(today, byDay!.remove!), "2026-10-16");

assert.equal(fallbackPlan("удали задачи на пятницу")?.remove?.scope, "day");
assert.equal(fallbackPlan("удали все задачи")?.remove?.scope, "all");
assert.equal(fallbackPlan("удали")?.remove?.scope, "unclear");
assert.equal(fallbackPlan("запиши задачу удалить фото")?.intent, "create");

const lied = reconcilePlan("удали задачу сходить в магазин", {
  intent: "chat",
  reply: "Удалил задачу.",
  tasks: [],
});
assert.equal(lied?.intent, "delete");
assert.equal(lied?.remove?.title, "Сходить в магазин");

const rows = [
  { title: "Сходить в магазин" },
  { title: "Сходить в магазин вечером" },
  { title: "Купить хлеб" },
];
assert.deepEqual(
  matchingTitles(rows, "Сходить в магазин").map((row) => row.title),
  ["Сходить в магазин"],
);
assert.deepEqual(
  matchingTitles(rows, "хлеб").map((row) => row.title),
  ["Купить хлеб"],
);
assert.equal(matchingTitles(rows, "аптека").length, 0);

const placed = fallbackPlan("удали задачи которые были поставлены 15, 16, 17 октября");
assert.equal(placed?.intent, "delete");
assert.equal(placed?.remove?.scope, "days");
assert.equal(placed?.remove?.title, "");
assert.equal(placed?.remove?.match, "either");
assert.deepEqual(placed?.remove?.points, [
  { month: 10, day: 15 },
  { month: 10, day: 16 },
  { month: 10, day: 17 },
]);
assert.deepEqual(
  resolveCalendarPoints("2026-10-19", placed!.remove!.points!),
  ["2026-10-15", "2026-10-16", "2026-10-17"],
);
assert.equal(
  spokenDateList(["2026-10-15", "2026-10-16", "2026-10-17"], "2026-10-19"),
  "15, 16 и 17 октября",
);

const ranged = fallbackPlan("удали задачи с 15 по 17 октября");
assert.equal(ranged?.remove?.scope, "days");
assert.equal(ranged?.remove?.match, "due");
assert.equal(ranged?.remove?.points?.length, 3);

assert.equal(fallbackPlan("удали задачи на 15 октября")?.remove?.scope, "day");
assert.equal(fallbackPlan("удали задачи на 15 октября")?.remove?.match, "due");
assert.equal(fallbackPlan("удали задачи созданные 15 октября")?.remove?.match, "created");
assert.equal(
  fallbackPlan("удали задачи поставленные на пятницу")?.remove?.match,
  "due",
);
assert.equal(fallbackPlan("удали задачи поставленные на пятницу")?.remove?.scope, "day");

assert.equal(resolveDueDate("2026-10-19", { when: "month_day", month: 10, day: 17 }), "2027-10-17");
assert.equal(closestMonthDay("2026-10-19", 10, 17), "2026-10-17");

assert.equal(
  fitsDates("2026-10-20", "2026-10-15T10:00:00.000Z", ["2026-10-15"], "either", 0),
  true,
);
assert.equal(
  fitsDates("2026-10-15", "2026-10-01T10:00:00.000Z", ["2026-10-15"], "due", 0),
  true,
);
assert.equal(
  fitsDates("2026-10-20", "2026-10-15T19:30:00.000Z", ["2026-10-15"], "created", 300),
  false,
);
assert.equal(
  fitsDates("2026-10-20", "2026-10-15T19:30:00.000Z", ["2026-10-16"], "created", 300),
  true,
);

console.log("tasks tests ok");
