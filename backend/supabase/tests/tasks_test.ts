import assert from "node:assert/strict";

import { remindInstant, resolveDueDate } from "../functions/chat/dates.ts";
import { fallbackPlan } from "../functions/chat/parse.ts";

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

console.log("tasks tests ok");
