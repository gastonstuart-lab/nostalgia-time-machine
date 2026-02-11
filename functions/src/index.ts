import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";

admin.initializeApp();

const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const OPENAI_YEAR_NEWS_TIMEOUT_MS = 60000;
const OPENAI_IMAGE_TIMEOUT_MS = 60000;

type GeneratedQuizQuestion = {
  year: number;
  question: string;
  options: string[];
  answerIndex: number;
  explanation?: string;
  source?: "ai" | "fallback";
  // Backward compatibility for existing Flutter model keys.
  q?: string;
  choices?: string[];
  explain?: string;
};

type RawAIYearNewsItem = {
  title?: unknown;
  subtitle?: unknown;
  imageQuery?: unknown;
  month?: unknown;
};

type YearNewsArticleDoc = {
  storyKey: string;
  year: number;
  month: number;
  title: string;
  subtitle: string;
  imageUrl: string;
  source: string;
  referenceUrl: string;
  bodyParagraphs: string[];
};

const YEAR_NEWS_MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec",
] as const;

function hashSeed(input: string): string {
  let hash = 2166136261;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash += (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24);
  }
  return Math.abs(hash >>> 0).toString();
}

function hasOtherYearInOptions(options: string[], year: number): boolean {
  for (const option of options) {
    const matches = option.match(/\b(19|20)\d{2}\b/g) ?? [];
    if (matches.some((value) => Number(value) !== year)) {
      return true;
    }
  }
  return false;
}

function filterQuestionsToYear(questions: GeneratedQuizQuestion[], year: number): GeneratedQuizQuestion[] {
  return questions.filter((question) => {
    if (question.year !== year) return false;
    if (question.options.length !== 4) return false;
    if (question.answerIndex < 0 || question.answerIndex > 3) return false;
    if (!question.question.trim()) return false;
    return true;
  });
}

async function assertMembership(groupId: string, uid: string): Promise<void> {
  const memberDoc = await admin
    .firestore()
    .collection("groups")
    .doc(groupId)
    .collection("members")
    .doc(uid)
    .get();

  if (!memberDoc.exists) {
    throw new HttpsError("permission-denied", "You are not a member of this group.");
  }
}

async function assertAdmin(groupId: string, uid: string): Promise<void> {
  const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
  if (!groupDoc.exists) {
    throw new HttpsError("not-found", "Group not found.");
  }

  const data = groupDoc.data() ?? {};
  const adminUid = (data.adminUid as string | undefined) ?? (data.createdByUid as string | undefined);
  if (!adminUid || adminUid != uid) {
    throw new HttpsError("permission-denied", "Only admins can generate quiz content.");
  }
}

function normalizeDifficulty(raw: unknown): "easy" | "medium" | "hard" {
  if (raw === "easy" || raw === "medium" || raw === "hard") return raw;
  return "medium";
}

function normalizeYearNewsRange(rawYear: unknown): number {
  const year = Number(rawYear);
  if (!Number.isInteger(year) || year < 1950 || year > 2010) {
    throw new HttpsError("invalid-argument", "year must be an integer between 1950 and 2010.");
  }
  return year;
}

function dedupeByTitle<T extends { title: string }>(items: T[]): T[] {
  const seen = new Set<string>();
  const output: T[] = [];
  for (const item of items) {
    const key = item.title.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    output.push(item);
  }
  return output;
}

function clampMonth(raw: unknown, fallback = 1): number {
  const month = Number(raw);
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    return fallback;
  }
  return month;
}

function normalizeTitle(raw: unknown): string {
  return String(raw ?? "").replace(/\s+/g, " ").trim();
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function toWikiSearchUrl(query: string): string {
  const normalized = normalizeTitle(query);
  if (!normalized) return "";
  return `https://en.wikipedia.org/wiki/Special:Search?search=${encodeURIComponent(normalized)}`;
}

function clampSubtitle(raw: unknown): string {
  const subtitle = normalizeTitle(raw);
  if (!subtitle) return "";
  return subtitle.length > 220 ? `${subtitle.slice(0, 217)}...` : subtitle;
}

function toStoryKey(year: number, month: number, title: string): string {
  const slug = normalizeTitle(title)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "")
    .slice(0, 80);
  return `${year}-${month.toString().padStart(2, "0")}-${slug || "story"}`;
}

function buildHeroImagePrompt(params: {
  year: number;
  title: string;
  subtitle: string;
}): string {
  return [
    `Cinematic realistic documentary-style scene set in ${params.year}.`,
    `Primary subject: ${params.title}.`,
    `Context: ${params.subtitle}.`,
    "Natural lighting, dramatic composition, period-appropriate details.",
    "No text, no logos, no watermarks.",
  ].join(" ");
}

function buildMonthlyTopImagePrompt(params: {
  title: string;
  subtitle: string;
}): string {
  return [
    `Cinematic documentary photograph of: ${params.title}.`,
    `Context: ${params.subtitle}.`,
    "Realistic lighting, historical accuracy, film still style, era-accurate clothing and setting, no text, no logos, no watermarks.",
  ].join(" ");
}

async function uploadGeneratedImageToStorage(params: {
  base64Image: string;
  path: string;
}): Promise<string> {
  const buffer = Buffer.from(params.base64Image, "base64");
  const bucket = admin.storage().bucket();
  const file = bucket.file(params.path);
  await file.save(buffer, {
    metadata: { contentType: "image/png" },
    resumable: false,
  });
  const [signedUrl] = await file.getSignedUrl({
    action: "read",
    expires: "2100-01-01",
  });
  return signedUrl;
}

