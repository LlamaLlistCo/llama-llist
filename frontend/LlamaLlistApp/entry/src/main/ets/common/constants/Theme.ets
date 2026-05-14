// frontend/entry/src/main/ets/common/constants/Theme.ets

export interface ThemeConfig {
  id: number;
  name: string;
  primary: string;
  secondary: string;
  background: string;
  accent: string;
  text: string;
  isDark: boolean;
}

export const THEMES: ThemeConfig[] = [
  {
    id: 1,
    name: '原野棕',
    primary: '#705C53',
    secondary: '#A89982',
    background: '#F9F8F4',
    accent: '#E67E22',
    text: '#4A3933',
    isDark: false
  },
  {
    id: 2,
    name: '晴空蓝',
    primary: '#4A90C4',
    secondary: '#7FB3D3',
    background: '#EFF6FB',
    accent: '#2980B9',
    text: '#1A3A52',
    isDark: false
  },
  {
    id: 3,
    name: '嫩芽绿',
    primary: '#5A9E6F',
    secondary: '#8FBF9F',
    background: '#F0F8F2',
    accent: '#27AE60',
    text: '#1B4332',
    isDark: false
  },
  {
    id: 4,
    name: '樱花粉',
    primary: '#C4788A',
    secondary: '#D9A0AE',
    background: '#FDF0F3',
    accent: '#E91E8C',
    text: '#4A1A28',
    isDark: false
  },
  {
    id: 5,
    name: '薰衣草紫',
    primary: '#7E6FAE',
    secondary: '#A99FCC',
    background: '#F3F0FA',
    accent: '#9B59B6',
    text: '#2E1A47',
    isDark: false
  }
];

export function getThemeById(id: number): ThemeConfig {
  return THEMES.find(t => t.id === id) || THEMES[0];
}
