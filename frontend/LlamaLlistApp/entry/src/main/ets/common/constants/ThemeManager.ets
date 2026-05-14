// frontend/entry/src/main/ets/common/constants/ThemeManager.ets

import { ThemeConfig, THEMES, getThemeById } from './Theme';

@Observed
export class ThemeManager {
  @Track currentTheme: ThemeConfig = THEMES[0];

  constructor() {
    this.loadTheme();
  }

  getTheme(): ThemeConfig {
    return this.currentTheme;
  }

  setTheme(themeId: number): void {
    const theme = getThemeById(themeId);
    if (theme) {
      this.currentTheme = theme;
      AppStorage.setOrCreate('currentThemeId', themeId);
      AppStorage.setOrCreate('themeBg', theme.background);
      AppStorage.setOrCreate('themePrimary', theme.primary);
      AppStorage.setOrCreate('themeText', theme.text);
      AppStorage.setOrCreate('themeSecondary', theme.secondary);
    }
  }

  loadTheme(): void {
    const savedId = AppStorage.get('currentThemeId') as number;
    if (savedId) {
      const theme = getThemeById(savedId);
      this.currentTheme = theme;
      AppStorage.setOrCreate('themeBg', theme.background);
      AppStorage.setOrCreate('themePrimary', theme.primary);
      AppStorage.setOrCreate('themeText', theme.text);
      AppStorage.setOrCreate('themeSecondary', theme.secondary);
    }
  }
}

export const appTheme = new ThemeManager();
