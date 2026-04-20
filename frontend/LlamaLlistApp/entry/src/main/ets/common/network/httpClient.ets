import http from '@ohos.net.http';
import { AppConfig } from '../constants/Config';

const BASE_URL = AppConfig.BASE_URL;

export async function request<T>(url: string, method: string, data?: object): Promise<T | null> {
  const httpRequest = http.createHttp();
  const options: http.HttpRequestOptions = {
    method: method as http.RequestMethod,
    header: { 'Content-Type': 'application/json' },
    extraData: data ? JSON.stringify(data) : undefined,
    connectTimeout: AppConfig.CONNECT_TIMEOUT,
    readTimeout: AppConfig.READ_TIMEOUT,
  };
  try {
    const response = await httpRequest.request(`${BASE_URL}${url}`, options);

    if (response.responseCode >= 200 && response.responseCode < 300) {
      const result = response.result as string;

      // 处理空响应体
      if (!result || result.trim() === '') {
        return null;
      }

      try {
        return JSON.parse(result) as T;
      } catch (parseError) {
        console.warn('响应不是有效的 JSON 格式:', result);
        return null;
      }
    } else {
      throw new Error(`HTTP ${response.responseCode}`);
    }
  } catch (err) {
    console.error('请求失败', JSON.stringify(err));
    if (err instanceof Error) {
      throw err;
    } else {
      throw new Error(JSON.stringify(err));
    }
  } finally {
    httpRequest.destroy();
  }
}