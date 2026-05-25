declare function requireNapi(moduleName: string, isAppModule?: boolean): Object;

export interface KeywordNativeApi {
  extractKeywords(text: string, topK: number): string[];
}

let nativeApi: KeywordNativeApi | null = null;

try {
  nativeApi = requireNapi('keyword_napi', true) as KeywordNativeApi;
} catch (_) {
  nativeApi = null;
}

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