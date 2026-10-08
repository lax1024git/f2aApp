import { TokenRecord } from '../model/TokenRecord';
import { TokenCard } from '../components/TokenCard';
import { TokenRepository } from '../model/TokenRepository';

@Component
export struct HomePage {
  @Consume('navStack') navStack: NavPathStack = new NavPathStack();
  @Link tokens: TokenRecord[];
  @State keyword: string = '';

  private confirmDelete(item: TokenRecord): void {
    AlertDialog.show({
      title: '是否删除',
      message: `确定删除 ${item.displayName()} 吗？`,
      primaryButton: {
        value: '否',
        action: () => {
        }
      },
      secondaryButton: {
        value: '是',
        fontColor: Color.Red,
        action: async () => {
          await TokenRepository.remove(item.id);
          this.tokens = TokenRepository.tokens.slice();
        }
      }
    });
  }

  private filtered(): TokenRecord[] {
    const key = this.keyword.trim().toLowerCase();
    if (key.length === 0) {
      return this.tokens;
    }
    return this.tokens.filter((item: TokenRecord) => {
      return item.issuer.toLowerCase().includes(key) || item.account.toLowerCase().includes(key);
    });
  }

  build() {
    Stack() {
      Column() {
      Row() {
        Text('F2A')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('设置')
          .fontSize(14)
          .height(36)
          .backgroundColor($r('app.color.card_background'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.navStack.pushPath({ name: 'settings' });
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      TextInput({ text: this.keyword, placeholder: '搜索发行方或账户' })
        .width('90%')
        .height(40)
        .backgroundColor($r('app.color.card_background'))
        .borderRadius(20)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.keyword = value;
        })

      if (this.tokens.length === 0) {
        Column() {
          Text('还没有令牌')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text('点击右下角添加，或粘贴 otpauth 链接')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.filtered(), (item: TokenRecord) => {
            ListItem() {
              TokenCard({
                token: item,
                onOpen: (id: string) => {
                  this.navStack.pushPath({ name: 'detail', param: id });
                },
                onDelete: () => {
                  this.confirmDelete(item);
                }
              })
            }
          }, (item: TokenRecord) => item.id)
        }
        .width('90%')
        .layoutWeight(1)
        .margin({ top: 12, bottom: 80 })
        .scrollBar(BarState.Off)
      }
      }
      .width('100%')
      .height('100%')

      Button({ type: ButtonType.Circle }) {
        Text('+')
          .fontSize(28)
          .fontColor(Color.White)
      }
      .width(56)
      .height(56)
      .backgroundColor($r('app.color.brand'))
      .position({ x: '80%', y: '86%' })
      .onClick(() => {
        this.navStack.pushPath({ name: 'add' });
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}
