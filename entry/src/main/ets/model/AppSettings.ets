import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const STORE_NAME: string = 'f2a_settings';
const PIN_HASH_KEY: string = 'pin_hash';
const LOCK_ENABLED_KEY: string = 'lock_enabled';

export class AppSettings {
  private static store: preferences.Preferences | undefined = undefined;
  static lockEnabled: boolean = false;
  static unlocked: boolean = false;
  private static pinHash: string = '';

  static async init(context: common.UIAbilityContext): Promise<void> {
    AppSettings.store = await preferences.getPreferences(context, STORE_NAME);
    AppSettings.lockEnabled = (await AppSettings.store.get(LOCK_ENABLED_KEY, false)) as boolean;
    AppSettings.pinHash = (await AppSettings.store.get(PIN_HASH_KEY, '')) as string;
    if (!AppSettings.lockEnabled || AppSettings.pinHash.length === 0) {
      AppSettings.unlocked = true;
    }
  }

  static async setPin(pin: string): Promise<void> {
    if (!AppSettings.store) {
      return;
    }
    AppSettings.pinHash = await AppSettings.hash(pin);
    AppSettings.lockEnabled = true;
    await AppSettings.store.put(PIN_HASH_KEY, AppSettings.pinHash);
    await AppSettings.store.put(LOCK_ENABLED_KEY, true);
    await AppSettings.store.flush();
    AppSettings.unlocked = true;
  }

  static async clearPin(): Promise<void> {
    if (!AppSettings.store) {
      return;
    }
    AppSettings.pinHash = '';
    AppSettings.lockEnabled = false;
    AppSettings.unlocked = true;
    await AppSettings.store.put(PIN_HASH_KEY, '');
    await AppSettings.store.put(LOCK_ENABLED_KEY, false);
    await AppSettings.store.flush();
  }

  static async verifyPin(pin: string): Promise<boolean> {
    const hashed = await AppSettings.hash(pin);
    const ok = hashed === AppSettings.pinHash;
    if (ok) {
      AppSettings.unlocked = true;
    }
    return ok;
  }

  private static async hash(pin: string): Promise<string> {
    const bytes = new util.TextEncoder().encodeInto(pin);
    const md = cryptoFramework.createMd('SHA256');
    await md.update({ data: bytes });
    const digest = await md.digest();
    let hex = '';
    for (let i = 0; i < digest.data.length; i++) {
      const part = digest.data[i].toString(16);
      hex += part.length === 1 ? `0${part}` : part;
    }
    return hex;
  }
}
