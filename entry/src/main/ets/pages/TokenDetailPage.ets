import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { TokenRecord } from '../model/TokenRecord';
import { TokenRepository } from '../model/TokenRepository';
import { OtpAuth } from '../common/OtpAuth';
import { OtpEngine } from '../common/OtpEngine';

@Component
export struct TokenDetailPage {
  @Consume('navStack') navStack: NavPathStack = new NavPathStack();
  @Prop tokenId: string = '';
  onChanged: () => void = () => {};
  @State token: TokenRecord = new TokenRecord();
  @State code: string = '------';
  @State remain: number = 30;
  private timerId: number = -1;

  aboutToAppear(): void {
    const found = TokenRepository.find(this.tokenId);
    if (found) {
      this.token = found.clone();
    }
    this.refresh();
    this.timerId = setInterval(() => {
      this.refresh();
    }, 400);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
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

  private async bumpHotp(): Promise<void> {
    if (this.token.type !== 'hotp') {
      return;
    }
    this.token.counter += 1;
    await TokenRepository.update(this.token);
    this.onChanged();
    await this.refresh();
  }

  private copyUri(): void {
    const uri = OtpAuth.toUri(this.token);
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, uri);
    pasteboard.getSystemPasteboard().setData(data);
    promptAction.showToast({ message: 'otpauth 链接已复制，请妥善保管' });
  }

  private deleteToken(): void {
    AlertDialog.show({
      title: '删除令牌',
      message: `确定删除 ${this.token.displayName()} 吗？删除后无法恢复。`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => {
          await TokenRepository.remove(this.token.id);
          this.onChanged();
          this.navStack.pop();
        }
      }
    });
  }

  build() {
    Column({ space: 16 }) {
      Text(this.token.displayName())
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Column() {
        Text(OtpEngine.formatCode(this.code))
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand'))
        if (this.token.type === 'totp') {
          Text(`${this.remain} 秒后刷新`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
          Progress({ value: this.remain, total: this.token.period, type: ProgressType.Linear })
            .width('100%')
            .color($r('app.color.brand'))
            .margin({ top: 12 })
        } else {
          Text(`计数器：${this.token.counter}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
          Button('生成下一个 HOTP')
            .margin({ top: 12 })
            .onClick(() => {
              this.bumpHotp();
            })
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor($r('app.color.card_background'))
      .borderRadius(16)

      Text(`算法 ${this.token.algorithm}  ·  ${this.token.digits} 位`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Button('复制 otpauth 链接')
        .width('100%')
        .onClick(() => {
          this.copyUri();
        })
      Button('删除令牌')
        .width('100%')
        .backgroundColor($r('app.color.danger'))
        .onClick(() => {
          this.deleteToken();
        })
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