async function generateOpenAIImageUrl(params: {
  apiKey: string;
  prompt: string;
  storagePath?: string;
}): Promise<string> {
  const response = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    signal: AbortSignal.timeout(OPENAI_IMAGE_TIMEOUT_MS),
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${params.apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-image-1",
      prompt: params.prompt,
      size: "1024x1024",
    }),
  });

  if (!response.ok) {
    return "";
  }

  const payload = await response.json() as {
    data?: Array<{ url?: string; b64_json?: string }>;
  };
  const first = payload.data?.[0];
  const url = normalizeTitle(first?.url);
  if (url) {
    return url;
  }

  const base64Image = normalizeTitle(first?.b64_json);
  if (!base64Image || !params.storagePath) {
    return "";
  }

  try {
    return await uploadGeneratedImageToStorage({
      base64Image,
      path: params.storagePath,
    });
  } catch {
    return "";
  }
}

function updateYearNewsPackageWithArticle(params: {
  packageData: Record<string, unknown>;
  article: YearNewsArticleDoc;
}): {
  hero: Record<string, unknown>[];
  byMonth: Record<string, Record<string, unknown>[]>;
  changed: boolean;
} {
  const { packageData, article } = params;
  let changed = false;
  const targetStoryKey = toStoryKey(article.year, article.month, article.title);

  const patchItem = (raw: unknown): Record<string, unknown> | null => {
    if (raw == null || typeof raw !== "object") return null;
    const item = { ...(raw as Record<string, unknown>) };
    const title = normalizeTitle(item.title);
    const month = clampMonth(item.month, article.month);
    if (!title) return item;
    const itemStoryKey = toStoryKey(article.year, month, title);
    if (itemStoryKey !== targetStoryKey) return item;

    if (normalizeTitle(item.imageUrl) !== article.imageUrl) {
      item.imageUrl = article.imageUrl;
      changed = true;
    }
    if (normalizeTitle(item.url) !== article.referenceUrl) {
      item.url = article.referenceUrl;
      changed = true;
    }
    if (normalizeTitle(item.source) !== article.source) {
      item.source = article.source;
      changed = true;
    }
    return item;
  };

  const heroRaw = Array.isArray(packageData.hero) ? packageData.hero : [];
  const hero = heroRaw
    .map((item) => patchItem(item))
    .filter((item): item is Record<string, unknown> => item != null);

  const byMonthRaw = (packageData.byMonth ?? {}) as Record<string, unknown>;
  const byMonth: Record<string, Record<string, unknown>[]> = {};
  for (const [monthKey, rawItems] of Object.entries(byMonthRaw)) {
    const items = Array.isArray(rawItems) ? rawItems : [];
    byMonth[monthKey] = items
      .map((item) => patchItem(item))
      .filter((item): item is Record<string, unknown> => item != null);
  }

  return { hero, byMonth, changed };
}

const FALLBACK_IMAGE_URL =
  "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/No_image_available.svg/640px-No_image_available.svg.png";

async function fetchWikipediaSummary(
  title: string,
): Promise<{ imageUrl: string; pageUrl: string } | null> {
  const normalizedTitle = normalizeTitle(title);
  if (!normalizedTitle) return null;

  const endpoint =
    `https://en.wikipedia.org/api/rest_v1/page/summary/${encodeURIComponent(normalizedTitle.replace(/\s+/g, "_"))}`;
  const response = await fetch(endpoint, {
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) return null;

  const payload = await response.json() as {
    thumbnail?: { source?: string };
    originalimage?: { source?: string };
    content_urls?: { desktop?: { page?: string } };
    type?: string;
  };

  if (payload.type === "disambiguation") {
    return null;
  }

  const imageUrl = normalizeTitle(payload.originalimage?.source) ||
    normalizeTitle(payload.thumbnail?.source);
  const pageUrl = normalizeTitle(payload.content_urls?.desktop?.page);

  return {
    imageUrl,
    pageUrl,
  };
}

function parseModelJson(content: string): Record<string, unknown> {
  const trimmed = content.trim();
  if (!trimmed) {
    throw new Error("empty_year_news_content");
  }

  try {
    return JSON.parse(trimmed) as Record<string, unknown>;
  } catch {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      return JSON.parse(trimmed.slice(start, end + 1)) as Record<string, unknown>;
    }
    throw new Error("invalid_year_news_json");
  }
}

async function callOpenAIJson(params: {
  apiKey: string;
  prompt: string;
  maxTokens: number;
}): Promise<Record<string, unknown>> {
  let lastError: unknown = null;

  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        signal: AbortSignal.timeout(OPENAI_YEAR_NEWS_TIMEOUT_MS),
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${params.apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          temperature: 0.2,
          max_tokens: params.maxTokens,
          messages: [
            { role: "system", content: "You output strict JSON only." },
            { role: "user", content: params.prompt },
          ],
          response_format: { type: "json_object" },
        }),
      });

      if (!response.ok) {
        throw new Error(`openai_year_news_${response.status}`);
      }

      const payload = await response.json() as { choices?: Array<{ message?: { content?: string } }> };
      const content = payload.choices?.[0]?.message?.content ?? "";
      return parseModelJson(content);
    } catch (err) {
      lastError = err;
      if (attempt < 2) {
        await sleep(600);
        continue;
      }
    }
  }

  throw lastError instanceof Error ? lastError : new Error("openai_year_news_failed");
}

function normalizeRawYearNewsItem(
  raw: RawAIYearNewsItem,
  monthFallback: number,
): Record<string, unknown> | null {
  const month = clampMonth(raw.month, monthFallback);
  const title = normalizeTitle(raw.title);
  const subtitle = clampSubtitle(raw.subtitle);
  const imageQuery = normalizeTitle(raw.imageQuery) || title;
  if (!title || !subtitle) return null;

  return {
    title,
    subtitle,
    imageUrl: "",
    imageQuery,
    source: "AI Historical Digest",
    url: toWikiSearchUrl(`${title} ${month} UK`),
    month,
  };
}

