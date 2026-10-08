import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { TokenRecord } from '../model/TokenRecord';
import { OtpEngine } from '../common/OtpEngine';

@Component
export struct TokenCard {
  @Prop token: TokenRecord = new TokenRecord();
  onOpen: (id: string) => void = () => {};
  onDelete: (id: string) => void = () => {};
  @State code: string = '------';
  @State remain: number = 30;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.refresh();
    this.timerId = setInterval(() => {
      this.refresh();
    }, 400);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private async refresh(): Promise<void> {
    try {
      this.code = await OtpEngine.generate(this.token);
      this.remain = this.token.type === 'totp' ? OtpEngine.remaining(this.token.period) : 0;
    } catch (_err) {
      this.code = '------';
    }
  }

  private copyCode(): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.code);
    pasteboard.getSystemPasteboard().setData(data);
    promptAction.showToast({ message: '验证码已复制' });
  }

  build() {
    Column() {
      Row() {
        Button('删除')
          .fontSize(12)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor('#FDECEA')
          .fontColor('#D94838')
          .margin({ right: 10 })
          .onClick(() => {
            this.onDelete(this.token.id);
          })
        Column() {
          Text(this.token.issuer.length > 0 ? this.token.issuer : '令牌')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.token.account)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.token.type === 'totp') {
          Progress({
            value: this.remain,
            total: this.token.period,
            type: ProgressType.Ring
          })
            .width(28)
            .height(28)
            .color($r('app.color.brand'))
            .backgroundColor('#E5E5E5')
        } else {
          Text('HOTP')
            .fontSize(10)
            .fontColor($r('app.color.brand'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .borderRadius(8)
            .backgroundColor('#E8F0FE')
        }
      }
      .width('100%')

      Text(OtpEngine.formatCode(this.code))
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand'))
        .letterSpacing(1)
        .margin({ top: 12 })
        .width('100%')
    }
    .padding(16)
    .backgroundColor($r('app.color.card_background'))
    .borderRadius(16)
    .width('100%')
    .onClick(() => {
      this.copyCode();
    })
  }
}
