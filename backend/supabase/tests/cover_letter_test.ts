import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { resumeText, xmlText } from "../functions/cover-letter/docx.ts";
import {
  candidateProfile,
  coverLetterFromTool,
  rememberedProfile,
  resumeFileName,
  vacancyText,
} from "../functions/cover-letter/flow.ts";
import { fillScript, readLetterScript } from "../functions/cover-letter/script.ts";
import { letterTool, readToolArguments, rememberTool } from "../functions/cover-letter/tools.ts";

const letterFile = new URL("../functions/cover-letter/letter.txt", import.meta.url);
const source = readFileSync(letterFile, "utf8");
const bundled = readFileSync(new URL("../functions/cover-letter/letter_text.ts", import.meta.url), "utf8");
assert.equal(bundled.includes(source.trim()), true);
const script = readLetterScript(source);

assert.match(source, /Здравствуйте!/);
assert.match(source, /\[Ваше имя\]/);
assert.match(source, /Составь короткое сопроводительное письмо/);
assert.match(source, /Названия предыдущих компаний/);
assert.match(source, /Конкретный стек технологий/);
assert.match(source, /4–6 предложений/);
assert.match(source, /\{\{vacancy_description\}\}/);
assert.match(source, /\{\{candidate_profile\}\}/);
assert.match(source, /Верни только готовое письмо/);
assert.equal(script.template.includes("Backend-разработчика"), true);

for (const name of ["index.ts", "flow.ts", "tools.ts", "script.ts", "docx.ts"]) {
  const code = readFileSync(new URL(`../functions/cover-letter/${name}`, import.meta.url), "utf8");
  assert.equal(code.includes("Меня заинтересовала ваша вакансия"), false);
  assert.equal(code.includes("Составь короткое сопроводительное письмо"), false);
}

const filled = fillScript(script.prompt, {
  template: script.template,
  vacancy_description: "Ищем дизайнера интерфейсов.",
  candidate_profile: "resume_id: 11111111-1111-4111-8111-111111111111",
});
assert.match(filled, /Ищем дизайнера интерфейсов/);
assert.match(filled, /Здравствуйте!/);
assert.equal(filled.includes("{{template}}"), false);
assert.throws(() => fillScript("Нужно {{missing}}", {}));

const memory = rememberedProfile({
  full_name: "  Иван   Иванов ",
  direction: "backend-разработка",
  profile: "Иван Иванов уже работал в backend-разработке и развитии серверной части.",
});
assert.equal(memory?.fullName, "Иван Иванов");
assert.equal(rememberedProfile({ full_name: "", direction: "дизайн", profile: "x".repeat(30) }), null);
assert.equal(vacancyText("коротко"), null);
assert.equal(vacancyText("Ищем разработчика серверной части."), "Ищем разработчика серверной части.");
assert.equal(resumeFileName("C:\\docs\\cv.docx"), "cv.docx");
assert.equal(resumeFileName("cv.pdf"), null);

const resumes = [
  {
    id: "11111111-1111-4111-8111-111111111111",
    fileName: "backend.docx",
    fullName: "Иван Иванов",
    direction: "backend-разработка",
    profile: "Иван Иванов имеет опыт backend-разработки.",
  },
  {
    id: "22222222-2222-4222-8222-222222222222",
    fileName: "design.docx",
    fullName: "Иван Иванов",
    direction: "дизайн интерфейсов",
    profile: "Иван Иванов имеет опыт дизайна интерфейсов.",
  },
];
const block = candidateProfile(resumes);
assert.match(block, /design\.docx/);
assert.equal(block.includes("source_text"), false);

const letter = "Здравствуйте!\n\nМеня заинтересовала ваша вакансия дизайнера интерфейсов. "
  + "Я уже имею опыт в этом направлении и знаком с такими задачами.\n\n"
  + "Буду рад присоединиться к команде и обсудить вакансию на собеседовании.\n\n"
  + "С уважением,\n[Ваше имя]";
const written = coverLetterFromTool({
  resume_id: "resume_id: 22222222-2222-4222-8222-222222222222",
  vacancy_title: "Дизайнер интерфейсов",
  letter,
}, resumes);
assert.equal(written?.resumeId, resumes[1].id);
assert.match(written?.letter ?? "", /Иван Иванов/);
assert.equal((written?.letter ?? "").includes("[Ваше имя]"), false);
assert.equal(coverLetterFromTool({
  resume_id: "33333333-3333-4333-8333-333333333333",
  vacancy_title: "Дизайнер",
  letter,
}, resumes), null);