function buildDefaultYearNewsItem(params: {
  year: number;
  month: number;
  index: number;
  hero?: boolean;
}): Record<string, unknown> {
  const monthLabel = YEAR_NEWS_MONTHS[params.month - 1] ?? "Jan";
  const title = params.hero ?
    `UK spotlight in ${params.year} (${params.index}/3)` :
    `${monthLabel} ${params.year} UK spotlight (${params.index}/5)`;
  const subtitle = params.hero ?
    `Major UK talking points from ${params.year}, curated for your nostalgia timeline.` :
    `A key UK moment from ${monthLabel} ${params.year}, selected for the year timeline.`;
  return {
    title,
    subtitle,
    imageUrl: "",
    imageQuery: title,
    source: "AI Historical Digest",
    url: toWikiSearchUrl(`${title} ${params.year} UK`),
    month: params.month,
  };
}

function buildDefaultTickerHeadlines(year: number): string[] {
  return [
    `UK headlines shaping ${year}`,
    `Showbiz buzz across ${year}`,
    `Sport moments fans remember from ${year}`,
    `Politics and public debate in ${year}`,
    `Cultural shifts that defined ${year}`,
    `Charts, screens, and stories from ${year}`,
    `Memorable UK events from ${year}`,
    `Year-in-review: standout moments in ${year}`,
    `What people talked about in ${year}`,
    `From Westminster to Wembley in ${year}`,
    `Global stories seen through a UK lens in ${year}`,
    `Flashback briefings from ${year}`,
    `Broadcast highlights from ${year}`,
    `Headline recap for ${year}`,
    `Nostalgia feed: UK yearbook ${year}`,
  ];
}

async function buildHeroAndTicker(year: number, apiKey: string): Promise<{
  hero: Record<string, unknown>[];
  ticker: string[];
}> {
  const prompt = [
    `Create UK-first nostalgic headlines for year ${year}.`,
    "Focus on UK news, showbiz, sport, and major global events that mattered in the UK conversation.",
    "Return strict JSON with fields hero and ticker.",
    "hero must be an array of exactly 3 items.",
    "Each hero item: { title, subtitle, imageQuery, month }",
    "ticker must be an array of 15 concise headlines (max 80 chars each).",
    "No markdown. No extra keys.",
  ].join("\n");

  let parsed: Record<string, unknown> = {};
  try {
    parsed = await callOpenAIJson({
      apiKey,
      prompt,
      maxTokens: 1600,
    });
  } catch (err) {
    console.warn("[buildHeroAndTicker] Falling back to padded content.", {
      year,
      error: err instanceof Error ? err.message : String(err),
    });
  }

  const heroRaw = Array.isArray(parsed.hero) ? parsed.hero : [];
  const heroBase = heroRaw
    .map((item) => normalizeRawYearNewsItem(item as RawAIYearNewsItem, 1))
    .filter((item): item is Record<string, unknown> => item != null)
    .slice(0, 3);

  const heroResolved: Record<string, unknown>[] = await Promise.all(
    heroBase.map(async (item) => {
      const title = normalizeTitle(item["title"]);
      const subtitle = normalizeTitle(item["subtitle"]);
      const month = clampMonth(item["month"], 1);
      const storyKey = toStoryKey(year, month, title);
      const imageQuery = normalizeTitle(item["imageQuery"]) || title;
      const generatedImageUrl = await generateOpenAIImageUrl({
        apiKey,
        prompt: buildHeroImagePrompt({
          year,
          title,
          subtitle,
        }),
        storagePath: `year-news/${year}/hero/${storyKey}.png`,
      });
      return {
        ...item,
        imageQuery,
        imageUrl: generatedImageUrl,
        url: toWikiSearchUrl(`${title} ${year} UK`) || String(item["url"] ?? ""),
      };
    }),
  );
  const hero = [...heroResolved];
  while (hero.length < 3) {
    hero.push(
      buildDefaultYearNewsItem({
        year,
        month: hero.length + 1,
        index: hero.length + 1,
        hero: true,
      }),
    );
  }

  const ticker = (Array.isArray(parsed.ticker) ? parsed.ticker : [])
    .map((entry) => normalizeTitle(entry))
    .filter((entry) => entry.length > 0)
    .slice(0, 15);
  if (ticker.length < 15) {
    const fallbackTicker = buildDefaultTickerHeadlines(year);
    for (const headline of fallbackTicker) {
      if (ticker.length >= 15) break;
      if (!ticker.includes(headline)) ticker.push(headline);
    }
  }

  return { hero, ticker };
}

async function buildMonthsChunk(
  year: number,
  startMonth: number,
  endMonth: number,
  apiKey: string,
): Promise<Record<string, Record<string, unknown>[]>> {
  const monthLabels = YEAR_NEWS_MONTHS.slice(startMonth - 1, endMonth).join(", ");
  const prompt = [
    `Create UK-first nostalgic news cards for year ${year}.`,
    `Generate months ${monthLabels}.`,
    "Return strict JSON with one key byMonth.",
    "byMonth is an object keyed by month short names (Jan..Dec).",
    "Each month must have exactly 5 items.",
    "Each item must be: { title, subtitle, imageQuery, month }",
    "subtitle must be factual one sentence, max 170 chars.",
    "No markdown and no extra keys.",
  ].join("\n");

  let byMonthRaw: Record<string, unknown> = {};
  try {
    const parsed = await callOpenAIJson({
      apiKey,
      prompt,
      maxTokens: 2600,
    });
    const raw = parsed.byMonth as Record<string, unknown> | undefined;
    if (raw != null && typeof raw === "object") {
      byMonthRaw = raw;
    }
  } catch (err) {
    console.warn("[buildMonthsChunk] Falling back to padded month content.", {
      year,
      startMonth,
      endMonth,
      error: err instanceof Error ? err.message : String(err),
    });
  }

  const output: Record<string, Record<string, unknown>[]> = {};
  for (let month = startMonth; month <= endMonth; month++) {
    const monthKey = YEAR_NEWS_MONTHS[month - 1];
    const monthRaw = byMonthRaw[monthKey] ?? byMonthRaw[String(month)];
    const itemsBase = (Array.isArray(monthRaw) ? monthRaw : [])
      .map((item) => normalizeRawYearNewsItem(item as RawAIYearNewsItem, month))
      .filter((item): item is Record<string, unknown> => item != null)
      .slice(0, 5);
    while (itemsBase.length < 5) {
      itemsBase.push(
        buildDefaultYearNewsItem({
          year,
          month,
          index: itemsBase.length + 1,
        }),
      );
    }

    output[monthKey] = itemsBase;
  }

  return output;
}

