#ifndef ARCHIVE_IO_H
#define ARCHIVE_IO_H
#include <stdint.h>
#include <stddef.h>
void ta_set_cancelled(int value);
int ta_is_cancelled(void);
/* Source offset points to the compression-method byte. Output is always a new file. */
int ta_extract(int source_fd, uint64_t offset, uint64_t packed_size,
               uint64_t expected_size, const char *output, char *error, size_t error_size);
#endif
