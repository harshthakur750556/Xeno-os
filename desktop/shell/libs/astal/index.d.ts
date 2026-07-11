export class Variable<T> {
  constructor(value: T);
  get(): T;
  set(value: T): void;
  observe(callback: (value: T) => void): () => void;
}

export const GLib: any;

export function bind(obj: any, prop?: string): any;

export namespace JSX {
  interface IntrinsicElements {
    [elemName: string]: any;
  }
}
