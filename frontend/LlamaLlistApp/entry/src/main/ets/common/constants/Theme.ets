export interface ThemeConfig {
  id: number;
  name: string;
  primary: string;
  secondary: string;
  background: string;
  accent: string;
  text: string;
  card: string;
  soft: string;
  mascot: string;
  slogan: string;
  isDark: boolean;
}

export const THEMES: ThemeConfig[] = [
  {
    id: 1,
    name: '羊驼草甸',
    primary: '#6F7F4F',
    secondary: '#B7A887',
    background: '#F8F5EC',
    accent: '#D9A85F',
    text: '#3F382F',
    card: '#FFFFFF',
    soft: '#EEF3E5',
    mascot: '🦙',
    slogan: '在草甸里收集灵感',
    isDark: false
  },
  {
    id: 2,
    name: '安第斯纸本',
    primary: '#8A654A',
    secondary: '#C8A978',
    background: '#FAF3E7',
    accent: '#C9895B',
    text: '#453328',
    card: '#FFFDF8',
    soft: '#F3E4D1',
    mascot: '⛰️',
    slogan: '像手帐一样安静整理',
    isDark: false
  },
  {
    id: 3,
    name: '云朵羊毛',
    primary: '#5B8FA8',
    secondary: '#A9C7D6',
    background: '#F3FAFC',
    accent: '#86B8C8',
    text: '#253D4A',
    card: '#FFFFFF',
    soft: '#E6F3F8',
    mascot: '☁️',
    slogan: '把想法织成轻软清单',
    isDark: false
  },
  {
    id: 4,
    name: '山谷晨光',
    primary: '#70875A',
    secondary: '#D1BF84',
    background: '#FBF7E8',
    accent: '#E2B85F',
    text: '#34402C',
    card: '#FFFFFF',
    soft: '#F1EBCB',
    mascot: '🌄',
    slogan: '让今天的目标慢慢发光',
    isDark: false
  },
  {
    id: 5,
    name: '极简牧场',
    primary: '#5F6D5A',
    secondary: '#A7A08E',
    background: '#F7F6F1',
    accent: '#9A7D58',
    text: '#323530',
    card: '#FFFFFF',
    soft: '#EDEBE2',
    mascot: '⌁',
    slogan: '少一点干扰，多一点完成',
    isDark: false
  },
  {
    id: 6,
    name: 'AI 驼队工作台',
    primary: '#51606F',
    secondary: '#95A3A8',
    background: '#F4F7F6',
    accent: '#79A58C',
    text: '#263238',
    card: '#FFFFFF',
    soft: '#E7EFEC',
    mascot: '✦',
    slogan: '让 AI 和你一起整理路线',
    isDark: false
  }
];

export function getThemeById(id: number): ThemeConfig {
  return THEMES.find(t => t.id === id) || THEMES[0];
}
