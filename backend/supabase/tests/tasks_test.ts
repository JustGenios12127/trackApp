import assert from "node:assert/strict";

import { remindInstant, resolveDueDate } from "../functions/chat/dates.ts";
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

console.log("tasks tests ok");