const toolPayload = {
  choices: [{
    finish_reason: "tool_calls",
    message: {
      content: "",
      tool_calls: [{
        function: {
          name: rememberTool.function.name,
          arguments: "{\"full_name\":\"Анна Смирнова\",\"direction\":\"аналитика\",\"profile\":\"профиль\"}",
        },
      }],
    },
  }],
};
assert.equal(readToolArguments(toolPayload, rememberTool.function.name).full_name, "Анна Смирнова");
assert.throws(() => readToolArguments({
  choices: [{ finish_reason: "stop", message: { content: "{\"letter\":\"длинный json\"}" } }],
}, letterTool.function.name));
assert.equal(readToolArguments({
  choices: [{
    message: {
      tool_calls: [{
        function: {
          name: letterTool.function.name,
          arguments: { resume_id: "abc", vacancy_title: "Роль", letter: "Текст письма" },
        },
      }],
    },
  }],
}, letterTool.function.name).vacancy_title, "Роль");

assert.equal(
  xmlText("<w:p><w:r><w:t>Иван &amp; Анна</w:t></w:r></w:p><w:p><w:r><w:t>Опыт</w:t></w:r></w:p>"),
  "Иван & Анна\nОпыт\n",
);

const body = `<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Иван Иванов</w:t></w:r></w:p>
    <w:p><w:r><w:t>Опыт backend-разработки и развития серверной части приложений.</w:t></w:r></w:p>
  </w:body>
</w:document>`;
const header = `<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:p><w:r><w:t>Шапка профиля</w:t></w:r></w:p></w:hdr>`;
const docx = await resumeText(zip([
  { name: "word/document.xml", data: textBytes(body) },
  { name: "word/header1.xml", data: textBytes(header) },
  { name: "word/media/photo.png", data: textBytes("png"), compressed: new Uint8Array([1, 2, 3]) },
]));
assert.match(docx, /Иван Иванов/);
assert.match(docx, /Шапка профиля/);
assert.match(docx, /backend-разработки/);

const compressed = await deflateRaw(textBytes(body));
const inflated = await resumeText(zip([
  { name: "word/document.xml", data: textBytes(body), compressed },
]));
assert.match(inflated, /Иван Иванов/);

await assert.rejects(() => resumeText(new Uint8Array([1, 2, 3, 4])));
await assert.rejects(() => resumeText(zip([
  { name: "word/document.xml", data: textBytes("<w:t>Мало текста</w:t>") },
])));

function textBytes(value: string): Uint8Array {
  return new TextEncoder().encode(value);
}

function zip(entries: Array<{ name: string; data: Uint8Array; compressed?: Uint8Array }>): Uint8Array {
  const locals: Uint8Array[] = [];
  const centrals: Uint8Array[] = [];
  let offset = 0;
  for (const entry of entries) {
    const name = textBytes(entry.name);
    const stored = entry.compressed ?? entry.data;
    const method = entry.compressed ? 8 : 0;
    const local = concat([
      u32(0x04034b50),
      u16(20),
      u16(0),
      u16(method),
      u16(0),
      u16(0),
      u32(0),
      u32(stored.length),
      u32(entry.data.length),
      u16(name.length),
      u16(0),
      name,
      stored,
    ]);
    const central = concat([
      u32(0x02014b50),
      u16(20),
      u16(20),
      u16(0),
      u16(method),
      u16(0),
      u16(0),
      u32(0),
      u32(stored.length),
      u32(entry.data.length),
      u16(name.length),
      u16(0),
      u16(0),
      u16(0),
      u16(0),
      u32(0),
      u32(offset),
      name,
    ]);
    locals.push(local);
    centrals.push(central);
    offset += local.length;
  }
  const centralBlob = concat(centrals);
  const eocd = concat([
    u32(0x06054b50),
    u16(0),
    u16(0),
    u16(entries.length),
    u16(entries.length),
    u32(centralBlob.length),
    u32(offset),
    u16(0),
  ]);
  return concat([...locals, centralBlob, eocd]);
}

async function deflateRaw(data: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([data]).stream().pipeThrough(new CompressionStream("deflate-raw"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

function concat(parts: Array<Uint8Array | number[]>): Uint8Array {
  const bytes = parts.map((part) => part instanceof Uint8Array ? part : Uint8Array.from(part));
  const length = bytes.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(length);
  let cursor = 0;
  for (const part of bytes) {
    out.set(part, cursor);
    cursor += part.length;
  }
  return out;
}

function u16(value: number): number[] {
  return [value & 255, (value >> 8) & 255];
}

function u32(value: number): number[] {
  return [value & 255, (value >> 8) & 255, (value >> 16) & 255, (value >> 24) & 255];
}