async function buildYearNewsFromAI(year: number, apiKey: string): Promise<{
  hero: Record<string, unknown>[];
  byMonth: Record<string, Record<string, unknown>[]>;
  ticker: string[];
}> {
  const heroAndTicker = await buildHeroAndTicker(year, apiKey);
  const chunkA = await buildMonthsChunk(year, 1, 4, apiKey);
  const chunkB = await buildMonthsChunk(year, 5, 8, apiKey);
  const chunkC = await buildMonthsChunk(year, 9, 12, apiKey);

  return {
    hero: heroAndTicker.hero,
    ticker: heroAndTicker.ticker,
    byMonth: {
      ...chunkA,
      ...chunkB,
      ...chunkC,
    },
  };
}

async function fetchWikimediaImageUrl(query: string): Promise<string> {
  const safeQuery = normalizeTitle(query);
  if (!safeQuery) return "";

  const searchUrl =
    `https://commons.wikimedia.org/w/api.php?action=query&list=search&srsearch=${encodeURIComponent(safeQuery)}&format=json&srlimit=1&utf8=1`;
  const searchResponse = await fetch(searchUrl, {
    signal: AbortSignal.timeout(10000),
  });
  if (!searchResponse.ok) return "";

  const searchPayload = await searchResponse.json() as {
    query?: { search?: Array<{ title?: string }> };
  };
  const title = normalizeTitle(searchPayload.query?.search?.[0]?.title);
  if (!title) return "";

  const imageUrl =
    `https://commons.wikimedia.org/w/api.php?action=query&titles=${encodeURIComponent(title)}&prop=pageimages&piprop=thumbnail&pithumbsize=1200&format=json`;
  const imageResponse = await fetch(imageUrl, {
    signal: AbortSignal.timeout(10000),
  });
  if (!imageResponse.ok) return "";

  const imagePayload = await imageResponse.json() as {
    query?: { pages?: Record<string, { thumbnail?: { source?: string } }> };
  };
  const pages = imagePayload.query?.pages ?? {};
  for (const page of Object.values(pages)) {
    const thumbnail = normalizeTitle(page.thumbnail?.source);
    if (thumbnail) return thumbnail;
  }
  return "";
}

async function resolveStoryImage(params: {
  title: string;
  imageQuery: string;
  year: number;
  apiKey: string;
}): Promise<{ imageUrl: string; pageUrl: string }> {
  const candidates = dedupeByTitle(
    [
      { title: `${params.title}` },
      { title: `${params.title} (${params.year})` },
      { title: `${params.imageQuery}` },
      { title: `${params.imageQuery} ${params.year}` },
      { title: `${params.title} UK ${params.year}` },
    ].filter((item) => normalizeTitle(item.title).length > 0),
  ).map((item) => item.title);

  for (const candidate of candidates) {
    const summary = await fetchWikipediaSummary(candidate);
    if (summary != null && summary.imageUrl) {
      return {
        imageUrl: summary.imageUrl,
        pageUrl: summary.pageUrl,
      };
    }
  }

  for (const candidate of candidates) {
    const commonsImage = await fetchWikimediaImageUrl(candidate);
    if (commonsImage) {
      return {
        imageUrl: commonsImage,
        pageUrl: toWikiSearchUrl(candidate),
      };
    }
  }

  const aiImagePrompt = [
    `Cinematic realistic documentary-style scene set in ${params.year}.`,
    `Subject: ${params.title}.`,
    "Historically grounded atmosphere.",
    "No text, no logos, no watermarks.",
  ].join(" ");
  const aiImageUrl = await generateOpenAIImageUrl({
    apiKey: params.apiKey,
    prompt: aiImagePrompt,
    storagePath: `year-news/${params.year}/stories/${toStoryKey(params.year, 1, params.title)}.png`,
  });
  if (aiImageUrl) {
    return {
      imageUrl: aiImageUrl,
      pageUrl: toWikiSearchUrl(`${params.title} ${params.year}`),
    };
  }

  return {
    imageUrl: FALLBACK_IMAGE_URL,
    pageUrl: toWikiSearchUrl(`${params.title} ${params.year}`),
  };
}

async function generateYearNewsArticleDoc(params: {
  year: number;
  month: number;
  title: string;
  subtitle: string;
  imageQuery: string;
  apiKey: string;
}): Promise<YearNewsArticleDoc> {
  const prompt = [
    `Write a UK-first nostalgic feature article for the year ${params.year}.`,
    `Headline: ${params.title}`,
    `Deck: ${params.subtitle}`,
    "Return strict JSON with fields:",
    "title, subtitle, imageQuery, bodyParagraphs",
    "bodyParagraphs must be an array of exactly 5 paragraphs.",
    "Each paragraph should be 2-4 sentences, vivid but factual in tone.",
    "No markdown, no bullet points, no extra keys.",
  ].join("\n");

  const parsed = await callOpenAIJson({
    apiKey: params.apiKey,
    prompt,
    maxTokens: 2200,
  });

  const bodyParagraphs = (Array.isArray(parsed.bodyParagraphs) ? parsed.bodyParagraphs : [])
    .map((entry) => normalizeTitle(entry))
    .filter((entry) => entry.length > 0)
    .slice(0, 5);

  if (bodyParagraphs.length < 3) {
    throw new Error("article_body_incomplete");
  }

  const resolvedTitle = normalizeTitle(parsed.title) || params.title;
  const resolvedSubtitle = clampSubtitle(parsed.subtitle) || params.subtitle;
  const resolvedImageQuery = normalizeTitle(parsed.imageQuery) || params.imageQuery || params.title;
  const resolvedImage = await resolveStoryImage({
    title: resolvedTitle,
    imageQuery: resolvedImageQuery,
    year: params.year,
    apiKey: params.apiKey,
  });

  return {
    storyKey: toStoryKey(params.year, params.month, resolvedTitle),
    year: params.year,
    month: params.month,
    title: resolvedTitle,
    subtitle: resolvedSubtitle,
    imageUrl: resolvedImage.imageUrl,
    source: "AI Historical Digest",
    referenceUrl: resolvedImage.pageUrl || toWikiSearchUrl(`${resolvedTitle} ${params.year} UK`),
    bodyParagraphs,
  };
}

