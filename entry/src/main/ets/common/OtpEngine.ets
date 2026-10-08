import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { TokenRecord } from '../model/TokenRecord';
import { Base32 } from './Base32';

export class OtpEngine {
  static remaining(period: number, nowMs: number = Date.now()): number {
    const step = period > 0 ? period : 30;
    const seconds = Math.floor(nowMs / 1000);
    return step - (seconds % step);
  }

  static formatCode(code: string): string {
    if (code.length === 8) {
      return `${code.substring(0, 4)} ${code.substring(4)}`;
    }
    if (code.length === 6) {
      return `${code.substring(0, 3)} ${code.substring(3)}`;
    }
    return code;
  }

  static async generate(token: TokenRecord, nowMs: number = Date.now()): Promise<string> {
    const key = Base32.decode(token.secret);
    if (key.length === 0) {
      throw new Error('密钥解码失败');
    }
    let movingFactor: number;
    if (token.type === 'hotp') {
      movingFactor = token.counter;
    } else {
      movingFactor = Math.floor(nowMs / 1000 / token.period);
    }
    const counter = OtpEngine.int64ToBytes(movingFactor);
    const digest = await OtpEngine.hmac(token.algorithm, key, counter);
    const offset = digest[digest.length - 1] & 0x0f;
    const binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
    const mod = OtpEngine.pow10(token.digits);
    const value = binary % mod;
    return value.toString().padStart(token.digits, '0');
  }

  private static pow10(digits: number): number {
    let n = 1;
    for (let i = 0; i < digits; i++) {
      n *= 10;
    }
    return n;
  }

  private static int64ToBytes(value: number): Uint8Array {
    const bytes = new Uint8Array(8);
    let n = value;
    for (let i = 7; i >= 0; i--) {
      bytes[i] = n & 0xff;
      n = Math.floor(n / 256);
    }
    return bytes;
  }

  private static async hmac(algorithm: string, key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const mac = cryptoFramework.createMac(algorithm);
    const generator = cryptoFramework.createSymKeyGenerator('HMAC');
    const symKey = await generator.convertKey({ data: key });
    await mac.init(symKey);
    await mac.update({ data: data });
    const result = await mac.doFinal();
    return result.data;
  }
}
