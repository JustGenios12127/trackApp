const textPart = /^word\/(document|header\d+|footer\d+)\.xml$/;
const localSig = 0x04034b50;
const centralSig = 0x02014b50;
const eocdSig = 0x06054b50;
const maxEntries = 300;
const maxXmlBytes = 2_000_000;

export async function resumeText(bytes: Uint8Array): Promise<string> {
  let files: Map<string, Uint8Array>;
  try {
    files = await unzip(bytes);
  } catch {
    throw new Error("docx");
  }
  const names = [...files.keys()].filter((name) => textPart.test(name));
  names.sort((left, right) => rank(left) - rank(right) || left.localeCompare(right));
  if (!names.some((name) => name === "word/document.xml")) throw new Error("docx");
  const parts: string[] = [];
  for (const name of names) {
    const xml = files.get(name);
    if (!xml) continue;
    parts.push(xmlText(decodeXml(xml)));
  }
  const text = clean(parts.join("\n"));
  if (text.length < 40) throw new Error("docx");
  return text.slice(0, 50_000);
}

export function xmlText(xml: string): string {
  const pattern = /<w:tab\b[^>]*\/>|<w:br\b[^>]*\/>|<\/w:p>|<w:t\b[^>]*>([\s\S]*?)<\/w:t>/g;
  let out = "";
  for (const match of xml.matchAll(pattern)) {
    const token = match[0];
    if (token.startsWith("<w:t")) out += decodeEntities(match[1] ?? "");
    else if (token.startsWith("<w:tab")) out += "\t";
    else out += "\n";
  }
  return out;
}

async function unzip(bytes: Uint8Array): Promise<Map<string, Uint8Array>> {
  if (bytes.length < 22) throw new Error("zip");
  const eocd = findEocd(bytes);
  const count = readU16(bytes, eocd + 10) || readU16(bytes, eocd + 8);
  if (count === 0 || count > maxEntries) throw new Error("zip");
  const centralSize = readU32(bytes, eocd + 12);
  const centralOffset = readU32(bytes, eocd + 16);
  if (centralOffset === 0xffffffff || centralSize === 0xffffffff) throw new Error("zip");
  if (centralOffset + centralSize > bytes.length) throw new Error("zip");

  const files = new Map<string, Uint8Array>();
  let offset = centralOffset;
  for (let index = 0; index < count; index++) {
    if (readU32(bytes, offset) !== centralSig) throw new Error("zip");
    const flags = readU16(bytes, offset + 8);
    const method = readU16(bytes, offset + 10);
    const compressedSize = readU32(bytes, offset + 20);
    const uncompressedSize = readU32(bytes, offset + 24);
    const nameLength = readU16(bytes, offset + 28);
    const extraLength = readU16(bytes, offset + 30);
    const commentLength = readU16(bytes, offset + 32);
    const localOffset = readU32(bytes, offset + 42);
    const name = decodeName(bytes, offset + 46, nameLength);
    const next = offset + 46 + nameLength + extraLength + commentLength;
    if (!textPart.test(name)) {
      offset = next;
      continue;
    }
    if ((flags & 1) !== 0) throw new Error("zip");
    if (uncompressedSize > maxXmlBytes || compressedSize > maxXmlBytes) throw new Error("zip");
    if (readU32(bytes, localOffset) !== localSig) throw new Error("zip");
    const localNameLength = readU16(bytes, localOffset + 26);
    const localExtraLength = readU16(bytes, localOffset + 28);
    const start = localOffset + 30 + localNameLength + localExtraLength;
    const end = start + compressedSize;
    if (end > bytes.length) throw new Error("zip");
    files.set(name, await inflate(method, bytes.subarray(start, end)));
    offset = next;
  }
  return files;
}

async function inflate(method: number, data: Uint8Array): Promise<Uint8Array> {
  if (method === 0) return new Uint8Array(data);
  if (method !== 8) throw new Error("zip");
  const stream = new Blob([new Uint8Array(data)]).stream().pipeThrough(
    new DecompressionStream("deflate-raw"),
  );
  const inflated = new Uint8Array(await new Response(stream).arrayBuffer());
  if (inflated.length > maxXmlBytes) throw new Error("zip");
  return inflated;
}

function findEocd(data: Uint8Array): number {
  const min = Math.max(0, data.length - 22 - 65535);
  for (let offset = data.length - 22; offset >= min; offset--) {
    if (readU32(data, offset) !== eocdSig) continue;
    const commentLength = readU16(data, offset + 20);
    if (offset + 22 + commentLength === data.length) return offset;
  }
  throw new Error("zip");
}

function rank(name: string): number {
  if (name === "word/document.xml") return 0;
  if (name.includes("header")) return 1;
  return 2;
}

function decodeName(data: Uint8Array, offset: number, length: number): string {
  if (offset + length > data.length) throw new Error("zip");
  return new TextDecoder().decode(data.subarray(offset, offset + length)).replaceAll("\\", "/");
}

function decodeXml(bytes: Uint8Array): string {
  if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
    return new TextDecoder("utf-16le").decode(bytes);
  }
  if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
    return new TextDecoder("utf-16be").decode(bytes);
  }
  return new TextDecoder("utf-8", { fatal: false }).decode(bytes);
}

function decodeEntities(value: string): string {
  return value.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z]+);/gi, (entity, body: string) => {
    const lower = body.toLowerCase();
    if (lower === "amp") return "&";
    if (lower === "lt") return "<";
    if (lower === "gt") return ">";
    if (lower === "quot") return "\"";
    if (lower === "apos") return "'";
    if (lower.startsWith("#x")) {
      const code = Number.parseInt(lower.slice(2), 16);
      return char(code, entity);
    }
    if (lower.startsWith("#")) {
      const code = Number.parseInt(lower.slice(1), 10);
      return char(code, entity);
    }
    return entity;
  });
}

function char(code: number, fallback: string): string {
  if (!Number.isFinite(code) || code < 0 || code > 0x10ffff) return fallback;
  try {
    return String.fromCodePoint(code);
  } catch {
    return fallback;
  }
}

function clean(value: string): string {
  return value
    .replace(/\u0000/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function readU16(data: Uint8Array, offset: number): number {
  if (offset < 0 || offset + 2 > data.length) throw new Error("zip");
  return data[offset] | (data[offset + 1] << 8);
}

function readU32(data: Uint8Array, offset: number): number {
  if (offset < 0 || offset + 4 > data.length) throw new Error("zip");
  return (
    data[offset] |
    (data[offset + 1] << 8) |
    (data[offset + 2] << 16) |
    (data[offset + 3] << 24)
  ) >>> 0;
}