async function enforceRateLimit(options: {
  uid: string;
  key: string;
  maxRequests: number;
  windowMs: number;
}): Promise<void> {
  const { uid, key, maxRequests, windowMs } = options;
  const now = Date.now();
  const bucket = Math.floor(now / windowMs);
  const docId = `${uid}_${key}_${bucket}`;
  const ref = admin.firestore().collection("aiRateLimits").doc(docId);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count as number | undefined) ?? 0;
    if (count >= maxRequests) {
      throw new HttpsError("resource-exhausted", "Rate limit exceeded. Please try again later.");
    }
    tx.set(
      ref,
      {
        uid,
        key,
        bucket,
        count: count + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(now + windowMs * 2),
      },
      { merge: true },
    );
  });
}

function fallbackQuestions(year: number, avoidQuestions: string[] = []): GeneratedQuizQuestion[] {
  const avoid = new Set(avoidQuestions.map((q) => questionKey(q)).filter((q) => q.length > 0));
  const prompts = [
    `Which headline music release in ${year} had the biggest cultural impact?`,
    `Which live performance from ${year} is most associated with that year’s sound?`,
    `Which soundtrack moment in ${year} became widely recognizable?`,
    `Which radio trend best matches mainstream listening in ${year}?`,
    `Which debut act most defined new talent in ${year}?`,
    `Which collaboration style was most visible in ${year}?`,
    `Which award-show music moment is most linked to ${year}?`,
    `Which chart pattern best describes hit songs in ${year}?`,
    `Which album production style stood out in ${year}?`,
    `Which genre crossover became common in ${year}?`,
    `Which tour format gained traction in ${year}?`,
    `Which music video direction was most typical in ${year}?`,
    `Which festival talking point was tied to ${year}?`,
    `Which breakthrough single pattern best fits ${year}?`,
    `Which vocal trend best reflects top songs in ${year}?`,
    `Which instrumentation choice was common in ${year}?`,
    `Which TV-and-music crossover felt most emblematic of ${year}?`,
    `Which pop-culture music headline best matches ${year}?`,
    `Which dance-floor trend was strongest in ${year}?`,
    `Which songwriting theme appeared most often in ${year}?`,
    `Which chart-climbing strategy was typical in ${year}?`,
    `Which live-band arrangement was most associated with ${year}?`,
    `Which remix trend best fits the sound of ${year}?`,
    `Which artist rollout style became common in ${year}?`,
  ];

  const optionPool = [
    `A breakthrough mainstream hit from ${year}`,
    `A crossover success associated with ${year}`,
    `A live-performance moment discussed in ${year}`,
    `A chart-dominating release from ${year}`,
    `A radio staple heavily played in ${year}`,
    `A soundtrack-driven song surge in ${year}`,
    `A genre-blending anthem tied to ${year}`,
    `A festival favorite strongly linked to ${year}`,
  ];

  const bank: GeneratedQuizQuestion[] = prompts.map((question, index) => {
    const rotated = [
      optionPool[(index + 0) % optionPool.length],
      optionPool[(index + 2) % optionPool.length],
      optionPool[(index + 4) % optionPool.length],
      optionPool[(index + 6) % optionPool.length],
    ];
    const answerIndex = (year + index) % 4;
    return {
      year,
      question,
      options: rotated,
      answerIndex,
      explanation: `Fallback year-locked question for ${year}.`,
      source: "fallback",
    };
  });

  const filtered = bank.filter((item) => !avoid.has(questionKey(item.question)));
  const pool = filtered.length >= 20 ? filtered : bank;
  return pool.slice(0, 20);
}

function normalizeQuestions(raw: unknown, maxCount = 40): GeneratedQuizQuestion[] {
  if (!Array.isArray(raw)) {
    return [];
  }

  const normalized = raw.slice(0, maxCount).map((item) => {
    const q = item as Record<string, unknown>;
    const optionsRaw = Array.isArray(q.options)
      ? q.options
      : (Array.isArray(q.choices) ? q.choices : []);
    const options = optionsRaw.slice(0, 4).map((c) => String(c));
    const answerIndex = Number(q.answerIndex ?? -1);
    const year = Number(q.year ?? NaN);
    const question = String(q.question ?? q.q ?? "").trim();
    const explanation = String(q.explanation ?? q.explain ?? "").trim();
    return {
      year,
      question,
      options,
      answerIndex,
      explanation,
      q: question,
      choices: options,
      explain: explanation,
    };
  });
  return normalized.filter((question) =>
    Number.isInteger(question.year) &&
    question.question.length > 0 &&
    question.options.length === 4 &&
    question.answerIndex >= 0 &&
    question.answerIndex <= 3,
  );
}

function coerceExistingQuestions(raw: unknown): GeneratedQuizQuestion[] {
  if (!Array.isArray(raw)) return [];
  return raw.slice(0, 20).map((item) => {
    const map = item as Record<string, unknown>;
    const question = String(map.question ?? map.q ?? "").trim();
    const rawChoices = Array.isArray(map.choices)
      ? map.choices
      : (Array.isArray(map.options) ? map.options : []);
    const options = rawChoices.slice(0, 4).map((choice) => String(choice));
    const year = Number(map.year ?? NaN);
    const answerIndex = Number(map.answerIndex ?? map.correctIndex ?? 0);
    const explanation = String(map.explanation ?? map.explain ?? "").trim();
    return {
      year,
      question,
      options,
      answerIndex: Number.isFinite(answerIndex) ? answerIndex : 0,
      explanation,
      q: question,
      choices: options,
      explain: explanation,
    };
  }).filter((question) => question.question.length > 0 && question.options.length == 4);
}

