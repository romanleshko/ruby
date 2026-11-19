// smoke.c — minimal embedder used by apple/Makefile to check each slice.
//
// macOS: linked and run; boots the VM and requires zlib + yaml (yaml.rb →
// psych.rb → static psych ext), proving the merged archive and the stdlib work.
// iOS / simulator: only linked; a successful link proves the archive is
// symbol-complete.
//
// STDLIB_DIR is passed with -D (the pure-Ruby stdlib to put on $LOAD_PATH).

#include <ruby.h>
#include <stdio.h>

int main(void) {
    ruby_init();
    static char *args[] = {
        "smoke", "-I", STDLIB_DIR,
        "-e", "require %q(zlib); require %q(yaml); Zlib.crc32(%q(questplay)); YAML.load(%q(a: 1))",
        NULL
    };
    int state = 0;
    void *node = ruby_options(5, args);
    if (ruby_executable_node(node, &state)) state = ruby_exec_node(node);
    if (state) {
        fprintf(stderr, "smoke: eval failed\n");
        return 1;
    }
    return ruby_cleanup(0);
}
