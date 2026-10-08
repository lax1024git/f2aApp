export type OtpType = 'totp' | 'hotp';
export type OtpAlgorithm = 'SHA1' | 'SHA256' | 'SHA512';

export class TokenRecord {
  id: string = '';
  issuer: string = '';
  account: string = '';
  secret: string = '';
  type: OtpType = 'totp';
  algorithm: OtpAlgorithm = 'SHA1';
  digits: number = 6;
  period: number = 30;
  counter: number = 0;
  createdAt: number = 0;

  displayName(): string {
    if (this.issuer.length > 0 && this.account.length > 0) {
      return `${this.issuer} · ${this.account}`;
    }
    if (this.issuer.length > 0) {
      return this.issuer;
    }
    if (this.account.length > 0) {
      return this.account;
    }
    return '未命名令牌';
  }

  clone(): TokenRecord {
    const copy = new TokenRecord();
    copy.id = this.id;
    copy.issuer = this.issuer;
    copy.account = this.account;
    copy.secret = this.secret;
    copy.type = this.type;
    copy.algorithm = this.algorithm;
    copy.digits = this.digits;
    copy.period = this.period;
    copy.counter = this.counter;
    copy.createdAt = this.createdAt;
    return copy;
  }

  static fromJson(raw: Record<string, Object>): TokenRecord {
    const item = new TokenRecord();
    item.id = `${raw['id'] ?? ''}`;
    item.issuer = `${raw['issuer'] ?? ''}`;
    item.account = `${raw['account'] ?? ''}`;
    item.secret = `${raw['secret'] ?? ''}`;
    const typeText = `${raw['type'] ?? 'totp'}`;
    item.type = typeText === 'hotp' ? 'hotp' : 'totp';
    const algoText = `${raw['algorithm'] ?? 'SHA1'}`.toUpperCase();
    if (algoText === 'SHA256') {
      item.algorithm = 'SHA256';
    } else if (algoText === 'SHA512') {
      item.algorithm = 'SHA512';
    } else {
      item.algorithm = 'SHA1';
    }
    item.digits = Number(raw['digits'] ?? 6);
    item.period = Number(raw['period'] ?? 30);
    item.counter = Number(raw['counter'] ?? 0);
    item.createdAt = Number(raw['createdAt'] ?? 0);
    if (item.digits !== 8) {
      item.digits = 6;
    }
    if (item.period <= 0) {
      item.period = 30;
    }
    return item;
  }

  toJson(): Record<string, Object> {
    const raw: Record<string, Object> = {};
    raw['id'] = this.id;
    raw['issuer'] = this.issuer;
    raw['account'] = this.account;
    raw['secret'] = this.secret;
    raw['type'] = this.type;
    raw['algorithm'] = this.algorithm;
    raw['digits'] = this.digits;
    raw['period'] = this.period;
    raw['counter'] = this.counter;
    raw['createdAt'] = this.createdAt;
    return raw;
  }
}
