// Compressão zlib (formato exigido por /FlateDecode) com as APIs nativas de Deno e Node.
async function pipe(data: Uint8Array, stream: CompressionStream | DecompressionStream): Promise<Uint8Array> {
  const body = new Blob([data as unknown as BlobPart]).stream().pipeThrough(stream as unknown as ReadableWritablePair<Uint8Array, Uint8Array>);
  return new Uint8Array(await new Response(body).arrayBuffer());
}

export const deflate = (data: Uint8Array) => pipe(data, new CompressionStream('deflate'));
export const inflate = (data: Uint8Array) => pipe(data, new DecompressionStream('deflate'));

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes as unknown as BufferSource));
  return Array.from(digest, v => v.toString(16).padStart(2, '0')).join('');
}
