// RubyEmbed.h — where this package's Ruby files are at runtime.
//
// The interpreter itself (libruby + ruby.h) comes from the Ruby-MKXPZ binary
// target; this target only ships the Ruby files it loads from disk and says
// where they are. It does not touch the Ruby VM.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Folders to put on Ruby's $LOAD_PATH, in order: this platform's
/// rbconfig.rb, then the pure-Ruby standard library. Pass each to
/// ruby_options() as `-I <folder>` when booting the VM.
NSArray<NSString *> *RubyEmbedLoadPaths(void);

NS_ASSUME_NONNULL_END
