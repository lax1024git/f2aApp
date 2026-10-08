import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { TokenRecord } from './TokenRecord';

const STORE_NAME: string = 'f2a_store';
const TOKENS_KEY: string = 'tokens';

export class TokenRepository {
  private static store: preferences.Preferences | undefined = undefined;
  static tokens: TokenRecord[] = [];

  static async init(context: common.UIAbilityContext): Promise<void> {
    TokenRepository.store = await preferences.getPreferences(context, STORE_NAME);
    await TokenRepository.reload();
  }

  static async reload(): Promise<void> {
    if (!TokenRepository.store) {
      return;
    }
    const raw = await TokenRepository.store.get(TOKENS_KEY, '[]') as string;
    const parsed = JSON.parse(raw) as Object[];
    const list: TokenRecord[] = [];
    for (let i = 0; i < parsed.length; i++) {
      list.push(TokenRecord.fromJson(parsed[i] as Record<string, Object>));
    }
    TokenRepository.tokens = list;
  }

  static async saveAll(): Promise<void> {
    if (!TokenRepository.store) {
      return;
    }
    const payload: Record<string, Object>[] = [];
    for (let i = 0; i < TokenRepository.tokens.length; i++) {
      payload.push(TokenRepository.tokens[i].toJson());
    }
    await TokenRepository.store.put(TOKENS_KEY, JSON.stringify(payload));
    await TokenRepository.store.flush();
  }

  static async add(token: TokenRecord): Promise<void> {
    TokenRepository.tokens.unshift(token);
    await TokenRepository.saveAll();
  }

  static async update(token: TokenRecord): Promise<void> {
    const index = TokenRepository.tokens.findIndex((item: TokenRecord) => item.id === token.id);
    if (index >= 0) {
      TokenRepository.tokens[index] = token;
      await TokenRepository.saveAll();
    }
  }

  static async remove(id: string): Promise<void> {
    TokenRepository.tokens = TokenRepository.tokens.filter((item: TokenRecord) => item.id !== id);
    await TokenRepository.saveAll();
  }

  static find(id: string): TokenRecord | undefined {
    return TokenRepository.tokens.find((item: TokenRecord) => item.id === id);
  }

  static exportJson(): string {
    const payload: Record<string, Object>[] = [];
    for (let i = 0; i < TokenRepository.tokens.length; i++) {
      payload.push(TokenRepository.tokens[i].toJson());
    }
    return JSON.stringify(payload, null, 2);
  }

  static async importJson(text: string): Promise<number> {
    const parsed = JSON.parse(text) as Object[];
    let added = 0;
    const existingSecrets = new Set<string>();
    for (let i = 0; i < TokenRepository.tokens.length; i++) {
      existingSecrets.add(TokenRepository.tokens[i].secret);
    }
    for (let i = 0; i < parsed.length; i++) {
      const token = TokenRecord.fromJson(parsed[i] as Record<string, Object>);
      if (token.secret.length === 0) {
        continue;
      }
      if (existingSecrets.has(token.secret)) {
        continue;
      }
      if (token.id.length === 0) {
        token.id = `${Date.now()}_${i}`;
      }
      TokenRepository.tokens.unshift(token);
      existingSecrets.add(token.secret);
      added++;
    }
    await TokenRepository.saveAll();
    return added;
  }
}
