declare function requireNapi(moduleName: string, isAppModule?: boolean): Object;

export interface MarkdownBlock {
  type: string;
  text: string;
  level?: number;
  checked?: boolean;
  language?: string;
}

export interface MarkdownDocument {
  blocks: MarkdownBlock[];
  extractedTitle: string;
  extractedSummary: string;
}

export interface MarkdownNativeApi {
  parseMarkdown(markdown: string): MarkdownDocument;
  renderMarkdownToPlainText(markdown: string): string;
  exportMarkdown(title: string, summary: string, markdown: string): string;
  // legacy
  extractKeywords(text: string, topK: number): string[];
}

let nativeApi: MarkdownNativeApi | null = null;

try {
  nativeApi = requireNapi('keyword_napi', true) as MarkdownNativeApi;
} catch (_) {
  nativeApi = null;
}

export function hasMarkdownNative(): boolean {
  return !!nativeApi;
}

export function parseMarkdownNative(markdown: string): MarkdownDocument {
  if (!nativeApi) {
    return { blocks: [], extractedTitle: '', extractedSummary: '' };
  }
  try {
    return nativeApi.parseMarkdown(markdown ?? '');
  } catch (_) {
    return { blocks: [], extractedTitle: '', extractedSummary: '' };
  }
}

export function renderMarkdownToPlainTextNative(markdown: string): string {
  if (!nativeApi) {
    return (markdown ?? '').toString();
  }
  try {
    return nativeApi.renderMarkdownToPlainText(markdown ?? '');
  } catch (_) {
    return (markdown ?? '').toString();
  }
}

export function exportMarkdownNative(title: string, summary: string, markdown: string): string {
  if (!nativeApi) {
    // fallback: mimic current export behavior
    const t = (title ?? '').trim() || '未命名笔记';
    const s = (summary ?? '').trim();
    const body = (markdown ?? '').toString();
    return `# ${t}\n\n${s ? `> ${s}\n\n` : ''}${body}`;
  }
  try {
    return nativeApi.exportMarkdown((title ?? ''), (summary ?? ''), (markdown ?? ''));
  } catch (_) {
    const t = (title ?? '').trim() || '未命名笔记';
    const s = (summary ?? '').trim();
    const body = (markdown ?? '').toString();
    return `# ${t}\n\n${s ? `> ${s}\n\n` : ''}${body}`;
  }
}

// Keep existing callers working
export function extractKeywordsNative(text: string, topK: number = 8): string[] {
  if (!nativeApi || !text || text.trim().length === 0) {
    return [];
  }

  try {
    const data = nativeApi.extractKeywords(text, topK);
    if (!data || data.length === 0) {
      return [];
    }
    return data.filter((s: string) => !!s && s.trim().length > 0);
  } catch (_) {
    return [];
  }
}
