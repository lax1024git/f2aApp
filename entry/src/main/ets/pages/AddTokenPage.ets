import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { TokenRecord, OtpAlgorithm, OtpType } from '../model/TokenRecord';
import { TokenRepository } from '../model/TokenRepository';
import { Base32 } from '../common/Base32';
import { OtpAuth } from '../common/OtpAuth';
import { OtpEngine } from '../common/OtpEngine';

@Component
export struct AddTokenPage {
  @Consume('navStack') navStack: NavPathStack = new NavPathStack();
  onChanged: () => void = () => {};
  @State issuer: string = '';
  @State account: string = '';
  @State secret: string = '';
  @State otpType: OtpType = 'totp';
  @State algorithm: OtpAlgorithm = 'SHA1';
  @State digits: number = 6;
  @State period: string = '30';
  @State uriText: string = '';
  @State preview: string = '';

  private async applyUri(): Promise<void> {
    try {
      const token = OtpAuth.parse(this.uriText);
      this.issuer = token.issuer;
      this.account = token.account;
      this.secret = token.secret;
      this.otpType = token.type;
      this.algorithm = token.algorithm;
      this.digits = token.digits;
      this.period = `${token.period}`;
      this.preview = await OtpEngine.generate(token);
      promptAction.showToast({ message: '已解析 otpauth 链接' });
    } catch (err) {
      promptAction.showToast({ message: (err as Error).message ?? '解析失败' });
    }
  }

  private async scanQr(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
      };
      const result: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, options);
      if (result.originalValue.length > 0) {
        this.uriText = result.originalValue;
        await this.applyUri();
      }
    } catch (_err) {
      promptAction.showToast({ message: '扫码取消或设备不支持扫码' });
    }
  }

  private async save(): Promise<void> {
    if (!Base32.isValid(this.secret)) {
      promptAction.showToast({ message: '请输入有效的 Base32 密钥' });
      return;
    }
    const token = new TokenRecord();
    token.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    token.issuer = this.issuer.trim();
    token.account = this.account.trim();
    token.secret = Base32.normalize(this.secret);
    token.type = this.otpType;
    token.algorithm = this.algorithm;
    token.digits = this.digits;
    token.period = Number(this.period);
    if (token.period <= 0) {
      token.period = 30;
    }
    token.counter = 0;
    token.createdAt = Date.now();
    try {
      this.preview = await OtpEngine.generate(token);
    } catch (_err) {
      promptAction.showToast({ message: '无法根据该密钥生成验证码' });
      return;
    }
    await TokenRepository.add(token);
    this.onChanged();
    promptAction.showToast({ message: '令牌已保存' });
    this.navStack.pop();
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('添加令牌')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .width('100%')

        TextInput({ text: this.uriText, placeholder: '粘贴 otpauth:// 链接（可选）' })
          .width('100%')
          .onChange((value: string) => {
            this.uriText = value;
          })
        Row({ space: 8 }) {
          Button('解析链接')
            .layoutWeight(1)
            .onClick(() => {
              this.applyUri();
            })
          Button('扫描二维码')
            .layoutWeight(1)
            .backgroundColor($r('app.color.brand'))
            .onClick(() => {
              this.scanQr();
            })
        }
        .width('100%')

        TextInput({ text: this.issuer, placeholder: '发行方，如 GitHub' })
          .width('100%')
          .onChange((value: string) => {
            this.issuer = value;
          })
        TextInput({ text: this.account, placeholder: '账户名 / 邮箱' })
          .width('100%')
          .onChange((value: string) => {
            this.account = value;
          })
        TextInput({ text: this.secret, placeholder: '密钥（Base32）' })
          .width('100%')
          .onChange((value: string) => {
            this.secret = value;
          })

        Row({ space: 12 }) {
          Toggle({ type: ToggleType.Checkbox, isOn: this.otpType === 'hotp' })
            .onChange((isOn: boolean) => {
              this.otpType = isOn ? 'hotp' : 'totp';
            })
          Text(this.otpType === 'hotp' ? 'HOTP 计数器模式' : 'TOTP 时间模式（推荐）')
            .fontSize(14)
        }
        .width('100%')

        Text('算法')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
        Select([
          { value: 'SHA1' },
          { value: 'SHA256' },
          { value: 'SHA512' }
        ])
          .selected(this.algorithm === 'SHA256' ? 1 : (this.algorithm === 'SHA512' ? 2 : 0))
          .value(this.algorithm)
          .onSelect((_index: number, value: string) => {
            if (value === 'SHA256' || value === 'SHA512' || value === 'SHA1') {
              this.algorithm = value as OtpAlgorithm;
            }
          })
          .width('100%')

        Row({ space: 12 }) {
          Column() {
            Text('位数')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
            Select([{ value: '6' }, { value: '8' }])
              .selected(this.digits === 8 ? 1 : 0)
              .value(`${this.digits}`)
              .onSelect((_index: number, value: string) => {
                this.digits = value === '8' ? 8 : 6;
              })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.otpType === 'totp') {
            Column() {
              Text('周期（秒）')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              TextInput({ text: this.period, placeholder: '30' })
                .type(InputType.Number)
                .onChange((value: string) => {
                  this.period = value;
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .width('100%')

        if (this.preview.length > 0) {
          Text(`预览：${OtpEngine.formatCode(this.preview)}`)
            .fontSize(16)
            .fontColor($r('app.color.brand'))
            .width('100%')
        }

        Button('保存令牌')
          .width('100%')
          .height(44)
          .backgroundColor($r('app.color.brand'))
          .margin({ top: 8 })
          .onClick(() => {
            this.save();
          })
      }
      .padding(20)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
