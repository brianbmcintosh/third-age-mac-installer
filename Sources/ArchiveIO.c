/* Clickteam stream layout reference: Bioruebe/cicdec, BSD-3-Clause (see THIRD_PARTY_NOTICES). */
#include "ArchiveIO.h"
#include <zlib.h>
#include <bzlib.h>
#include <stdatomic.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

static atomic_int cancelled = 0;
void ta_set_cancelled(int value) { atomic_store(&cancelled, value); }
int ta_is_cancelled(void) { return atomic_load(&cancelled); }

static int write_all(int fd, const unsigned char *buf, size_t count) {
    while (count) {
        ssize_t n = write(fd, buf, count);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        buf += n; count -= (size_t)n;
    }
    return 0;
}

int ta_extract(int source_fd, uint64_t offset, uint64_t packed_size,
               uint64_t expected_size, const char *output, char *error, size_t error_size) {
    int out = -1, result = -1, method = 0, initialized = 0, finished = 0;
    const char *reason = "Archive data is incomplete or damaged.";
    uint64_t remaining = packed_size, written = 0;
    unsigned char input[65536], buffer[65536], method_byte;
    z_stream zs = {0}; bz_stream bs = {0};
    out = open(output, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0644);
    if (out < 0) { snprintf(error, error_size, "Cannot create output file: %s", strerror(errno)); return -1; }
    if (expected_size == 0) { result = 0; goto done; }
    if (!remaining || pread(source_fd, &method_byte, 1, (off_t)offset) != 1) goto done;
    method = method_byte; offset++; remaining--;
    if (method == 1) { if (inflateInit(&zs) != Z_OK) goto done; initialized = 1; }
    else if (method == 2) { if (BZ2_bzDecompressInit(&bs, 0, 0) != BZ_OK) goto done; initialized = 1; }
    else if (method != 0) { reason = "Unsupported archive compression."; goto done; }
    while (!finished) {
        if (ta_is_cancelled()) { reason = "Installation cancelled."; goto done; }
        size_t available = method == 1 ? zs.avail_in : method == 2 ? bs.avail_in : 0;
        if (method == 0 && !remaining) goto done;
        if (!available && remaining) {
            size_t wanted = remaining > sizeof input ? sizeof input : (size_t)remaining;
            if (method == 0 && wanted > expected_size-written) wanted = (size_t)(expected_size-written);
            ssize_t n = pread(source_fd, input, wanted, (off_t)offset);
            if (n <= 0) goto done;
            offset += n; remaining -= n;
            if (method == 0) {
                if (write_all(out, input, (size_t)n)) { reason = "Could not write game data. Check free disk space and folder permissions."; goto done; }
                written += n; finished = written == expected_size; continue;
            }
            if (method == 1) { zs.next_in = input; zs.avail_in = (unsigned int)n; }
            else { bs.next_in = (char *)input; bs.avail_in = (unsigned int)n; }
        }
        size_t produced;
        unsigned int before = method == 1 ? zs.avail_in : bs.avail_in;
        if (method == 1) {
            zs.next_out = buffer; zs.avail_out = sizeof buffer;
            int status = inflate(&zs, Z_NO_FLUSH);
            if (status != Z_OK && status != Z_STREAM_END) goto done;
            produced = sizeof buffer-zs.avail_out; finished = status == Z_STREAM_END;
        } else {
            bs.next_out = (char *)buffer; bs.avail_out = sizeof buffer;
            int status = BZ2_bzDecompress(&bs);
            if (status != BZ_OK && status != BZ_STREAM_END) goto done;
            produced = sizeof buffer-bs.avail_out; finished = status == BZ_STREAM_END;
        }
        if (produced > expected_size-written) { reason = "Archive expands beyond its declared size."; goto done; }
        if (write_all(out, buffer, produced)) { reason = "Could not write game data. Check free disk space and folder permissions."; goto done; }
        written += produced;
        unsigned int after = method == 1 ? zs.avail_in : bs.avail_in;
        if (!finished && produced == 0 && before == after) goto done;
    }
    if (!finished || written != expected_size) goto done;
    result = 0;
done:
    if (initialized && method == 1) inflateEnd(&zs);
    if (initialized && method == 2) BZ2_bzDecompressEnd(&bs);
    if (out >= 0 && close(out) != 0 && result == 0) { result = -1; reason = "Could not finish writing game data."; }
    if (result) { unlink(output); snprintf(error, error_size, "%s", reason); }
    return result;
}
