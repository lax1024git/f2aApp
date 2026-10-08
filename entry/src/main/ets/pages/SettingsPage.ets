import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { TokenRepository } from '../model/TokenRepository';
import { AppSettings } from '../model/AppSettings';

@Component
export struct SettingsPage {
  @Consume('navStack') navStack: NavPathStack = new NavPathStack();
  onChanged: () => void = () => {};
  @State pin: string = '';
  @State confirmPin: string = '';
  @State lockEnabled: boolean = AppSettings.lockEnabled;

  private async enableLock(): Promise<void> {
    if (this.pin.length < 4 || this.pin !== this.confirmPin) {
      promptAction.showToast({ message: '请设置至少 4 位 PIN，并保持两次一致' });
      return;
    }
    await AppSettings.setPin(this.pin);
    this.lockEnabled = true;
    this.pin = '';
    this.confirmPin = '';
    promptAction.showToast({ message: '应用锁已开启' });
  }

  private async disableLock(): Promise<void> {
    await AppSettings.clearPin();
    this.lockEnabled = false;
    promptAction.showToast({ message: '应用锁已关闭' });
  }

  private exportTokens(): void {
    const json = TokenRepository.exportJson();
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, json);
    pasteboard.getSystemPasteboard().setData(data);
    promptAction.showToast({ message: '备份 JSON 已复制，请离线妥善保存' });
  }

  private importTokens(): void {
    pasteboard.getSystemPasteboard().getData().then(async (data: pasteboard.PasteData) => {
      const text = data.getPrimaryText();
      try {
        const added = await TokenRepository.importJson(text);
        this.onChanged();
        promptAction.showToast({ message: `已导入 ${added} 条令牌` });
      } catch (_err) {
        promptAction.showToast({ message: '剪贴板内容不是有效的 F2A 备份' });
      }
    }).catch(() => {
      promptAction.showToast({ message: '无法读取剪贴板' });
    });
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        Column({ space: 10 }) {
          Text('应用锁')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text(this.lockEnabled ? '已开启 PIN 保护' : '未开启。开启后每次进入应用需输入 PIN。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          if (!this.lockEnabled) {
            TextInput({ text: this.pin, placeholder: '设置 PIN（至少 4 位）' })
              .type(InputType.NUMBER_PASSWORD)
              .onChange((value: string) => {
                this.pin = value;
              })
            TextInput({ text: this.confirmPin, placeholder: '再次输入 PIN' })
              .type(InputType.NUMBER_PASSWORD)
              .onChange((value: string) => {
                this.confirmPin = value;
              })
            Button('开启应用锁')
              .width('100%')
              .backgroundColor($r('app.color.brand'))
              .onClick(() => {
                this.enableLock();
              })
          } else {
            Button('关闭应用锁')
              .width('100%')
              .onClick(() => {
                this.disableLock();
              })
          }
        }
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .width('100%')

        Column({ space: 10 }) {
          Text('备份与恢复')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text('令牌仅保存在本机。导出为 JSON 后请勿发送到不可信应用。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Button('导出到剪贴板')
            .width('100%')
            .onClick(() => {
              this.exportTokens();
            })
          Button('从剪贴板导入')
            .width('100%')
            .backgroundColor($r('app.color.brand'))
            .onClick(() => {
              this.importTokens();
            })
        }
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .width('100%')

        Column({ space: 8 }) {
          Text('关于 F2A')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width('100%')
          Text('鸿蒙原生二次验证器，兼容 RFC 6238 TOTP / RFC 4226 HOTP，密钥全程本地存储，不上传云端。')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
          Text('版本 1.0.0  ·  HarmonyOS NEXT API 12')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
        }
        .padding(16)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(16)
        .width('100%')
      }
      .padding(20)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