function questionKey(question: string): string {
  return question.trim().toLowerCase().replace(/\s+/g, " ");
}

async function generateWithOpenAI(params: {
  year: number;
  difficultyHint: "easy" | "medium" | "hard";
  apiKey: string;
  avoidQuestions?: string[];
  seed: string;
  retryLevel?: number;
  questionCount?: number;
}): Promise<GeneratedQuizQuestion[]> {
  const {
    year,
    difficultyHint,
    apiKey,
    avoidQuestions = [],
    seed,
    retryLevel = 0,
    questionCount = 20,
  } = params;
  const avoidList = avoidQuestions
    .map((q) => q.trim())
    .filter((q) => q.length > 0)
    .slice(0, 20);
  const nonce = `${seed}_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;

  const prompt = [
    `Generate exactly ${questionCount} nostalgia quiz questions.`,
    `Focus year: ${year}. ONLY use this exact year.`,
    "NO OTHER YEARS are allowed anywhere.",
    `Difficulty hint: ${difficultyHint || "medium"}.`,
    `Generation nonce: ${nonce}.`,
    `Deterministic seed for this group/week/year: ${seed}.`,
    "Difficulty guidelines:",
    "easy: basic pop culture and major events, very recognizable questions.",
    "medium: balanced mix of pop culture, tech, sports, and world events.",
    "hard: deeper or less obvious facts, niche events, second-tier hits, tech details.",
    "Each question must have year, question, options[4], answerIndex (0-3), explanation.",
    "Do not repeat any question text within this quiz.",
    `Question.year MUST be ${year} for every item.`,
    `No option may contain any 4-digit year other than ${year}.`,
    ...(retryLevel > 0
      ? [
          `RETRY ${retryLevel}: NO OTHER YEARS. If uncertain, rewrite the question to stay in ${year}.`,
          "If any question cannot be guaranteed for the exact year, replace it before returning.",
        ]
      : []),
    ...(avoidList.length > 0
      ? [
          "Do not reuse or closely paraphrase any of these prior questions:",
          ...avoidList.map((q, idx) => `${idx + 1}. ${q}`),
        ]
      : []),
    "Return ONLY JSON in this exact shape:",
    `{"questions":[{"year":${year},"question":"...","options":["a","b","c","d"],"answerIndex":0,"explanation":"..."}]}`,
  ].join("\n");

  let lastError: unknown;
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          temperature: 0.9,
          max_tokens: 4200,
          messages: [
            { role: "system", content: "You are a strict JSON generator." },
            { role: "user", content: prompt },
          ],
          response_format: { type: "json_object" },
        }),
      });

      if (!response.ok) {
        throw new Error(`openai_error_${response.status}`);
      }

      const data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
      const content = data.choices?.[0]?.message?.content;
      if (!content) {
        throw new Error("empty_openai_response");
      }

      const parsed = JSON.parse(content) as { questions?: unknown };
      const rawCount = Array.isArray(parsed.questions) ? parsed.questions.length : 0;
      const normalized = normalizeQuestions(parsed.questions, Math.max(questionCount, 40));
      console.log(
        "[generateWeeklyQuiz] batch metrics:",
        `retry=${retryLevel}`,
        `requested=${questionCount}`,
        `raw=${rawCount}`,
        `normalized=${normalized.length}`,
      );
      return normalized;
    } catch (err) {
      lastError = err;
      if (attempt == 2) break;
    }
  }
  throw lastError instanceof Error ? lastError : new Error("openai_generation_failed");
}

export const generateWeeklyQuiz = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: [OPENAI_API_KEY],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const groupId = String(request.data?.groupId ?? "");
    const weekId = String(request.data?.weekId ?? "");
    const requestedYear = Number(request.data?.year ?? 1990);
    const forceRegenerate = Boolean(request.data?.forceRegenerate ?? false);

    if (!groupId || !weekId) {
      throw new HttpsError("invalid-argument", "groupId and weekId are required.");
    }
    await assertMembership(groupId, uid);

    const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
    if (!groupDoc.exists) {
      throw new HttpsError("not-found", "Group not found.");
    }

    const groupCurrentYear = Number(groupDoc.data()?.currentYear ?? NaN);
    const year = Number.isInteger(groupCurrentYear) ? groupCurrentYear : requestedYear;
    if (!Number.isInteger(year) || year < 1900 || year > 2100) {
      throw new HttpsError("invalid-argument", "year must be a valid integer year.");
    }

    const groupDifficulty = normalizeDifficulty(groupDoc.data()?.settings?.quizDifficulty);
    const seed = hashSeed(`${groupId}:${weekId}:${year}:${groupDifficulty}`);

    const quizRef = admin
      .firestore()
      .collection("groups")
      .doc(groupId)
      .collection("weeks")
      .doc(weekId)
      .collection("quiz")
      .doc("definition");

    const existingDoc = await quizRef.get();
    const existingQuestions = existingDoc.data()?.questions;
    const existingYear = Number(existingDoc.data()?.year ?? NaN);
    const storedDifficulty = normalizeDifficulty(existingDoc.data()?.difficulty);
    const existingSourceSummary = existingDoc.data()?.sourceSummary as { aiCount?: unknown; fallbackCount?: unknown } | undefined;
    const hasSourceSummary =
      typeof existingSourceSummary?.aiCount === "number" &&
      typeof existingSourceSummary?.fallbackCount === "number";
    const existingStrictQuestions = filterQuestionsToYear(
      coerceExistingQuestions(existingQuestions),
      year,
    );

    // Regenerate if:
    // - caller explicitly requested forceRegenerate, OR
    // - no quiz exists, OR
    // - stored difficulty no longer matches group difficulty
    const shouldRegenerate =
      forceRegenerate ||
      !existingDoc.exists ||
      !Array.isArray(existingQuestions) ||
      existingQuestions.length === 0 ||
      existingStrictQuestions.length !== 20 ||
      !Number.isInteger(existingYear) ||
      existingYear !== year ||
      !hasSourceSummary ||
      storedDifficulty !== groupDifficulty;

    console.log("[generateWeeklyQuiz] groupId:", groupId, "weekId:", weekId, "forceRegenerate:", forceRegenerate, "shouldRegenerate:", shouldRegenerate, "storedDifficulty:", storedDifficulty, "groupDifficulty:", groupDifficulty);

    if (shouldRegenerate) {
      console.log("[generateWeeklyQuiz] Regenerating quiz...");
      if (forceRegenerate) {
        await assertAdmin(groupId, uid);
        await enforceRateLimit({
          uid,
          key: "quiz_generation_daily",
          maxRequests: 25,
          windowMs: 24 * 60 * 60 * 1000,
        });
      }

      const apiKey = OPENAI_API_KEY.value();
      let questions: GeneratedQuizQuestion[] = [];
      const normalizedExisting = coerceExistingQuestions(existingQuestions);
      const existingQuestionTexts = normalizedExisting.map((q) => q.question);

      try {
        const unique = new Map<string, GeneratedQuizQuestion>();
        let attempt = 0;
        while (attempt < 5 && unique.size < 20) {
          const requestCount = attempt === 0 ? 35 : 20;
          const instructionSeed = attempt == 0 ? seed : `${seed}_retry_${attempt}`;
          const nextQuestions = await generateWithOpenAI({
            year,
            difficultyHint: groupDifficulty,
            apiKey,
            avoidQuestions: existingQuestionTexts,
            seed: instructionSeed,
            retryLevel: attempt,
            questionCount: requestCount,
          });
          const filtered = filterQuestionsToYear(nextQuestions, year);
          console.log(
            "[generateWeeklyQuiz] filter metrics:",
            `retry=${attempt}`,
            `yearLocked=${filtered.length}`,
            `uniqueBefore=${unique.size}`,
          );
          for (const item of filtered) {
            const key = questionKey(item.question);
            if (!key || unique.has(key)) continue;
            unique.set(key, { ...item, source: "ai" });
            if (unique.size >= 20) break;
          }
          console.log(
            "[generateWeeklyQuiz] dedupe metrics:",
            `retry=${attempt}`,
            `uniqueAfter=${unique.size}`,
          );
          attempt++;
        }
        questions = Array.from(unique.values()).slice(0, 20);
        console.log("[generateWeeklyQuiz] OpenAI questions generated:", questions && questions.length);
      } catch (err) {
        console.error("[generateWeeklyQuiz] OpenAI generation error:", err);
        questions = [];
      }

      const aiCount = questions.length;
      if (questions.length < 20) {
        const fallbackPool = fallbackQuestions(year, questions.map((q) => q.question));
        for (const fallback of fallbackPool) {
          const key = questionKey(fallback.question);
          if (!key) continue;
          if (questions.some((q) => questionKey(q.question) === key)) continue;
          questions.push({ ...fallback, source: "fallback" });
          if (questions.length >= 20) break;
        }
      }
      if (questions.length < 20) {
        let pad = 1;
        while (questions.length < 20) {
          const synthetic: GeneratedQuizQuestion = {
            year,
            question: `Year ${year} music memory check #${pad}`,
            options: [
              `Notable release in ${year}`,
              `Popular radio trend in ${year}`,
              `Major live performance in ${year}`,
              `Breakout artist moment in ${year}`,
            ],
            answerIndex: 0,
            explanation: `Fallback filler for strict year ${year}.`,
            source: "fallback",
          };
          const key = questionKey(synthetic.question);
          if (!questions.some((q) => questionKey(q.question) === key)) {
            questions.push(synthetic);
          }
          pad++;
        }
      }
      const fallbackCount = Math.max(0, questions.length - aiCount);
      questions = questions.slice(0, 20);

      await quizRef.set(
        {
          year,
          difficulty: groupDifficulty,
          seed,
          questions,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          weekId,
          // Optional metadata kept for diagnostics.
          generatedBy: uid,
          model: "gpt-4o-mini-or-fallback",
          sourceSummary: {
            aiCount,
            fallbackCount,
          },
        },
        { merge: false },
      );
      console.log("[generateWeeklyQuiz] Quiz written to Firestore.");

      return { questions };
    } else {
      // Return existing quiz
      const normalized = existingStrictQuestions;
      console.log("[generateWeeklyQuiz] Returning existing quiz. Questions:", normalized && normalized.length);
      return { questions: normalized };
    }
  },
);

