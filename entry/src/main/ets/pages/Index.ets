import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { TokenRecord } from '../model/TokenRecord';
import { TokenRepository } from '../model/TokenRepository';
import { AppSettings } from '../model/AppSettings';
import { HomePage } from './HomePage';
import { AddTokenPage } from './AddTokenPage';
import { TokenDetailPage } from './TokenDetailPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @Provide('navStack') navStack: NavPathStack = new NavPathStack();
  @State tokens: TokenRecord[] = [];
  @State ready: boolean = false;
  @State unlocked: boolean = false;
  @State pinInput: string = '';

  aboutToAppear(): void {
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await AppSettings.init(context);
    await TokenRepository.init(context);
    this.tokens = TokenRepository.tokens;
    this.unlocked = AppSettings.unlocked;
    this.ready = true;
  }

  private refreshTokens(): void {
    this.tokens = TokenRepository.tokens.slice();
  }

  private async unlock(): Promise<void> {
    const ok = await AppSettings.verifyPin(this.pinInput);
    if (ok) {
      this.unlocked = true;
      this.pinInput = '';
    } else {
      promptAction.showToast({ message: 'PIN 不正确' });
    }
  }

  @Builder
  destinationBuilder(name: string, param: Object) {
    if (name === 'add') {
      AddTokenPage({
        onChanged: () => {
          this.refreshTokens();
        }
      })
    } else if (name === 'settings') {
      SettingsPage({
        onChanged: () => {
          this.refreshTokens();
        }
      })
    } else if (name === 'detail') {
      TokenDetailPage({
        tokenId: `${param}`,
        onChanged: () => {
          this.refreshTokens();
        }
      })
    }
  }

  build() {
    Stack() {
      Navigation(this.navStack) {
        HomePage({ tokens: $tokens })
      }
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.destinationBuilder)

      if (this.ready && !this.unlocked) {
        Column({ space: 16 }) {
          Text('F2A 已锁定')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('输入 PIN 查看令牌')
            .fontSize(14)
            .fontColor('#CCFFFFFF')
          TextInput({ text: this.pinInput, placeholder: 'PIN' })
            .type(InputType.NUMBER_PASSWORD)
            .width('70%')
            .onChange((value: string) => {
              this.pinInput = value;
            })
          Button('解锁')
            .width('70%')
            .backgroundColor($r('app.color.brand'))
            .onClick(() => {
              this.unlock();
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#CC182431')
      }
    }
    .width('100%')
    .height('100%')
  }
}
