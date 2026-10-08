import { TokenRecord } from '../model/TokenRecord';
import { Base32 } from './Base32';

export class OtpAuth {
  static parse(uriText: string): TokenRecord {
    const trimmed = uriText.trim();
    if (!trimmed.toLowerCase().startsWith('otpauth://')) {
      throw new Error('不是有效的 otpauth 链接');
    }
    const withoutScheme = trimmed.substring('otpauth://'.length);
    const slash = withoutScheme.indexOf('/');
    if (slash < 0) {
      throw new Error('otpauth 缺少账户路径');
    }
    const typeText = withoutScheme.substring(0, slash).toLowerCase();
    const rest = withoutScheme.substring(slash + 1);
    const queryIndex = rest.indexOf('?');
    const labelRaw = queryIndex >= 0 ? rest.substring(0, queryIndex) : rest;
    const query = queryIndex >= 0 ? rest.substring(queryIndex + 1) : '';
    const params = OtpAuth.parseQuery(query);
    const secret = `${params['secret'] ?? ''}`;
    if (!Base32.isValid(secret)) {
      throw new Error('密钥无效，请检查 Base32 编码');
    }

    const label = decodeURIComponent(labelRaw.replace(/\+/g, ' '));
    let issuer = `${params['issuer'] ?? ''}`;
    let account = label;
    const colon = label.indexOf(':');
    if (colon >= 0) {
      if (issuer.length === 0) {
        issuer = label.substring(0, colon);
      }
      account = label.substring(colon + 1);
    }

    const token = new TokenRecord();
    token.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    token.issuer = issuer.trim();
    token.account = account.trim();
    token.secret = Base32.normalize(secret);
    token.type = typeText === 'hotp' ? 'hotp' : 'totp';
    const algo = `${params['algorithm'] ?? 'SHA1'}`.toUpperCase();
    if (algo === 'SHA256') {
      token.algorithm = 'SHA256';
    } else if (algo === 'SHA512') {
      token.algorithm = 'SHA512';
    } else {
      token.algorithm = 'SHA1';
    }
    token.digits = Number(params['digits'] ?? 6) === 8 ? 8 : 6;
    token.period = Number(params['period'] ?? 30);
    if (token.period <= 0) {
      token.period = 30;
    }
    token.counter = Number(params['counter'] ?? 0);
    token.createdAt = Date.now();
    return token;
  }

  static toUri(token: TokenRecord): string {
    const label = encodeURIComponent(
      token.issuer.length > 0 ? `${token.issuer}:${token.account}` : token.account
    );
    const parts: string[] = [
      `secret=${token.secret}`,
      `algorithm=${token.algorithm}`,
      `digits=${token.digits}`
    ];
    if (token.issuer.length > 0) {
      parts.push(`issuer=${encodeURIComponent(token.issuer)}`);
    }
    if (token.type === 'totp') {
      parts.push(`period=${token.period}`);
    } else {
      parts.push(`counter=${token.counter}`);
    }
    return `otpauth://${token.type}/${label}?${parts.join('&')}`;
  }

  private static parseQuery(query: string): Record<string, string> {
    const result: Record<string, string> = {};
    if (query.length === 0) {
      return result;
    }
    const pairs = query.split('&');
    for (let i = 0; i < pairs.length; i++) {
      const pair = pairs[i];
      const eq = pair.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const key = decodeURIComponent(pair.substring(0, eq)).toLowerCase();
      const value = decodeURIComponent(pair.substring(eq + 1).replace(/\+/g, ' '));
      result[key] = value;
    }
    return result;
  }
}
