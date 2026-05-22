import router from '@ohos.router';

@Entry
@Component
struct SplashPage {
  @State bgopacity: number = 0;
  @State translateY: number = 40;
  @StorageLink('themeBg') themeBg: string = '#F9F8F4';
  private timer: number = -1;

  build() {
    Column() {
      Blank()

      Column({ space: 20 }) {
        Text('🦙')
          .fontSize(80)
          .shadow({ radius: 20, color: '#20705C53', offsetY: 10 })

        Text('Llama Llist')
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4A3933')
          .letterSpacing(2)

        Text('在灵感的草地上，像羊驼一样自由反刍')
          .fontSize(16)
          .fontColor('#A89982')
          .margin({ top: 10 })
      }
      .opacity(this.bgopacity)
      .translate({ y: this.translateY })

      Blank()

      Column({ space: 10 }) {
        LoadingProgress()
          .width(32)
          .height(32)
          .color('#705C53')  // 改回深色，更明显

        Text('正在加载...')
          .fontSize(13)
          .fontColor('#9999AA')
      }
      .opacity(this.bgopacity)
      .margin({ bottom: 60 })

      Text('Designed by Llama Studio')
        .fontSize(12)
        .fontColor('#D2C4B0')
        .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBg)
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
    .onAppear(() => {
      // 页面出现时立即执行动画
      animateTo({ duration: 800, curve: Curve.EaseOut }, () => {
        this.bgopacity = 1;
        this.translateY = 0;
      });

      // 2.5 秒后跳转
      this.timer = setTimeout(() => {
        router.replaceUrl({ url: 'pages/Index' });
      }, 2500);
    })
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearTimeout(this.timer);
    }
  }
}