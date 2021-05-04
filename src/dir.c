#include <stddef.h>
#include <stdio.h>
#include <limits.h>
#include <sys/stat.h>

// Make a directory and all missing path segments. Returns 0 if directory
// already exists or is successfully created, 1 otherwise.
int fullmkdir(const char *dir) {
  struct stat path_stat;
  char tmp[PATH_MAX];
  char *p = NULL;
  size_t len;

  len = snprintf(tmp, sizeof(tmp), "%s", dir);
  if (len < sizeof tmp) {
    if (tmp[len - 1] == '/') tmp[len - 1] = 0; // Remove trailing slash if present
    for (p = tmp + 1; *p; p++) {
      if (*p == '/') {
        *p = 0;
        mkdir(tmp, S_IRWXU);
        *p = '/';
      }
    }
    mkdir(tmp, S_IRWXU);
  }
  stat(tmp, &path_stat);
  return S_ISDIR(path_stat.st_mode) ? 0 : 1;
}