export const generateYearNewsPackage = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 300,
    memory: "512MiB",
    secrets: [OPENAI_API_KEY],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    await enforceRateLimit({
      uid,
      key: "year_news_generation_daily",
      maxRequests: 40,
      windowMs: 24 * 60 * 60 * 1000,
    });

    const year = normalizeYearNewsRange(request.data?.year);
    const docRef = admin.firestore().collection("year_news").doc(String(year));
    const now = Date.now();
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

    const existing = await docRef.get();
    if (existing.exists) {
      const data = existing.data() ?? {};
      const generationStatus = String(data.generationStatus ?? "");
      const updatedAtRaw = data.updatedAt as admin.firestore.Timestamp | undefined;
      const updatedAtMillis = updatedAtRaw?.toMillis() ?? 0;
      const hasRecentCompleteData =
        generationStatus === "complete" && now - updatedAtMillis < thirtyDaysMs;
      if (hasRecentCompleteData) {
        return { status: "already_exists", year };
      }
    }

    const apiKey = String(OPENAI_API_KEY.value() ?? "").trim();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "OPENAI_API_KEY is not configured.");
    }

    let generated: {
      hero: Record<string, unknown>[];
      byMonth: Record<string, Record<string, unknown>[]>;
      ticker: string[];
    };
    try {
      generated = await buildYearNewsFromAI(year, apiKey);
    } catch (err) {
      console.error("[generateYearNewsPackage] AI generation failed.", {
        error: err instanceof Error ? err.message : String(err),
      });
      throw new HttpsError("internal", "Year news generation failed. Please retry.");
    }

    await docRef.set(
      {
        year,
        generationStatus: "complete",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        hero: generated.hero,
        byMonth: generated.byMonth,
        ticker: generated.ticker.slice(0, 15),
      },
      { merge: false },
    );

    return { status: "generated", year };
  },
);

