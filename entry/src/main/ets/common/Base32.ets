const ALPHABET: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

export class Base32 {
  static normalize(secret: string): string {
    return secret.toUpperCase().replace(/[\s=-]/g, '');
  }

  static isValid(secret: string): boolean {
    const text = Base32.normalize(secret);
    if (text.length < 8) {
      return false;
    }
    for (let i = 0; i < text.length; i++) {
      if (ALPHABET.indexOf(text.charAt(i)) < 0) {
        return false;
      }
    }
    return true;
  }

  static decode(secret: string): Uint8Array {
    const text = Base32.normalize(secret);
    let bits = 0;
    let value = 0;
    const bytes: number[] = [];
    for (let i = 0; i < text.length; i++) {
      const idx = ALPHABET.indexOf(text.charAt(i));
      if (idx < 0) {
        continue;
      }
      value = (value << 5) | idx;
      bits += 5;
      if (bits >= 8) {
        bytes.push((value >> (bits - 8)) & 0xff);
        bits -= 8;
      }
    }
    return new Uint8Array(bytes);
  }
}
