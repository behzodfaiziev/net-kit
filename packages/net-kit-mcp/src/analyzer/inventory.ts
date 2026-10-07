import { identifiers, namedArg, type DartFile } from './model.js';
import { UPLOAD_METHODS, urlEvidence } from './rules/helpers.js';

/** Upload call sites classified by design, for `review_upload_flow`. */
export interface UploadSite {
  readonly file: string;
  readonly line: number;
  readonly design:
    | 'api-file-stream'
    | 'api-multipart'
    | 'api-bytes'
    | 'external-file-stream'
    | 'external-replayable-stream'
    | 'external-single-shot-stream'
    | 'external-bytes'
    | 'external-multipart';
  readonly destination: 'api' | 'external' | 'unknown';
  readonly replayable: boolean;
  readonly cancellable: boolean;
  readonly progress: boolean;
}

export function uploadInventory(files: readonly DartFile[]): UploadSite[] {
  const sites: UploadSite[] = [];
  for (const file of files) {
    for (const call of file.calls) {
      const cancellable = namedArg(call, 'cancellationToken') !== undefined;
      const progress = namedArg(call, 'onSendProgress') !== undefined;
      if (call.isMember && UPLOAD_METHODS.has(call.name)) {
        const pathEvidence = urlEvidence(namedArg(call, 'path')?.tokens ?? []);
        sites.push({
          file: file.path,
          line: call.line,
          design:
            call.name === 'uploadFile'
              ? 'api-file-stream'
              : call.name === 'uploadRawData'
                ? 'api-bytes'
                : 'api-multipart',
          destination: pathEvidence.kind === 'none' ? 'api' : 'external',
          replayable: true,
          cancellable,
          progress,
        });
        continue;
      }
      if (call.name !== 'RawHttpRequest' || call.isMember) continue;
      const body = namedArg(call, 'body');
      if (body === undefined) continue;
      const names = identifiers(body.tokens);
      const design = names.includes('FileRawHttpBody')
        ? 'external-file-stream'
        : names.includes('ReplayableRawHttpBody')
          ? 'external-replayable-stream'
          : names.includes('StreamRawHttpBody')
            ? 'external-single-shot-stream'
            : names.includes('NetKitFormData')
              ? 'external-multipart'
              : names.includes('BytesRawHttpBody')
                ? 'external-bytes'
                : null;
      if (design === null) continue;
      sites.push({
        file: file.path,
        line: call.line,
        design,
        destination:
          urlEvidence(namedArg(call, 'uri')?.tokens ?? []).kind === 'none' ? 'unknown' : 'external',
        replayable: design !== 'external-single-shot-stream',
        cancellable,
        progress,
      });
    }
  }
  return sites;
}