export const generateYearNewsArticle = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 90,
    memory: "512MiB",
    secrets: [OPENAI_API_KEY],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    await enforceRateLimit({
      uid,
      key: "year_news_article_daily",
      maxRequests: 100,
      windowMs: 24 * 60 * 60 * 1000,
    });

    const year = normalizeYearNewsRange(request.data?.year);
    const month = clampMonth(request.data?.month, 1);
    const title = normalizeTitle(request.data?.title);
    const subtitle = clampSubtitle(request.data?.subtitle);
    const imageQuery = normalizeTitle(request.data?.imageQuery) || title;

    if (!title || !subtitle) {
      throw new HttpsError("invalid-argument", "title and subtitle are required.");
    }

    const storyKey = toStoryKey(year, month, title);
    const articleRef = admin
      .firestore()
      .collection("year_news")
      .doc(String(year))
      .collection("stories")
      .doc(storyKey);

    const existing = await articleRef.get();
    if (existing.exists && existing.data() != null) {
      return {
        status: "already_exists",
        year,
        storyKey,
        article: existing.data(),
      };
    }

    const apiKey = String(OPENAI_API_KEY.value() ?? "").trim();
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "OPENAI_API_KEY is not configured.");
    }

    let article: YearNewsArticleDoc;
    try {
      article = await generateYearNewsArticleDoc({
        year,
        month,
        title,
        subtitle,
        imageQuery,
        apiKey,
      });
    } catch (err) {
      console.error("[generateYearNewsArticle] generation failed", {
        error: err instanceof Error ? err.message : String(err),
      });
      throw new HttpsError("internal", "Story generation failed. Please retry.");
    }

    await articleRef.set(
      {
        ...article,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: false },
    );

    const yearDocRef = admin.firestore().collection("year_news").doc(String(year));
    const yearDocSnap = await yearDocRef.get();
    if (yearDocSnap.exists && yearDocSnap.data() != null) {
      const packageData = yearDocSnap.data() as Record<string, unknown>;
      const patched = updateYearNewsPackageWithArticle({
        packageData,
        article,
      });
      if (patched.changed) {
        await yearDocRef.set(
          {
            hero: patched.hero,
            byMonth: patched.byMonth,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
    }

    return {
      status: "generated",
      year,
      storyKey,
      article,
    };
  },
);

export const nostalgiaChat = onCall(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    secrets: [OPENAI_API_KEY],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }

    const groupId = String(request.data?.groupId ?? "");
    const message = String(request.data?.message ?? "").trim();
    const context = request.data?.context;

    if (!groupId || !message) {
      throw new HttpsError("invalid-argument", "groupId and message are required.");
    }

    if (message.length > 800) {
      throw new HttpsError("invalid-argument", "Message too long.");
    }

    await assertMembership(groupId, uid);
    await enforceRateLimit({
      uid,
      key: "chat_minute",
      maxRequests: 20,
      windowMs: 60 * 1000,
    });

    const year = Number(context?.year ?? 1990);
    const history = Array.isArray(context?.history) ? context.history.slice(-8) : [];

    const messages = [
      {
        role: "system",
        content:
          `You are a nostalgic assistant for year ${year}. Keep answers concise, friendly, and practical.`,
      },
      ...history
        .map((entry: any): { role: string; content: string } => {
          const role = entry?.role == "assistant" ? "assistant" : "user";
          const content = String(entry?.content ?? "").slice(0, 400);
          return { role, content };
        })
        .filter((entry: { role: string; content: string }) => entry.content.length > 0),
      { role: "user", content: message },
    ];

    // TEMP DIAGNOSTIC LOGGING
    console.log('[nostalgiaChat] About to call OpenAI', {
      apiKeySet: !!OPENAI_API_KEY.value(),
      model: 'gpt-4o-mini',
      messagesLength: messages.length,
      firstMessage: messages[0],
    });
    let response;
    try {
      response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENAI_API_KEY.value()}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          temperature: 0.7,
          max_tokens: 300,
          messages,
        }),
      });
    } catch (err) {
      console.error('[nostalgiaChat] OpenAI fetch error', err);
      throw new HttpsError("internal", "AI fetch failed: " + (err instanceof Error ? err.message : String(err)));
    }

    console.log('[nostalgiaChat] OpenAI response status', response && response.status);
    if (!response || !response.ok) {
      let errorText = '';
      try { errorText = await response.text(); } catch {}
      console.error('[nostalgiaChat] OpenAI bad response', response && response.status, errorText);
      throw new HttpsError("internal", "AI service unavailable. Status: " + (response && response.status) + ", Body: " + errorText);
    }

    let data;
    try {
      data = (await response.json()) as { choices?: Array<{ message?: { content?: string } }> };
    } catch (err) {
      console.error('[nostalgiaChat] OpenAI JSON parse error', err);
      throw new HttpsError("internal", "AI JSON parse error: " + (err instanceof Error ? err.message : String(err)));
    }
    const reply = String(data.choices?.[0]?.message?.content ?? "").trim();

    if (!reply) {
      console.error('[nostalgiaChat] OpenAI empty reply', data);
      throw new HttpsError("internal", "AI returned an empty response.");
    }

    console.log('[nostalgiaChat] Success', { reply });
    return { reply: reply.slice(0, 1500) };
  },
);
